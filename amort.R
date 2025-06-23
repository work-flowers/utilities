library(tidyverse)
library(lubridate)

# --- Inputs ---
start_date <- as.Date("2025-06-20")
end_date <- as.Date("2026-05-13")
total_amount <- 112.41

# Billing day = end_date day
billing_day <- day(end_date)

# First full billing period starts on the next occurrence of that day
first_full_start <- make_date(
  year = year(start_date),
  month = month(start_date),
  day = billing_day
)
if (first_full_start <= start_date) {
  first_full_start <- first_full_start %m+% months(1)
}

# First (partial) period ends day before first full month starts
first_period_end <- first_full_start - days(1)

# Build all full month periods
period_starts <- c(start_date)
period_ends <- c(first_period_end)

current_start <- first_full_start
while (current_start < end_date) {
  current_end <- current_start %m+% months(1) - days(1)
  if (current_end > end_date) current_end <- end_date
  period_starts <- c(period_starts, current_start)
  period_ends <- c(period_ends, current_end)
  current_start <- current_end + days(1)
}

# Calculate number of full months
n_periods <- length(period_starts)
n_full_months <- n_periods - 1

# Standard monthly payment
monthly_amount <- round(total_amount / n_periods, 2)

# First period proration: based on actual days in partial period
first_period_days <- as.numeric(period_ends[1] - period_starts[1] + 1)
full_month_days <- as.numeric(period_ends[2] - period_starts[2] + 1)

prorated_first <- round(monthly_amount * (first_period_days / full_month_days), 2)

# Recalculate the remaining (equal) full month payments
remaining_amount <- total_amount - prorated_first
full_month_amount <- round(remaining_amount / n_full_months, 2)

# Adjust last month for rounding difference
amounts <- c(prorated_first, rep(full_month_amount, n_full_months))
rounding_correction <- total_amount - sum(amounts)
amounts[length(amounts)] <- amounts[length(amounts)] + rounding_correction

# Build tibble
amortization_df <- tibble(
  period_start = period_starts,
  period_end = period_ends,
  amount = amounts
)

print(amortization_df)