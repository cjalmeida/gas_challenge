### Load Data and Prepare Data
library(xts)
library(RPostgreSQL)
library(lubridate)

drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname="gas", user="postgres")

load_data <- function(con, table) {
  data <- dbReadTable(con, table)
  data.x <- xts(data[2], order.by=data$date)
  return (data.x)
}

# In our model, we'll try to forecast the 3-month gas price using a regression model based on crude future
# First let's load the data and get it to the frequency we want.

# Data 1: Weekly U.S. Ending Stocks of Crude Oil and Petroleum Products (Thousand Barrels)
# We'll get it to monthly data.
crude_stock <- to.monthly(load_data(con, "crude_oil_and_petroleum"), OHLC=F)

# Data 2: Weekly U.S. Ending Stocks of Total Gasoline (Thousand Barrels)
gas_stock <- to.monthly(load_data(con, "total_gasoline"), OHLC=F)

# Data 3: Cushing, OK Crude Oil Future Contract 1 (Dollars per Barrel) (Daily)
# Note 1: Contract 1 reflect "next delivery" price of crude oil.
# Note 2: We could use Contract 3 price from EIA for a better model, but we'll stick to the dataset we already have
# We'll convert it to monthly data
crude_price <- to.monthly(load_data(con, "crude_oil_future_contract"), OHLC=F)

# Data 4: US Regular Conventional Gasoline Retail Prices (Dollars per Gallon) (Weekly)
# Note: That's what we want to predict.
# We need to sanitize the data (0 to NA, then interpolate)
# We'll also create a data set indexed 3 months in the future to train and compare our prediction
gas_price <- load_data(con, "us_regular_conventional_gasoline_price")
gas_price[gas_price$dollars_per_gallon == 0] <- NA
gas_price <- na.approx(gas_price)
gas_price <- to.monthly(gas_price, OHLC=F)
idx_3m <- index(gas_price) - 3/12
gas_price_3m <- xts(coredata(gas_price), order.by = idx_3m)

# Data 5: U.S. Field Production of Crude Oil (Thousand Barrels) (Monthly)
# Note: there's a typo in table name
crude_prod <- to.monthly(load_data(con, "us_field_production_of_curde_oil"), OHLC=F)

# Data 6:  U.S. Total Gasoline All Sales/Deliveries by Prime Supplier (Monthly)
gas_sales <- to.monthly(load_data(con, "total_gasoline_by_prime_supplier"),OHLC=F)


#### Now we'll sanitize,  convert all data to weekly granularity and reindex

# We'll roll up daily crude price into weekly data. We'll use the closing price then.


# We need sanitize gas prices dataset (zeroes to NA, then interpolate NA)

