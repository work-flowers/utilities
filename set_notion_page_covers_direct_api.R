
# setup -------------------------------------------------------------------

# Load required packages
pacman::p_load(
  tidyverse,      # Data manipulation and visualization
  httr2,          # Modern HTTP client for API calls
  keyring         # Secure credential storage
)

# Configuration -----------------------------------------------------------

# Define your Notion data source ID (copy from URL, no need for hyphens)
DATA_SOURCE_ID <- "2d991b07-11ac-8008-8380-000bdc22a8a4"

# Define the property name that contains the cover image URL
COVER_URL_PROPERTY <- "remoteImageUrl"

# Which Notion API version to use
NOTION_API_VERSION <- "2025-09-03"

# extraction --------------------------------------------------------------

# Get API key
api_key <- key_get("notion", "work.flowers")

# Function to query data source using httr2 (API version 2025-09-03)
query_data_source <- function(data_source_id, api_key, api_version) {
  url <- paste0("https://api.notion.com/v1/data_sources/", data_source_id, "/query")

  req <- request(url) %>%
    req_headers(
      Authorization = paste0("Bearer ", api_key),
      "Notion-Version" = api_version,
      "Content-Type" = "application/json"
    ) %>%
    req_body_json(list(page_size = 100))

  all_results <- list()
  has_more <- TRUE
  start_cursor <- NULL

  while (has_more) {
    # Add cursor if we're paginating
    if (!is.null(start_cursor)) {
      req <- req %>% req_body_json(list(
        page_size = 100,
        start_cursor = start_cursor
      ))
    }

    resp <- req_perform(req)
    data <- resp_body_json(resp)

    all_results <- c(all_results, data$results)
    has_more <- data$has_more
    start_cursor <- data$next_cursor

    cat(sprintf("Fetched %d pages so far...\n", length(all_results)))
  }

  return(all_results)
}

cat("Fetching pages from data source...\n")
pages <- query_data_source(DATA_SOURCE_ID, api_key, NOTION_API_VERSION)
cat(sprintf("Total pages fetched: %d\n\n", length(pages)))

# Extract page IDs and cover URLs
pages_to_update <- map_df(pages, function(page) {
  # Extract the URL property
  url_value <- page$properties[[COVER_URL_PROPERTY]]$url

  tibble(
    page_id = page$id,
    cover_url = url_value %||% NA_character_
  )
}) %>%
  filter(!is.na(cover_url) & cover_url != "")

cat(sprintf("Pages with cover URLs: %d\n", nrow(pages_to_update)))
cat("\nSample URLs (first 3):\n")
print(head(pages_to_update, 3))

# Update covers -----------------------------------------------------------

# Function to update page cover using direct API call
update_page_cover <- function(page_id, cover_url, api_key, api_version) {
  url <- paste0("https://api.notion.com/v1/pages/", page_id)

  req <- request(url) %>%
    req_headers(
      Authorization = paste0("Bearer ", api_key),
      "Notion-Version" = api_version,
      "Content-Type" = "application/json"
    ) %>%
    req_body_json(list(
      cover = list(
        type = "external",
        external = list(url = cover_url)
      )
    )) %>%
    req_method("PATCH")

  tryCatch({
    resp <- req_perform(req)
    data <- resp_body_json(resp)

    # Check if cover was actually set
    if (!is.null(data$cover) && data$cover$type == "external") {
      return(list(success = TRUE, error = NA))
    } else {
      return(list(success = FALSE, error = "Cover not set in response"))
    }
  }, error = function(e) {
    return(list(success = FALSE, error = as.character(e)))
  })
}

cat("\nUpdating page covers...\n")

# Update each page
results <- pages_to_update %>%
  rowwise() %>%
  mutate(
    result = list(update_page_cover(page_id, cover_url, api_key, NOTION_API_VERSION)),
    success = result$success,
    error = result$error
  ) %>%
  select(-result) %>%
  ungroup()

# Summary -----------------------------------------------------------------

summary_stats <- results %>%
  summarise(
    total = n(),
    successful = sum(success, na.rm = TRUE),
    failed = sum(!success, na.rm = TRUE)
  )

cat("\n=== Update Summary ===\n")
cat(sprintf("Total pages processed: %d\n", summary_stats$total))
cat(sprintf("✅ Successfully updated: %d\n", summary_stats$successful))
cat(sprintf("❌ Failed to update: %d\n", summary_stats$failed))

# Show failed pages if any
if (summary_stats$failed > 0) {
  cat("\nFailed pages:\n")
  results %>%
    filter(!success) %>%
    select(page_id, cover_url, error) %>%
    print(n = 10)
}

# Save results
write.csv(results, "notion_cover_update_results_direct_api.csv", row.names = FALSE)
cat("\n📄 Results saved to: notion_cover_update_results_direct_api.csv\n")

# Verification ------------------------------------------------------------

cat("\n=== Verification ===\n")

if (nrow(results) > 0 && any(results$success)) {
  first_success <- results %>% filter(success) %>% slice(1)

  cat(sprintf("Verifying page: %s\n", first_success$page_id))

  # Fetch the page to verify cover
  verify_url <- paste0("https://api.notion.com/v1/pages/", first_success$page_id)

  verify_req <- request(verify_url) %>%
    req_headers(
      Authorization = paste0("Bearer ", api_key),
      "Notion-Version" = NOTION_API_VERSION
    )

  verify_resp <- req_perform(verify_req)
  page_data <- resp_body_json(verify_resp)

  if (!is.null(page_data$cover)) {
    cat(sprintf("✓ Cover found on page!\n"))
    cat(sprintf("  Type: %s\n", page_data$cover$type))
    if (page_data$cover$type == "external") {
      cat(sprintf("  URL: %s\n", page_data$cover$external$url))
    }
  } else {
    cat("⚠ No cover found on verified page\n")
  }
}
