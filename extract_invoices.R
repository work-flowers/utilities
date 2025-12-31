
# setup -------------------------------------------------------------------

# Load required packages
pacman::p_load(
  tidyverse,      # Data manipulation and visualization
  notionR,        # Interface with Notion API
  keyring         # Secure credential storage
)

# Define your Notion database ID (copy from URL, no need for hyphens)
DATABASE_ID <- "21a91b07-11ac-80fc-a74b-d5506e567d49"  # Sales Invoices database

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
    invoice_number = `properties.Invoice Number.title.plain_text`
  )


# Save the processed data as CSV file
write.csv(clean, "sales_invoices_export.csv", row.names = FALSE)

