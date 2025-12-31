
# setup -------------------------------------------------------------------

# Load required packages
pacman::p_load(
  tidyverse,      # Data manipulation and visualization
  notionR,        # Interface with Notion API
  keyring         # Secure credential storage
)

# Configuration -----------------------------------------------------------

# Define your Notion database ID (copy from URL, no need for hyphens)
DATABASE_ID <- "2d991b0711ac8025a48af0a637e67ff7?v=2d991b0711ac80889c66000c4b4e7c2e"

# Define the property name that contains the cover image URL
COVER_URL_PROPERTY <- "remoteImageUrl"  # Change to match your database property name

# extraction --------------------------------------------------------------

# Fetch the entire database as a tibble using stored API key
db <- getNotionDatabase(
  secret = key_get("notion", "work.flowers"),  # Retrieve API key from keyring
  database = DATABASE_ID,
  cover_icon = TRUE  # Include existing cover/icon information
)

# Debug: Print column names to find the correct property name
cat("Available columns:\n")
print(names(db))
cat("\n\nColumns matching the property name:\n")
print(grep(COVER_URL_PROPERTY, names(db), value = TRUE))

# Extract page IDs and cover URLs
pages_to_update <- db %>%
  transmute(
    page_id = id,
    cover_url = .data[[paste0("properties.", COVER_URL_PROPERTY, ".url")]]
  ) %>%
  # Only process pages that have a cover URL specified
  filter(!is.na(cover_url) & cover_url != "")

# Debug: Show sample URLs being used
cat("\nSample cover URLs (first 3):\n")
print(head(pages_to_update, 3))

# Display summary
cat(sprintf("Found %d pages with cover URLs to update\n", nrow(pages_to_update)))

# Update covers -----------------------------------------------------------

# Function to safely update a page cover with error handling
update_cover_safely <- function(page_id, cover_url, secret) {
  tryCatch({
    cat(sprintf("Updating page %s with URL: %s\n", page_id, cover_url))
    result <- updatePageCover(
      secret = secret,
      id = page_id,
      cover_url = cover_url
    )
    cat(sprintf("  ✓ API response received\n"))
    return(TRUE)
  }, error = function(e) {
    message(sprintf("  ✗ Error updating page %s: %s", page_id, e$message))
    return(FALSE)
  })
}

# Get API key once
api_key <- key_get("notion", "work.flowers")

# Update each page's cover image
results <- pages_to_update %>%
  rowwise() %>%
  mutate(
    success = update_cover_safely(page_id, cover_url, api_key)
  ) %>%
  ungroup()

# Summary -----------------------------------------------------------------

# Count successes and failures
summary_stats <- results %>%
  summarise(
    total = n(),
    successful = sum(success, na.rm = TRUE),
    failed = sum(!success, na.rm = TRUE)
  )

# Display summary
cat("\n=== Update Summary ===\n")
cat(sprintf("Total pages processed: %d\n", summary_stats$total))
cat(sprintf("✅ Successfully updated: %d\n", summary_stats$successful))
cat(sprintf("❌ Failed to update: %d\n", summary_stats$failed))

# Show failed pages if any
if (summary_stats$failed > 0) {
  cat("\nFailed page IDs:\n")
  results %>%
    filter(!success) %>%
    select(page_id, cover_url) %>%
    print()
}

# Optional: Save results to CSV
write.csv(results, "notion_cover_update_results.csv", row.names = FALSE)
cat("\n📄 Results saved to: notion_cover_update_results.csv\n")

# Verification ------------------------------------------------------------

cat("\n=== Verification ===\n")
cat("Fetching first updated page to verify cover was set...\n")

if (nrow(results) > 0 && any(results$success)) {
  first_success <- results %>% filter(success) %>% slice(1)

  verification <- tryCatch({
    page_data <- getNotionPage(
      secret = api_key,
      id = first_success$page_id
    )

    if (!is.null(page_data$cover)) {
      cat(sprintf("✓ Cover verified on page %s\n", first_success$page_id))
      cat(sprintf("  Cover type: %s\n", page_data$cover$type))
      if (page_data$cover$type == "external") {
        cat(sprintf("  Cover URL: %s\n", page_data$cover$external$url))
      }
    } else {
      cat(sprintf("⚠ No cover found on page %s after update\n", first_success$page_id))
      cat("  This might indicate an API version compatibility issue\n")
    }
  }, error = function(e) {
    cat(sprintf("Error verifying page: %s\n", e$message))
  })
}
