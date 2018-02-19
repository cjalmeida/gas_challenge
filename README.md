Gas Price Predicition Using HP Vertica and HP Distributed R
========================================

This is a project where we're going to use two products of HP Haven's Big Data Platform: "Vertica", a column-oriented 
analytical database and "Distributed R", distributed platform for running applications written in the "R" language. The 
goal is to build a predictive model in R for Gasoline prices in the USA using sample data provided and/or outside data.

There are two blog posts carefully explaining how to install and run the challenge:

  * Part 1: Installation
    - Blog post at https://my.vertica.com/blog/gasoline-price-prediction-using-hp-vertica-and-distributed-rba-p228170/

  * Part 2: Building the Model
    - Blog post at https://my.vertica.com/blog/gasoline-price-prediction-using-hp-vertica-and-distributed-rba-p228370/

There is a script called "load_data_into_vertica.py" that does exactly what the name says. The R model in located in a 
single file named "gas_prediction.r". To install the required R packages, just run:

    install.packages(c("xts", "Metrics", "e1071"))
    
