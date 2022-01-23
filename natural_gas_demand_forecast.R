# LIBRARIES ----

library(tidyverse)
library(modeltime)
library(timetk)
library(lubridate)
library(tidymodels)
library(plotly)
library(USgas)


# DATA ----

demand_monthly_tbl <- USgas::us_monthly

## Data Cleaning ----

demand_monthly_tbl <- demand_monthly_tbl %>% 
  rename(total_demand = y) %>% 
  summarise_by_time(date, .by = "month", total_demand = sum(total_demand))

# EDA ----

demand_monthly_tbl %>% 
  plot_acf_diagnostics(date, total_demand, .interactive = F)+
  labs(subtitle = "Yearly seasonality can be observed")

# Creating Full Dataset ----

horizon <- 24 # number of months we want to forecast for 
lag_period <- 24
rolling_periods <- c(12, 24, 36, 48)

full_tbl <- demand_monthly_tbl %>% 
  # Creating future observations for next 24 months
  bind_rows(future_frame(
    .data = .,
    .date_var = date,
    .length_out = horizon
  )) %>%
  
  # Adding  autocorrelated lags
  tk_augment_lags(.value = total_demand, .lags = lag_period) %>%
  
  # Adding rolling features
  tk_augment_slidify(
    .value = total_demand_lag24,
    .period = rolling_periods,
    .f = mean,
    .align = "center",
    .partial = TRUE
  ) %>%
  
  # Renaming rolling lagged columns
  rename_with(.cols = contains("lag"), .fn = ~ str_c("lag_", .))

## Creating Forecast Table ----

forecast_tbl <- full_tbl %>% 
  filter(is.na(total_demand))  

data_prep_tbl <- full_tbl %>% 
  filter(!is.na(total_demand))

# Visualizing lagged and rolling lagged features

data_prep_tbl %>% 
  pivot_longer(-date) %>% 
  plot_time_series(date, value, name, .smooth = F,
                   .title = "Lagged vs Rolling Lagged Features", 
                   .interactive = F)+
  labs(subtitle = "Rolling Lag 12 and 24 seem to capture the trend better than rolling lag 26 and 48")+
  scale_y_continuous(labels = scales::comma)
  

# Creating Splits ----

splits <- time_series_split(data_prep_tbl, 
                            date_var = date, 
                            assess = horizon,
                            cumulative = TRUE)

# Visualizing the splits

splits %>% 
  tk_time_series_cv_plan() %>% 
  plot_time_series_cv_plan(date, total_demand) 



# Model Specifications ----

## Prophet ----

model_fit_prophet <- prophet_reg(changepoint_num = 20,
            changepoint_range = 0.8,
            season = "additive",
            growth = "linear",
            seasonality_yearly = TRUE) %>% 
  set_engine("prophet") %>% 
  fit(total_demand ~ date, 
      training(splits))

## AUTO ARIMA ----

model_fit_auto_arima <- arima_reg() %>% 
  set_engine("auto_arima") %>% 
  fit(total_demand ~ date + + fourier_vec(date, period = 12/2)
      + fourier_vec(date, period = 12)
      + fourier_vec(date, period = 24)
      + fourier_vec(date, period = 36),
      training(splits))


# ARIMA ----

model_fit_arima <- arima_reg(
  non_seasonal_ar = 2, 
  non_seasonal_differences = 1,
  
  seasonal_period = 12,
  seasonal_ar = 4,
  seasonal_differences = 1,
  seasonal_ma = 1
) %>%
  set_engine("arima") %>%
  fit(total_demand ~ date, data = training(splits))


# ETS ----

model_fit_ets <- exp_smoothing(error = "additive",
                               trend = "additive",
                               season = "additive") %>% 
  set_engine("ets") %>% 
  fit(total_demand ~ date, data = training(splits))


# TBATS ----

model_fit_tbats <- seasonal_reg(seasonal_period_1 = 12,
                                seasonal_period_2 = 24,
                                seasonal_period_3 = 36) %>% 
  set_engine("tbats") %>% 
  fit(total_demand ~ date, training(splits))


# STLM ETS ----

model_fit_stlm_ets <- seasonal_reg(seasonal_period_1 = 12, 
                                   seasonal_period_2 = 24,
                                   seasonal_period_3 = 36) %>% 
  set_engine("stlm_ets") %>% 
  fit(total_demand ~ date, training(splits))

# STLM ARIMA ----

model_fit_stlm_arima <- seasonal_reg(seasonal_period_1 = 12,
                                seasonal_period_2 = 24,
                                seasonal_period_3 = 36) %>% 
  set_engine("stlm_arima") %>% 
  fit(total_demand ~ date, training(splits))

# Calibrating all the models on testing set ----

calibration_tbl <- modeltime_table(model_fit_arima,
                                   model_fit_ets,
                                   model_fit_prophet,
                                   model_fit_stlm_ets,
                                   model_fit_tbats,
                                   model_fit_stlm_arima,
                                   model_fit_auto_arima) %>% 
  modeltime_calibrate(testing(splits))

# Model Accuracy ----

calibration_tbl %>% 
  modeltime_accuracy(testing(splits))

# Based on rmse, I will stick with Auto Arima model. It has the lowest rmse out of all the other models

# Visualizing the forecast on testing set----

calibration_tbl %>% 
  modeltime_forecast(new_data = testing(splits),
                     actual_data = data_prep_tbl) %>%
  plot_modeltime_forecast(.conf_interval_show = F, 
                          .interactive = F,
                          .title = "Forecast on Testing Splits")+
  labs(subtitle = "TBATS and ETS models seem to be not performing that great when compared with other models.")+
  scale_y_continuous(labels = scales::comma)

# Forecasting on Future Data ----

## Refitting the models ----

refit_tbl <- calibration_tbl %>% 
  modeltime_refit(data_prep_tbl)
  
refit_tbl %>% 
  modeltime_forecast(new_data = forecast_tbl,
                    actual_data = data_prep_tbl) %>% 
  plot_modeltime_forecast(.conf_interval_show = F)

# It looks like Auto Arima model seems to be performing well by capturing the seasonalities and trend pretty well. 








