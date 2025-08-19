pacman::p_load(
  tidyverse,
  readr,
  jsonlite
  )

raw <- jsonlite::read_json("exported-zaps-2025-08-17T10_18_14.587Z.json", simplifyVector = FALSE)

df_zaps <- tibble(zap = raw$zaps) %>%
  transmute(
    title   = map_chr(zap, ~ pluck(.x, "title", .default = NA_character_)),
    nodes   = map(zap, ~ pluck(.x, "nodes", .default = list()))
  ) %>%
  mutate(
    root_id = map_chr(
      nodes,
      function(ns) {
        if (!is.list(ns) || length(ns) == 0) return(NA_character_)
        enframe(ns, name = "node_key", value = "node") %>%
          hoist(node, root_id = "root_id") %>%
          mutate(root_id = as.character(root_id)) %>%
          filter(!is.na(root_id) & nzchar(root_id)) %>%
          summarise(root_id = if (n()) first(root_id) else NA_character_) %>%
          pull(root_id)
      }
    )
  ) %>%
  select(root_id, title)
