Gas Price Predicition Using HP Vertica and HP Distributed R - Part 2: Building the Model
========================================

This is "Part 2: Building the Model" of a two-part blog post where we're going to use two products of HP Haven's Big Data Platform: "Vertica", a column-oriented analytical database and "Distributed R", distributed platform for running applications written in the "R" language. The goal is to build a predictive model in R for Gasoline prices in the USA using sample data provided and/or outside data. The output is a CSV file with inputs and the predicted output.

We assume you already have a running Vertica and Distributed R environment with R-Studio Server installed. Also, you'll need the sample dataset provided loaded into Vertica. You can find all files following this link and you can follow the instructions on  "Part 1: Installation".


Installing the Packages
-----------------------

Before we start our model, we must make sure all the required R packages are installed. "DistributedR" and "vRODBC" were installed during Distributed R installation. We need to install "xts" (for time-series analysis) so, from the R console:

```r
> install.packages('xts')
```

With all the required packages installed, we can begin building our model. The complete code can be found on the accompaining `gas_prediction.r` file. First, let's load the libraries, start Distributed R and setup the connection to Vertica.


```r
# Change env timezone to UTC make xts subsetting work
Sys.setenv(TZ='UTC')

# Load the required libraries
library(xts)
library(vRODBC)
library(distributedR)

# Start Distributed R
distributedR_start()

# Connect to the Database we configured in odbc.ini
con <- odbcConnect("VerticaGasDSN")
```
