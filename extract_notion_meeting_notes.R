
library(notionR)
library(tidyverse)
library(keyring)

# Define your Notion database ID (copy from URL, no need for hyphens)
DATABASE_ID <-  "1984d37f6b4081e6a46bfe5fdd6e44d9"  # Meeting Notes DB

# Fetch the entire database as a tibble
db <- getNotionDatabase(
  secret = key_get("notion", "work.flowers"),
  database = DATABASE_ID
)

# Inspect to confirm columns
print(names(db))

# You should see columns like: id, properties.Primary Email.email, properties.Secondary Email.email

# Extract needed columns into a clean dataframe
clean <- db %>%
  select(
    page_id = id,
    event_id = `properties.Google Calendar Event ID.rich_text.plain_text`,
    start_date = `properties.Date.date.start`,
    end_date = `properties.Date.date.end`
  ) |> 
  filter(!is.na(event_id))


# Save as CSV
write.csv(clean, "meeting_notes_export.csv", row.names = FALSE)
