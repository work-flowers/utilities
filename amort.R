library(tidyverse)
library(lubridate)

# --- Inputs ---
start_date <- as.Date("2025-04-23")
end_date <- as.Date("2026-04-23")
total_amount <- 246.24

# --- Compute billing anchor ---
# Add 1 month to start_date, but adjust day to match end_date's day
anchor_month <- start_date %m+% months(1)
billing_anchor <- make_date(
  year = year(anchor_month),
  month = month(anchor_month),
  day = day(end_date)
)

# If billing anchor is before start_date, move it 1 month forward
if (billing_anchor <= start_date) {
  billing_anchor <- billing_anchor %m+% months(1)
}

# --- Calculate number of full billing months after the first partial ---
full_months <- interval(billing_anchor + days(1), end_date) %/% months(1)

# --- First period (prorated) ---
days_in_first_partial_period <- as.numeric(billing_anchor - start_date + 1)

# Standard billing month days
# Assume that each "full" billing month is about 1 month after billing_anchor
example_next_anchor <- billing_anchor %m+% months(1)
standard_billing_days <- as.numeric(example_next_anchor - billing_anchor)

# Rates
monthly_rate <- total_amount / (full_months + 1)
daily_rate <- monthly_rate / standard_billing_days
first_payment <- round(daily_rate * days_in_first_partial_period, 2)

# --- Build periods ---
period_starts <- c(start_date)
period_ends <- c(billing_anchor)

current_start <- billing_anchor + days(1)

for (i in 1:full_months) {
  next_end <- current_start %m+% months(1) - days(1)
  
  # Cap at end_date
  if (next_end > end_date) next_end <- end_date
  
  period_starts <- c(period_starts, current_start)
  period_ends <- c(period_ends, next_end)
  
  current_start <- next_end + days(1)
}

# --- Assign payments ---
amounts <- c(
  first_payment,
  rep(round(monthly_rate, 2), full_months)
)

# Adjust the final month if necessary to fix rounding
correction <- total_amount - sum(amounts)
amounts[length(amounts)] <- amounts[length(amounts)] + correction

# --- Build final dataframe ---
amortization_df <- tibble(
  period_start = period_starts,
  period_end = period_ends,
  amount = amounts
)

# --- Output ---
print(amortization_df)