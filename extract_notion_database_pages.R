
library(notionR)
library(tidyverse)

# Define your Notion database ID (copy from URL, no need for hyphens)
DATABASE_ID <-  "21991b0711ac8103bdaddb2df65e6bba"  # Clay Contacts tb

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
  transmute(
    page_id = id,
    primary_email = `properties.Primary Email.email`,
    secondary_email = `properties.Secondary Email.email`
  )


output_long <- clean |> 
  pivot_longer(
    cols = c(primary_email, secondary_email),
    names_to = "email_type",
    values_to = "email"
  ) %>%
  filter(!is.na(email) & email != "") |> 
  mutate(
    email_type = case_when(
      email_type == "primary_email" ~ "Primary",
      email_type == "secondary_email" ~ "Secondary",
      TRUE ~ email_type # fallback in case of other values
    )
  )

# Save as CSV
write.csv(output_long, "notion_emails_export.csv", row.names = FALSE)

cat("✅ Export complete: notion_emails_export.csv\n")