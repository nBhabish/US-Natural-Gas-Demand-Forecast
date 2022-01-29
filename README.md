# US-Natural-Gas-Demand-Forecast
> Forecasting monthly natural gas demand in the United States until 2023-01-01 (i.e. next 24 months based on the dataset in use)


### Table of Contents

- [Description](#description)
- [Models Used](#models-used)
- [Natural Gas Demand Visualization](#natural-gas-demand-visualization)
- [Pre-Forecast Diagnostics](#pre-forecast-diagnostics)
- [Results](#results)
- [Post-Forecast Diagnostics](#post-forecast-diagnostics)
- [Further-Improvisation](#further-improvisation)


# Description

We are trying to predict Natural Gas Demand of the United States until 2023-01-01. The data comes from `USgas` package developed by Rami Krispin, Data Science and Engineering Manager at Apple. We trained some sequential models to generate forecast for 24 months into the future

# Models Used

- Prophet
- ARIMA
- AUTO ARIMA
- ETS
- TBATS 
- STLM ETS
- STLM ARIMA 



# Natural Gas Demand Visualization

The following plot shows what the natural gas demand has been like in the United States since 2000 to 2020. 

  <img src = "01_plots/00_demand_plot.png">

Takeaways from the Visualization above:
- No outliers that would throw off our forecast
- Stationary for the most part

# Pre-Forecast Diagnostics

- ACF Plot below allows us to see the autocorrelated lags, and from the plot below it is clear the lag 12, 24, 36 are going to be important. 

<img src = "01_plots/01_pre_forecast_diagnostics.png">

- After performing pre-processing operations we decided to observe the lag and rolling lag features to see which features picked up the trend better. It does look like from the plot below rolling lad 12 and 24 did capture the trend better. 

<img src = "01_plots/02_rolling_lag_features.png">


# Results

- After preforming pre-forecast diagnostics, we then decided to split the data into training and testing set. We decided to fit the models to the training set and evaluate their performance on the testing set. 

- After evaluating ARIMA, AUTO ARIMA, PROPHET, ETS, TBATS, STLM ETS, and STLM ARIMA, we observed that AUTO ARIMA outperformed the rest of the models on the testing set. It can also be verified from the plot below

<img src = "01_plots/model_performance.png">

- We also observed that TBATS and ETS did not really picked up the dipping patterns that well. 

<img src = "01_plots/forecasting_testing_splits.png">

- Since, we skipped resampling and tuning, we decided to use all the models to see how they would forecast. Before moving on to forecasting procedures, we decided to refit all the calibrated models on the `data_prep_tbl`(didn't include the dates to be forecasted), since recent timestamps are very essential for time series forecasting. 

- After refitting the models, we decided to use the data separated for forecasting to forecast the natural gas demand in the United States for next 24 months. One of the ARIMA models also got updated after refitting it to the `(training + testing - forecast)` data.

- Both ARIMA models forecast seemed to stand out, however we decided to stick to `ARIMA(1,1,1)(2,1,1)[12]` model that preformed great on the test set. It also seemed to capture the spikes pretty well and follow the trend while being stationary. Another reason why we thought it gave us a better forecast was because it also accounted for the drop in demand after 2020. 

<img src = "01_plots/auto_arima_forecast.png">

- The plot below shows all models forecast. 

<img src = "01_plots/all_models_forecast.png">


# Post-Forecast Diagnostics

- We decided to plot in-sample and out-of-sample residuals for all the models to see if we were able to capture patterns from the data. 

<img src = "01_plots/residual_in_sample.png">

- From the plot, doing an eye test, we can see the residuals being centered around 0. 

<img src = "01_plots/residual_out_sample.png">


`ARIMA(1,1,1)(2,1,1)[12]` residuals for in-sample and out-of-sample data is plotted below. 

<img src = "01_plots/arima_in_sample_residual.png">

<img src = "01_plots/arima_out_sample_residual.png">

- It's also best advised to see if there's any autocorrelation left in our best model. So, we also decided to take a look at `ARIMA(1,1,1)(2,1,1)[12]` for any autocorrelation in the residuals to see if there's still more information that we could mine to improvise model performance.

<img src = "01_plots/arima_acf.png">

- We can see that there is minimal autocorrelation among the residuals in the plot above. The plot above uses out-of-sample data for acf. This indicates that we have extracted decent amount of information with our algorithms and features.


# Further-Improvisation

- We can use machine learning models that are better at picking up seasonalities like XGBoost, or use a combination of PROPHET and XGBoost since PROPHET is great at picking up trends whereas XGBoost is great at picking up patterns. 

- The only downside with using AUTO ARIMA or ARIMA models are that they only pick up single seasonality, so if we wanted to model complex seasonalities/ multiple seasonalities ARIMA might not be the best model for us. 
