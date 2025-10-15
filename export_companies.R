
# setup -------------------------------------------------------------------

# Load required packages
pacman::p_load(
  tidyverse,      # Data manipulation and visualization
  notionR,        # Interface with Notion API
  keyring         # Secure credential storage
)

# Define your Notion database ID (copy from URL, no need for hyphens)
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
    page_id = id, # Unique identifier for each contact
    name = `properties.Company Name.title.plain_text`,
    url = `properties.Website.url`,
    campany_id = glue::glue("COM-{`properties.ID.unique_id.number`}")   
  )


# Save the processed data as CSV file
write.csv(clean, "notion_companies_export.csv", row.names = FALSE)
