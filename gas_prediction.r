### Prepare the environment

# Change env timezone to UTC make xts subsetting work
Sys.setenv(TZ='UTC')

# Load the required libraries
library(stats)
library(xts)
library(vRODBC)
library(distributedR)
library(Metrics)
library(HPdclassifier)
library(HPdregression)
library(e1071)

# Start Distributed R (ignore error if already started)
tryCatch(
  {
    distributedR_start()
  },  error= function(e) {
    if (!grepl('is already running', e$message)) stop(e)
  }
)

# Connect to the Database we configured in odbc.ini
con <- odbcConnect("VerticaGasDSN")

# Function to create the SQL query to load the data.
get_query <- function(table_name) {
  # The SQL query will use Vertica's FIRST_VALUE analytic function to get the closing value for the month
  # regardless if we're working with monthly, weekly or daily values. Vertica is *very* efficient in this
  # kind of work and can saves us from loading unnecessary fine grained data into R's memory.
  
  # We'll detect the data column name from meta-data
  data_col <- names(sqlQuery(con, paste('select * from', table_name, 'limit 0')))[2]
  
  # Note that the query will run the FIRST_VALUE function on a DESC ordered by date set because we want the closing value.
  # We's run in ASC order if we were interested in the opening value.
  sub_query <- paste("select year(date) as y,  month(date) as m,", 
                     "first_value(", data_col, ") over(partition by year(date), month(date) order by date desc) closing",
                     "from", table_name)
  
  # The data is not grouped, so we'll wrap our query to group our data by year and month. Additionaly we're going to return
  # the (year, month) information in the xts "yearmon" representation format (year + (month_number-1)/12)
  query <- paste("select y + (m-1)/12 as yearmon, max(closing) as closing from",
                 "(", sub_query, ") as subq",
                 "group by 1 order by 1")
  return(query)
}

# We'll create a load_data function to fully load a table from Vertica into Distributed R
load_data <- function(con, table_name) {
  
  d <- sqlQuery(con, get_query(table_name))
  
  # Detect zero, assing to NA, create xts object and interpolate.
  d[2][d[2]==0] <- NA   
  d.x <- xts(d[2], order.by=as.yearmon(d$yearmon))
  d.x <- na.approx(d.x)
  return (d.x)
}


## Do load the data

# Data 1: Weekly U.S. Ending Stocks of Crude Oil and Petroleum Products (Thousand Barrels)
crude_stock <- load_data(con, "crude_oil_and_petroleum")

# Data 2: Weekly U.S. Ending Stocks of Total Gasoline (Thousand Barrels)
gas_stock <- load_data(con, "total_gasoline")

# Data 3: Cushing, OK Crude Oil Future Contract 1 (Dollars per Barrel)
# Contract 1 reflect "next delivery" price of crude oil. We could use Contract 3 price from EIA 
# for a better model, but we'll stick to the dataset we already have.
crude_price <- load_data(con, "crude_oil_future_contract")

# Data 4: US Regular Conventional Gasoline Retail Prices (Dollars per Gallon)
gas_price <- load_data(con, "us_regular_conventional_gasoline_price")

# Data 5: U.S. Field Production of Crude Oil (Thousand Barrels)
# Note: there's a typo in table name
crude_prod <- load_data(con, "us_field_production_of_curde_oil")

# Data 6:  U.S. Total Gasoline All Sales/Deliveries by Prime Supplier
gas_sales <- load_data(con, "total_gasoline_by_prime_supplier")

# close DB handle
odbcCloseAll()


# We want to predict the gas price in 3 months. So we'll also create a data set where move the dates 3 months to the past.
idx_3m <- index(gas_price) - 3/12  # each month in yearmon objects is 1/12
gas_price_3m <- xts(coredata(gas_price), order.by = idx_3m)


# Stock levels have a seasonal component that we should remove to improve our prediction. We'll use the
# "decompose" function from "stats" package and remove the "seasonal" part from our data.
crude_stock <-(xts(as.ts(crude_stock) / decompose(as.ts(crude_stock), type = 'mult')$seasonal, 
                   order.by=index(crude_stock)))

gas_stock <- (xts(as.ts(gas_stock) / decompose(as.ts(gas_stock), type = 'mult')$seasonal, 
                  order.by=index(gas_stock)))

# We'll merge the data into a single xts object, filter for complete cases only and adjust their names.
# The last value is the response data. We'll also remove the objects from environment to save memory
dset <- merge(crude_price, crude_prod, crude_stock, gas_sales, gas_stock, gas_price, gas_price_3m)
dset <- dset[complete.cases(dset)]
names(dset) <- c("crude_price", "crude_prod", "crude_stock", "gas_sales", "gas_stock", "gas_price", "gas_price_3m")
rm(crude_price, crude_prod, crude_stock, gas_sales, gas_stock, gas_price, gas_price_3m)

# Now we'll split the data into training and test sets from start to "2010-Dec"
# First of all, we'll detect the earliest start date by applying the "start"
# function to our dataset ignoring NA values. Then we find the max start date
# and convert it back to "yearmon" object
dset.train <- as.data.frame(dset["/2010"])
dset.test <- as.data.frame(dset["2011/"])


# We'll create a two Random Forest models, one using all variables and another using selected variables we know from testing that gives us
# a better prediction, defined as a lower CV(RMSE). We'll use Distributed R's "hprandomForest" function available from HPdclassifier package. 
# Though it's labelled as a "classifier", it can be used for regression too.

# First we'll calculate the number of executors and prepare our "actual" data to compare to predictions
# The number of executors is, ideally a bit lower the number of Distributed R instances. We can get the info from the distributedR_status 
# function.

nExecutor <- sum(distributedR_status()$Inst)
actuals <- dset.test$gas_price_3m

# We'll create a "model runner" function to simply the testing using a number of different predictor variables. The function
# return a list containing $model: the created model, $predictions: the predicted values, $rmse: the RMSE "CV(RMSE)".
# The RMSE is the Root Mean Squared Error of predictions and we'll use that to judge how "predictive" our model is. The lower the
# value, the better

# Use Distributed R Random Forest function, a parallelized version of the algorithm
build_randomForest <- function (predictors) {
  time <- system.time({
    # train the model
    X = dset.train[predictors]
    Y = dset.train$gas_price_3m
    my_model <- hpdrandomForest(x = X, y = Y, nExecutor = nExecutor, importance = T)  
    
    # test the model
    predicted_vals <- predict(my_model, dset.test[predictors])
    model_rmse <- rmse(actuals, predicted_vals)
  })
  return(list("model" = my_model, "predictions" = predicted_vals, "rmse" = model_rmse, "time" = time[3]))
}

# Use Distributed R glm function, a parallelized version of the algorithm for Generalized Linear Models
build_glm <- function(predictors) {
  time <- system.time({
    # Train the model. Since we're not supplying the number of blocks, the function will strip
    # the data across the cluster by default.
    X = as.darray(as.matrix(dset.train[predictors]))
    Y = as.darray(as.matrix(dset.train$gas_price_3m))
    my_model <- hpdglm(responses = Y, predictors = X, family = gaussian(link=identity))  
    
    # test the model
    predicted_vals <- predict(my_model, as.matrix(dset.test[predictors]))
    model_rmse <- rmse(actuals, predicted_vals)
  })
  return(list("model" = my_model, "predictions" = predicted_vals, "rmse" = model_rmse, "time" = time[3]))
}

# Create a Support Vector Regression model for the data. We want to optimize the epsilon parameter
# so we're using a "nu-regression" type. Note that HP has not yet implemented a distributed version of 
# this algorithm, so we're using the non-distributed version provided on e1071 package.
build_svm <- function(predictors) {
  time <- system.time ({
    # Train the model. Since we're not supplying the number of blocks, the function will strip
    # the data across the cluster by default.
    X = as.matrix(dset.train[predictors])
    Y = as.matrix(dset.train$gas_price_3m)
    
      my_model <- svm(y = Y, X, type = 'nu-regression', kernel = 'linear')  
    
    
    # test the model
    predicted_vals <- predict(my_model, as.matrix(dset.test[predictors]))
    model_rmse <- rmse(actuals, predicted_vals)
  })
  return(list("model" = my_model, "predictions" = predicted_vals, "rmse" = model_rmse, "time" = time[3]))
}

# Model 0: Naïve "no-change" model. It assumes the gasoline price in 3 months will be equal to current price.
# The no-change model is usually used to control if our costlier models do improve over the simplest approach to forecasting.
r0 <- list()
r0$time <- system.time({
  r0$predictions <- dset.test$gas_price
  r0$rmse <- rmse(actuals, r0$predictions)
})[3]

# Model 1: RF model using all variables. The RF model is good for this kind of exploratory work since it can calculate
# the "importance" of each variable and let us take somewhat unimportant data out of the training set and maybe improve
# our models.
predictors_all <- names(dset.test)[names(dset.test) != "gas_price_3m"]
r1 <- build_randomForest(predictors_all)
importance <- r1$model$importance
print("Variable importance from Random Forest model with all variables:")
print(importance)

# We'll select only a few predictors we judge more relevant for our model. Then we'll create the remaining models
predictors = c("crude_price", "crude_stock", "gas_price")

# Model 2: create a RF model based exclusively on selected variables
r2 <- build_randomForest(predictors)

# Model 3: GLM Gaussian model based exclusively on selected variables
r3 <- build_glm(predictors)

# Model 4: Support Vector Regression model based on selected variables. 
r4 <- build_svm(predictors)

# Let's analyse the RMSE and Execution time of all models
RMSE <- c(r0$rmse, r1$rmse, r2$rmse, r3$rmse, r4$rmse)
EXEC_TIME <- c(r0$time, r1$time, r2$time, r3$time, r4$time)
models_summary <- data.frame("RMSE" = RMSE, "Execution Time" = EXEC_TIME)
row.names(models_summary) <- c("Naive", "Random Forest (all vars)", "Random Forest (key vars)", "GLM Gaussian", "SVR")
print("")
print("Comparison of models")
print(models_summary)

# Our models improve slightly over the Naive approach - ~0.35 RMSE against ~0.37. We're picking the Ramdom Forest
# model to output our results.

test.output <- cbind(dset.test[predictors], prediction_gas_price_3m=r2$predictions, actual_gas_price_3m=actuals)
write.csv(test.output, file="output.csv")
print("Output written to 'output.csv' file in the current directory.")