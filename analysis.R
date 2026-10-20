# ------------------------------------------------------------------
# State government web accessibility, six months before the ADA
# Title II deadline
#
# analysis.R
#
# Reads the axe-core scan results in data/ and produces the tables
# and figures used in README.md.
#
# How to run in RStudio:
#   1. File > Open Project (or open this file) so the working directory
#      is the repository root. If in doubt:
#      Session > Set Working Directory > To Source File Location
#   2. Source the whole file (Ctrl+Shift+S on Windows).
#   Outputs land in output/ and figures/.
# ------------------------------------------------------------------

# ---- 0. Packages -------------------------------------------------
needed <- c("tidyverse", "scales")
missing <- needed[!needed %in% rownames(installed.packages())]
if (length(missing) > 0) install.packages(missing)
library(tidyverse)
library(scales)

# usmap is optional; the choropleth is skipped if it is not installed.
have_usmap <- requireNamespace("usmap", quietly = TRUE)
if (!have_usmap) message("Package usmap not installed; figure 4 (map) will be skipped. install.packages('usmap') to add it.")

dir.create("output", showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)

# ---- 1. Data -----------------------------------------------------
pages <- read_csv("data/pages_scanned.csv", show_col_types = FALSE)
viol  <- read_csv("data/violations.csv",    show_col_types = FALSE)
nodes <- read_csv("data/nodes.csv",         show_col_types = FALSE)

cat_levels <- c("medicaid", "ehdi", "partc")
cat_labels <- c("Medicaid application", "EHDI newborn hearing", "Part C early intervention")

pages <- pages %>%
  mutate(
    category = factor(category, levels = cat_levels, labels = cat_labels),
    # A page counts as scanned only if axe ran AND the server returned 200.
    # A 403 bot wall or a 503 error page is not the page a family would see.
    usable = scan_ok & http_status == 200
  )

viol <- viol %>%
  mutate(category = factor(category, levels = cat_levels, labels = cat_labels)) %>%
  inner_join(pages %>% select(state, category, usable, state_name), by = c("state", "category")) %>%
  filter(usable)

# The DOJ Title II rule requires WCAG 2.1 Level AA. axe tags each rule with the
# WCAG version and level it maps to, so the headline numbers use only rules in
# that scope. Best-practice rules and WCAG 2.2-only rules are reported separately.
scope <- viol %>% filter(is_wcag21aa_scope)

# ---- 2. Page-level summary --------------------------------------
page_summary <- pages %>%
  filter(usable) %>%
  select(state, state_name, category, final_url, page_title) %>%
  left_join(
    scope %>%
      group_by(state, category) %>%
      summarise(
        rules_failed    = n(),
        elements_failed = sum(n_nodes),
        critical        = sum(n_critical),
        serious         = sum(n_serious),
        moderate        = sum(n_moderate),
        minor           = sum(n_minor),
        .groups = "drop"
      ),
    by = c("state", "category")
  ) %>%
  mutate(across(rules_failed:minor, ~ replace_na(.x, 0)),
         any_failure = rules_failed > 0,
         any_serious_or_critical = (critical + serious) > 0) %>%
  arrange(state, category)

write_csv(page_summary, "output/page_summary.csv")

# ---- 3. State-level summary -------------------------------------
state_summary <- page_summary %>%
  group_by(state, state_name) %>%
  summarise(
    pages_scanned        = n(),
    pages_with_failure   = sum(any_failure),
    rules_failed         = sum(rules_failed),
    elements_failed      = sum(elements_failed),
    serious_or_critical  = sum(critical + serious),
    elements_per_page    = elements_failed / pages_scanned,
    .groups = "drop"
  ) %>%
  arrange(desc(elements_per_page)) %>%
  mutate(rank = row_number())

write_csv(state_summary, "output/state_summary.csv")

# ---- 4. Rule-level summary --------------------------------------
n_pages_usable <- sum(pages$usable)

rule_summary <- scope %>%
  group_by(rule_id, help, impact, wcag_criteria, help_url) %>%
  summarise(
    pages_affected   = n_distinct(paste(state, category)),
    elements_failed  = sum(n_nodes),
    .groups = "drop"
  ) %>%
  mutate(share_of_pages = pages_affected / n_pages_usable) %>%
  arrange(desc(pages_affected))

write_csv(rule_summary, "output/rule_summary.csv")

# Rules outside the Title II scope, for the appendix
out_of_scope_summary <- viol %>%
  filter(!is_wcag21aa_scope) %>%
  mutate(bucket = if_else(is_best_practice_only, "Best practice (not a WCAG failure)", "WCAG 2.2 only")) %>%
  group_by(bucket, rule_id, help) %>%
  summarise(pages_affected = n_distinct(paste(state, category)), elements_failed = sum(n_nodes), .groups = "drop") %>%
  arrange(bucket, desc(pages_affected))

write_csv(out_of_scope_summary, "output/out_of_scope_rules.csv")

# ---- 5. Headline numbers ----------------------------------------
headline <- list(
  pages_listed          = nrow(pages),
  pages_usable          = n_pages_usable,
  pages_not_usable      = nrow(pages) - n_pages_usable,
  states_covered        = n_distinct(page_summary$state),
  pages_with_failure    = sum(page_summary$any_failure),
  pct_pages_with_failure = mean(page_summary$any_failure),
  pages_with_serious    = sum(page_summary$any_serious_or_critical),
  pct_pages_with_serious = mean(page_summary$any_serious_or_critical),
  states_all_pages_clean = sum(state_summary$pages_with_failure == 0),
  median_elements_per_page = median(page_summary$elements_failed),
  mean_elements_per_page   = mean(page_summary$elements_failed),
  total_elements_failed    = sum(page_summary$elements_failed),
  top_rule                 = rule_summary$rule_id[1],
  top_rule_share           = rule_summary$share_of_pages[1],
  top3_rules_share_of_elements = sum(head(rule_summary %>% arrange(desc(elements_failed)), 3)$elements_failed) / sum(rule_summary$elements_failed)
)

headline_txt <- c(
  sprintf("Pages listed: %d; usable scans (axe ran, HTTP 200): %d; excluded: %d", headline$pages_listed, headline$pages_usable, headline$pages_not_usable),
  sprintf("States and DC with at least one usable page: %d", headline$states_covered),
  sprintf("Pages with at least one WCAG 2.1 A/AA failure: %d of %d (%s)", headline$pages_with_failure, headline$pages_usable, percent(headline$pct_pages_with_failure, 1)),
  sprintf("Pages with at least one serious or critical failure: %d of %d (%s)", headline$pages_with_serious, headline$pages_usable, percent(headline$pct_pages_with_serious, 1)),
  sprintf("States where every scanned page was clean: %d", headline$states_all_pages_clean),
  sprintf("Failing elements per page: median %s, mean %s, total %d", headline$median_elements_per_page, round(headline$mean_elements_per_page, 1), headline$total_elements_failed),
  sprintf("Most common failing rule: %s, on %s of pages", headline$top_rule, percent(headline$top_rule_share, 1)),
  sprintf("Share of all failing elements explained by the three biggest rules: %s", percent(headline$top3_rules_share_of_elements, 1))
)
writeLines(headline_txt, "output/headline_numbers.txt")
cat(paste(headline_txt, collapse = "\n"), "\n")

# ---- 6. Figures --------------------------------------------------
# A single colorblind-safe palette, used consistently.
pal_impact <- c(critical = "#7a0177", serious = "#c51b8a", moderate = "#f768a1", minor = "#fbb4b9")
pal_cat    <- c("Medicaid application" = "#1b7837", "EHDI newborn hearing" = "#762a83", "Part C early intervention" = "#2166ac")

theme_set(
  theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank(),
          plot.title.position = "plot",
          plot.caption.position = "plot",
          plot.caption = element_text(color = "grey40", hjust = 0))
)

scan_date <- format(as.Date(min(pages$scan_timestamp_utc)), "%d %B %Y")
caption_txt <- str_wrap(sprintf("Source: axe-core %s run against each page on %s. WCAG 2.1 A/AA rules only. Automated checks find a subset of barriers; zero is not conformance.",
                                pages$axe_version[1], scan_date), 110)

# Figure 1: state ranking
fig1 <- state_summary %>%
  mutate(state_name = fct_reorder(state_name, elements_per_page),
         severity = case_when(serious_or_critical > 0 ~ "At least one serious or critical failure",
                              elements_failed > 0     ~ "Moderate or minor failures only",
                              TRUE                    ~ "No failures found"),
         severity = factor(severity, levels = c("At least one serious or critical failure", "Moderate or minor failures only", "No failures found"))) %>%
  ggplot(aes(x = elements_per_page, y = state_name)) +
  geom_segment(aes(x = 0, xend = elements_per_page, yend = state_name), color = "grey75") +
  geom_point(aes(color = severity), size = 3) +
  scale_color_manual(values = c("At least one serious or critical failure" = "#c51b8a",
                                "Moderate or minor failures only" = "#f768a1",
                                "No failures found" = "#2166ac"),
                     name = NULL, drop = FALSE) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Failing elements per page, by state",
       subtitle = "Medicaid application, newborn hearing (EHDI) and Part C early intervention pages, WCAG 2.1 A/AA",
       x = "Failing elements per scanned page", y = NULL, caption = caption_txt) +
  theme(legend.position = "top", axis.text.y = element_text(size = 9))
ggsave("figures/fig1_state_ranking.png", fig1, width = 9, height = 12, dpi = 150, bg = "white")

# Figure 2: state by program heatmap
fig2 <- page_summary %>%
  mutate(state_name = factor(state_name, levels = levels(fct_reorder(state_summary$state_name, state_summary$elements_per_page)))) %>%
  ggplot(aes(x = category, y = state_name, fill = elements_failed)) +
  geom_tile(color = "white", linewidth = 0.6) +
  geom_text(aes(label = elements_failed, color = elements_failed > 20), size = 3) +
  scale_fill_gradient(low = "#f7f4f9", high = "#7a0177", trans = "sqrt", name = "Failing\nelements") +
  scale_color_manual(values = c(`TRUE` = "white", `FALSE` = "black"), guide = "none") +
  scale_x_discrete(position = "top") +
  labs(title = "Where the failures sit: state by program page",
       subtitle = "Blank tile = page could not be scanned (bot wall, error page, or unreachable)",
       x = NULL, y = NULL, caption = caption_txt) +
  theme(panel.grid = element_blank(), axis.text.y = element_text(size = 9))
ggsave("figures/fig2_state_program_heatmap.png", fig2, width = 8, height = 13, dpi = 150, bg = "white")

# Figure 3: top rules
fig3 <- rule_summary %>%
  slice_max(pages_affected, n = 12, with_ties = FALSE) %>%
  mutate(help = str_wrap(help, 55), help = fct_reorder(help, share_of_pages),
         impact = factor(impact, levels = names(pal_impact))) %>%
  ggplot(aes(x = share_of_pages, y = help, fill = impact)) +
  geom_col() +
  geom_text(aes(label = percent(share_of_pages, 1)), hjust = -0.15, size = 3.5) +
  scale_fill_manual(values = pal_impact, name = "axe impact", drop = FALSE) +
  scale_x_continuous(labels = percent_format(1), expand = expansion(mult = c(0, 0.15))) +
  labs(title = "The twelve most common WCAG 2.1 A/AA failures",
       subtitle = sprintf("Share of %d scanned pages failing each rule", n_pages_usable),
       x = "Share of pages", y = NULL, caption = caption_txt) +
  theme(legend.position = "top")
ggsave("figures/fig3_top_rules.png", fig3, width = 10, height = 7.5, dpi = 150, bg = "white")

# Figure 4: map (optional). Wrapped in tryCatch because usmap and ggplot2
# versions occasionally disagree about theme elements.
if (have_usmap) {
  tryCatch({
    fig4 <- usmap::plot_usmap(data = state_summary, values = "elements_per_page", regions = "states", color = "white") +
      scale_fill_gradient(low = "#f7f4f9", high = "#7a0177", trans = "sqrt", name = "Failing elements\nper page", na.value = "grey90") +
      labs(title = "Failing elements per scanned page, by state", caption = caption_txt)
    ggsave("figures/fig4_map.png", fig4, width = 10, height = 6.5, dpi = 150, bg = "white")
  }, error = function(e) {
    message("Map skipped: ", conditionMessage(e), "\nUpdate ggplot2 and usmap (install.packages(c('ggplot2','usmap'))) and re-run to get figures/fig4_map.png.")
    if (file.exists("figures/fig4_map.png")) file.remove("figures/fig4_map.png")
  })
}

# Figure 5: impact mix by program type
fig5 <- page_summary %>%
  pivot_longer(c(critical, serious, moderate, minor), names_to = "impact", values_to = "n") %>%
  group_by(category, impact) %>% summarise(n = sum(n), .groups = "drop") %>%
  mutate(impact = factor(impact, levels = rev(names(pal_impact)))) %>%
  ggplot(aes(x = category, y = n, fill = impact)) +
  geom_col(width = 0.65) +
  scale_fill_manual(values = pal_impact, name = "axe impact") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  labs(title = "Failing elements by program page type and severity",
       x = NULL, y = "Failing elements (all scanned pages)", caption = caption_txt)
ggsave("figures/fig5_impact_by_program.png", fig5, width = 9, height = 6, dpi = 150, bg = "white")

# ---- 7. Tables for the README -----------------------------------
md_table <- function(df) {
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  paste(c(hdr, sep, rows), collapse = "\n")
}

worst <- state_summary %>% slice_head(n = 10) %>%
  transmute(Rank = rank, State = state_name, `Pages scanned` = pages_scanned,
            `Failing elements` = elements_failed, `Per page` = round(elements_per_page, 1),
            `Serious or critical` = serious_or_critical)
best <- state_summary %>% arrange(elements_per_page, desc(pages_scanned)) %>% slice_head(n = 10) %>%
  transmute(State = state_name, `Pages scanned` = pages_scanned,
            `Failing elements` = elements_failed, `Per page` = round(elements_per_page, 1))
top_rules_tbl <- rule_summary %>% slice_head(n = 10) %>%
  transmute(Rule = rule_id, `What it means` = help, Impact = impact, `WCAG` = wcag_criteria,
            `Pages affected` = pages_affected, `Share` = percent(share_of_pages, 1), `Elements` = elements_failed)

writeLines(c("## Ten states with the most failing elements per page", md_table(worst), "",
             "## Ten states with the fewest", md_table(best), "",
             "## Ten most common failing rules", md_table(top_rules_tbl)),
           "output/readme_tables.md")

# Pages that could not be scanned, for the limitations section
excluded <- pages %>% filter(!usable) %>%
  transmute(state, category, url = requested_url, http_status, error = str_trunc(coalesce(error, ""), 120))
write_csv(excluded, "output/pages_excluded.csv")

message("Done. See output/ and figures/.")
