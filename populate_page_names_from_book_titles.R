
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

# Define the property names
NAME_PROPERTY <- "Name"          # The title property of the database
BOOK_TITLE_PROPERTY <- "bookTitle"  # The property containing book title

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

# Extract page IDs, current names, and book titles
pages_to_check <- map_df(pages, function(page) {
  # Extract the Name property (title type)
  name_prop <- page$properties[[NAME_PROPERTY]]
  current_name <- if (!is.null(name_prop$title) && length(name_prop$title) > 0) {
    name_prop$title[[1]]$plain_text
  } else {
    NA_character_
  }

  # Extract the book title property (assuming it's a rich_text or title type)
  book_title_prop <- page$properties[[BOOK_TITLE_PROPERTY]]
  book_title <- if (!is.null(book_title_prop$rich_text) && length(book_title_prop$rich_text) > 0) {
    book_title_prop$rich_text[[1]]$plain_text
  } else if (!is.null(book_title_prop$title) && length(book_title_prop$title) > 0) {
    book_title_prop$title[[1]]$plain_text
  } else {
    NA_character_
  }

  tibble(
    page_id = page$id,
    current_name = current_name,
    book_title = book_title
  )
})

# Filter to pages where Name is empty but book title exists
pages_to_update <- pages_to_check %>%
  filter(
    (is.na(current_name) | current_name == "") &
    !is.na(book_title) &
    book_title != ""
  )

cat(sprintf("Pages with empty names but have book titles: %d\n", nrow(pages_to_update)))
cat("\nSample pages to update (first 5):\n")
print(head(pages_to_update, 5))

# Update names -----------------------------------------------------------

# Function to update page name (title) using direct API call
update_page_name <- function(page_id, new_name, name_property, api_key, api_version) {
  url <- paste0("https://api.notion.com/v1/pages/", page_id)

  req <- request(url) %>%
    req_headers(
      Authorization = paste0("Bearer ", api_key),
      "Notion-Version" = api_version,
      "Content-Type" = "application/json"
    ) %>%
    req_body_json(list(
      properties = setNames(
        list(list(
          title = list(
            list(
              type = "text",
              text = list(content = new_name)
            )
          )
        )),
        name_property
      )
    )) %>%
    req_method("PATCH")

  tryCatch({
    resp <- req_perform(req)
    data <- resp_body_json(resp)

    # Check if name was actually set
    name_in_response <- if (!is.null(data$properties[[name_property]]$title) &&
                             length(data$properties[[name_property]]$title) > 0) {
      data$properties[[name_property]]$title[[1]]$plain_text
    } else {
      NA_character_
    }

    if (!is.na(name_in_response) && name_in_response == new_name) {
      return(list(success = TRUE, error = NA))
    } else {
      return(list(success = FALSE, error = "Name not set in response"))
    }
  }, error = function(e) {
    return(list(success = FALSE, error = as.character(e)))
  })
}

if (nrow(pages_to_update) > 0) {
  cat("\nUpdating page names...\n")

  # Update each page
  results <- pages_to_update %>%
    rowwise() %>%
    mutate(
      result = list(update_page_name(page_id, book_title, NAME_PROPERTY, api_key, NOTION_API_VERSION)),
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
      select(page_id, book_title, error) %>%
      print(n = 10)
  }

  # Save results
  write.csv(results, "notion_name_update_results.csv", row.names = FALSE)
  cat("\n📄 Results saved to: notion_name_update_results.csv\n")

  # Verification ------------------------------------------------------------

  cat("\n=== Verification ===\n")

  if (nrow(results) > 0 && any(results$success)) {
    first_success <- results %>% filter(success) %>% slice(1)

    cat(sprintf("Verifying page: %s\n", first_success$page_id))

    # Fetch the page to verify name
    verify_url <- paste0("https://api.notion.com/v1/pages/", first_success$page_id)

    verify_req <- request(verify_url) %>%
      req_headers(
        Authorization = paste0("Bearer ", api_key),
        "Notion-Version" = NOTION_API_VERSION
      )

    verify_resp <- req_perform(verify_req)
    page_data <- resp_body_json(verify_resp)

    name_prop <- page_data$properties[[NAME_PROPERTY]]
    verified_name <- if (!is.null(name_prop$title) && length(name_prop$title) > 0) {
      name_prop$title[[1]]$plain_text
    } else {
      NA_character_
    }

    if (!is.na(verified_name)) {
      cat(sprintf("✓ Name verified on page!\n"))
      cat(sprintf("  Name: %s\n", verified_name))
    } else {
      cat("⚠ No name found on verified page\n")
    }
  }
} else {
  cat("\nNo pages need updating - all pages either have names or don't have book titles.\n")
}
