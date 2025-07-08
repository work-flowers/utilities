
library(notionR)
library(tidyverse)
library(keyring)

# Define your Notion database ID (copy from URL, no need for hyphens)
DATABASE_ID <-  "21691b0711ac80b38e40e6c1178b3c62"  # Meeting Notes DB

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
    identifier = `properties.Issue Identifier.rich_text.plain_text`,
    issue_id = `properties.Issue ID.rich_text.plain_text`
  ) 


# Save as CSV
write.csv(clean, "of_tasks_export.csv", row.names = FALSE)

test <- db |> 
  filter(id == "22a91b07-11ac-8026-a4da-d4d209387806")
