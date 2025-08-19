
# setup -------------------------------------------------------------------

# Load required packages
pacman::p_load(
  tidyverse,      # Data manipulation and visualization
  notionR,        # Interface with Notion API
  keyring         # Secure credential storage
)

# Define your Notion database ID (copy from URL, no need for hyphens)
# DATABASE_ID <- "21991b0711ac8103bdaddb2df65e6bba"  # Clay Contacts database
DATABASE_ID <- "21991b0711ac806d99e8f151552c7d3c" # Companies database
# extraction --------------------------------------------------------------

# Fetch the entire database as a tibble using stored API key
db <- getNotionDatabase(
  secret = key_get("notion", "work.flowers"),  # Retrieve API key from keyring
  database = DATABASE_ID
)

# Extract needed columns into a clean dataframe
# Select only the page ID and email fields from the complex nested structure
clean <- db %>%
  transmute(
    page_id = id,                                      # Unique identifier for each contact
    primary_email = `properties.Primary Email.email`,   # Main email address
    secondary_email = `properties.Secondary Email.email` # Alternative email address
  )

# Transform from wide to long format for easier analysis
# This creates one row per email address rather than one row per contact
output_long <- clean |> 
  pivot_longer(
    cols = c(primary_email, secondary_email),  # Columns to pivot
    names_to = "email_type",                   # New column for email type
    values_to = "email"                        # New column for email values
  ) %>%
  filter(!is.na(email) & email != "") |>      # Remove empty/missing emails
  mutate(
    # Clean up email type labels for better readability
    email_type = case_when(
      email_type == "primary_email" ~ "Primary",
      email_type == "secondary_email" ~ "Secondary",
      TRUE ~ email_type # fallback in case of other values
    )
  )

# Save the processed data as CSV file
write.csv(output_long, "notion_emails_export.csv", row.names = FALSE)

# Confirm successful export
cat("✅ Export complete: notion_emails_export.csv\n")