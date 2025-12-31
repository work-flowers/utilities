
# Test script to update a single page cover and inspect the response

pacman::p_load(httr2, keyring, jsonlite)

# Configuration
api_key <- key_get("notion", "work.flowers")
page_id <- "2d991b07-11ac-8100-9476-f80478c01d7f"  # First page from CSV
cover_url <- "http://books.google.com/books/publisher/content?id=3qMFEQAAQBAJ&printsec=frontcover&img=1&zoom=1&imgtk=AFLRE73dvUJXRuWlHC_4EcXHPBAgYz9-_hGOqJNeSOswF6zZ-j-yXZaS2hLt3Jf9q_y_Z748xtpSKu7mEVwiNEoc3cAH6JQUhdYbj1eaUkKB4OdUQsx-ERug7sTJAX2gvb4c2v8b-W2Q&source=gbs_api&fife=w1000-h1000"

cat("Testing cover update with API version 2025-09-03\n")
cat(sprintf("Page ID: %s\n", page_id))
cat(sprintf("Cover URL: %s\n\n", cover_url))

# Make the API call
url <- paste0("https://api.notion.com/v1/pages/", page_id)

req <- request(url) %>%
  req_headers(
    Authorization = paste0("Bearer ", api_key),
    "Notion-Version" = "2025-09-03",
    "Content-Type" = "application/json"
  ) %>%
  req_body_json(list(
    cover = list(
      type = "external",
      external = list(url = cover_url)
    )
  )) %>%
  req_method("PATCH")

cat("Sending PATCH request...\n")
resp <- req_perform(req)

cat(sprintf("Response status: %d\n\n", resp_status(resp)))

# Parse response
response_data <- resp_body_json(resp)

# Check cover in response
cat("=== Response Cover Info ===\n")
if (!is.null(response_data$cover)) {
  cat(sprintf("Cover type: %s\n", response_data$cover$type))
  if (response_data$cover$type == "external") {
    cat(sprintf("Cover URL in response: %s\n", response_data$cover$external$url))
  }
} else {
  cat("⚠️  No cover in response!\n")
}

# Now fetch the page to verify
cat("\n=== Verifying by fetching page ===\n")
verify_req <- request(url) %>%
  req_headers(
    Authorization = paste0("Bearer ", api_key),
    "Notion-Version" = "2025-09-03"
  )

verify_resp <- req_perform(verify_req)
verify_data <- resp_body_json(verify_resp)

if (!is.null(verify_data$cover)) {
  cat(sprintf("✓ Cover found!\n"))
  cat(sprintf("  Type: %s\n", verify_data$cover$type))
  if (verify_data$cover$type == "external") {
    cat(sprintf("  URL: %s\n", verify_data$cover$external$url))
  }
} else {
  cat("⚠️  No cover found on page after update\n")
}

# Print full response for debugging
cat("\n=== Full PATCH Response (first 1000 chars) ===\n")
cat(substr(toJSON(response_data, auto_unbox = TRUE, pretty = TRUE), 1, 1000))
cat("\n...")
