suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(scales)
  library(tidyr)
})

source(
  file.path("src", "R", "00_plot_theme.R"),
  local = TRUE
)

input_path <- file.path(
  "data",
  "processed",
  "national_annual.parquet"
)

table_directory <- file.path(
  "output",
  "tables"
)

figure_data_directory <- file.path(
  table_directory,
  "figure_data"
)

figure_directory <- file.path(
  "output",
  "figures"
)

candidate_figure_directory <- file.path(
  figure_directory,
  "candidates"
)

annual_table_path <- file.path(
  table_directory,
  "table_01_national_beneficiaries_2020_2025.csv"
)

summary_table_path <- file.path(
  table_directory,
  "table_01_national_change_2020_2025.csv"
)

primary_figure_stem <- (
  "figure_01_national_beneficiaries_rate_2020_2025"
)

candidate_figure_stems <- c(
  levels = "figure_01a_national_levels_2020_2025",
  indexed = "figure_01b_national_indexed_2020_2025",
  annual_change = (
    "figure_01c_national_annual_change_2021_2025"
  )
)

national <- read_parquet(
  input_path,
  as_data_frame = TRUE
) %>%
  arrange(study_year)

required_columns <- c(
  "study_year",
  "beneficiaries",
  "population_average",
  "beneficiary_rate_per_100000",
  "beneficiaries_absolute_change",
  "beneficiaries_percentage_change",
  "beneficiary_rate_absolute_change",
  "beneficiary_rate_percentage_change",
  "beneficiary_measure_status",
  "analysis_version"
)

stopifnot(
  all(required_columns %in% names(national)),
  nrow(national) == 7L,
  identical(as.integer(national$study_year), 2019:2025),
  identical(
    unique(national$analysis_version),
    "sap-v1.0-amendment-001"
  ),
  is.na(national$beneficiaries[1]),
  is.na(national$beneficiary_rate_per_100000[1]),
  all(national$beneficiaries[-1] >= 0),
  all(national$population_average > 0),
  all(national$beneficiary_rate_per_100000[-1] >= 0),
  national$beneficiary_measure_status[1] ==
    "not_estimable_from_aggregated_source"
)

calculate_endpoint_change <- function(values, years) {
  stopifnot(length(values) == length(years))

  valid <- !is.na(values) & !is.na(years)
  values <- values[valid]
  years <- years[valid]

  initial <- first(values)
  final <- last(values)
  initial_year <- first(years)
  final_year <- last(years)
  periods <- final_year - initial_year

  stopifnot(
    !is.na(initial),
    !is.na(final),
    initial > 0,
    final >= 0,
    periods > 0
  )

  tibble(
    start_year = initial_year,
    end_year = final_year,
    start_value = initial,
    end_value = final,
    absolute_change = final - initial,
    percentage_change = (
      final / initial - 1
    ) * 100,
    compound_annual_growth_rate_percentage = (
      (final / initial)^(1 / periods) - 1
    ) * 100
  )
}

annual_table <- national %>%
  filter(study_year >= 2020L) %>%
  transmute(
    year = study_year,
    beneficiaries = round(beneficiaries),
    average_population = round(population_average),
    beneficiaries_per_100000 = round(
      beneficiary_rate_per_100000,
      1
    ),
    annual_beneficiary_change = round(
      beneficiaries_absolute_change
    ),
    annual_beneficiary_percentage_change = round(
      beneficiaries_percentage_change,
      1
    ),
    annual_rate_change_per_100000 = round(
      beneficiary_rate_absolute_change,
      1
    ),
    annual_rate_percentage_change = round(
      beneficiary_rate_percentage_change,
      1
    )
  )

beneficiary_summary <- calculate_endpoint_change(
  national$beneficiaries,
  national$study_year
) %>%
  mutate(
    measure = "Annual beneficiary count",
    .before = 1
  )

rate_summary <- calculate_endpoint_change(
  national$beneficiary_rate_per_100000,
  national$study_year
) %>%
  mutate(
    measure = "Beneficiary rate per 100,000 residents",
    .before = 1
  )

summary_table <- bind_rows(
  beneficiary_summary,
  rate_summary
) %>%
  mutate(
    across(
      where(is.numeric),
      ~ round(.x, 1)
    )
  )

plot_data <- national %>%
  select(
    study_year,
    beneficiaries,
    beneficiary_rate_per_100000
  ) %>%
  pivot_longer(
    cols = -study_year,
    names_to = "measure",
    values_to = "value"
  ) %>%
  filter(!is.na(value)) %>%
  mutate(
    measure = recode(
      measure,
      beneficiaries = "Annual beneficiaries",
      beneficiary_rate_per_100000 = (
        "Beneficiaries per 100,000 residents"
      )
    ),
    measure = factor(
      measure,
      levels = c(
        "Annual beneficiaries",
        "Beneficiaries per 100,000 residents"
      )
    )
  )

stopifnot(
  nrow(plot_data) == 12L,
  setequal(
    as.character(unique(plot_data$measure)),
    names(maradian_metric_colours)
  )
)

indexed_plot_data <- plot_data %>%
  group_by(measure) %>%
  arrange(study_year, .by_group = TRUE) %>%
  mutate(
    index_2020 = value / first(value) * 100
  ) %>%
  ungroup()

annual_change_plot_data <- national %>%
  filter(study_year >= 2021L) %>%
  select(
    study_year,
    beneficiaries_percentage_change,
    beneficiary_rate_percentage_change
  ) %>%
  pivot_longer(
    cols = -study_year,
    names_to = "measure",
    values_to = "annual_percentage_change"
  ) %>%
  mutate(
    measure = recode(
      measure,
      beneficiaries_percentage_change = (
        "Annual beneficiaries"
      ),
      beneficiary_rate_percentage_change = (
        "Beneficiaries per 100,000 residents"
      )
    ),
    measure = factor(
      measure,
      levels = names(maradian_metric_colours)
    )
  )

stopifnot(
  nrow(indexed_plot_data) == 12L,
  all(
    indexed_plot_data %>%
      group_by(measure) %>%
      summarise(
        baseline = first(index_2020),
        .groups = "drop"
      ) %>%
      pull(baseline) == 100
  ),
  nrow(annual_change_plot_data) == 10L,
  all(is.finite(
    annual_change_plot_data$annual_percentage_change
  ))
)

national_caption <- wrap_maradian_text(
  c(
    "Sources: Open Medic and the French National Institute",
    "of Statistics and Economic Studies.",
    "Beneficiaries had at least one reimbursed community",
    "dispensing during the calendar year.",
    "The 2019 class-level beneficiary count was not",
    "estimable because of a historical coding discontinuity."
  )
)

national_sources <- paste(
  "Open Medic; French National Institute of Statistics and",
  "Economic Studies (INSEE)."
)

national_caption_table <- data.frame(
  figure_id = c("01", "01a", "01b", "01c"),
  caption = c(
    paste(
      "Annual beneficiaries and beneficiary rates for reimbursed GLP-1",
      "receptor agonist dispensings in France, 2020–2025. Panels use",
      "independent vertical scales. Beneficiaries had at least one",
      "reimbursed community dispensing during the calendar year."
    ),
    paste(
      "Annual beneficiaries and beneficiary rates for reimbursed GLP-1",
      "receptor agonist dispensings in France, 2020–2025. Panels use",
      "independent vertical scales. Beneficiaries had at least one",
      "reimbursed community dispensing during the calendar year."
    ),
    paste(
      "Relative change in annual beneficiaries and beneficiary rates for",
      "reimbursed GLP-1 receptor agonist dispensings in France, 2020–2025,",
      "indexed to 2020 = 100 within each measure."
    ),
    paste(
      "Year-on-year percentage change in annual beneficiaries and",
      "beneficiary rates for reimbursed GLP-1 receptor agonist dispensings",
      "in France, 2021–2025."
    )
  ),
  sources = national_sources,
  stringsAsFactors = FALSE
)

national_levels_figure <- ggplot(
  plot_data,
  aes(
    x = study_year,
    y = value,
    colour = measure,
    group = measure
  )
) +
  geom_line(
    linewidth = 1.15
  ) +
  geom_point(
    size = 2.9
  ) +
  facet_wrap(
    vars(measure),
    ncol = 1,
    scales = "free_y"
  ) +
  scale_x_continuous(
    breaks = 2020:2025
  ) +
  scale_y_continuous(
    labels = label_number(
      scale_cut = cut_short_scale(),
      accuracy = 0.1
    ),
    expand = expansion(mult = c(0.05, 0.12))
  ) +
  scale_colour_manual(
    values = maradian_metric_colours,
    drop = FALSE
  ) +
  labs(
    title = paste(
      "Reimbursed use of glucagon-like peptide-1",
      "(GLP-1) receptor agonists"
    ),
    subtitle = "National beneficiary measures, France, 2020-2025",
    x = "Calendar year",
    y = NULL,
    caption = national_caption
  ) +
  theme_maradian() +
  theme(
    legend.position = "none"
  )

national_indexed_figure <- ggplot(
  indexed_plot_data,
  aes(
    x = study_year,
    y = index_2020,
    colour = measure,
    group = measure
  )
) +
  geom_hline(
    yintercept = 100,
    colour = maradian_colours[["grid"]],
    linewidth = 0.7
  ) +
  geom_line(linewidth = 1.15) +
  geom_point(size = 2.9) +
  scale_x_continuous(breaks = 2020:2025) +
  scale_y_continuous(
    labels = label_number(accuracy = 1),
    expand = expansion(mult = c(0.05, 0.12))
  ) +
  scale_colour_manual(
    values = maradian_metric_colours,
    drop = FALSE
  ) +
  labs(
    title = "Relative growth in national beneficiary measures",
    subtitle = "Index: 2020 = 100; France, 2020-2025",
    x = "Calendar year",
    y = "Index (2020 = 100)",
    caption = national_caption
  ) +
  theme_maradian()

national_annual_change_figure <- ggplot(
  annual_change_plot_data,
  aes(
    x = factor(study_year),
    y = annual_percentage_change,
    fill = measure
  )
) +
  geom_hline(
    yintercept = 0,
    colour = maradian_colours[["neutral"]],
    linewidth = 0.5
  ) +
  geom_col(
    position = position_dodge(width = 0.78),
    width = 0.7
  ) +
  geom_text(
    aes(
      label = label_percent(
        accuracy = 0.1,
        scale = 1
      )(annual_percentage_change)
    ),
    position = position_dodge(width = 0.78),
    vjust = -0.35,
    size = 3.2,
    colour = maradian_colours[["navy"]]
  ) +
  scale_y_continuous(
    labels = label_percent(
      accuracy = 1,
      scale = 1
    ),
    expand = expansion(mult = c(0.05, 0.18))
  ) +
  scale_fill_manual(
    values = maradian_metric_colours,
    drop = FALSE
  ) +
  labs(
    title = "Annual change in national beneficiary measures",
    subtitle = "France, 2021-2025",
    x = "Calendar year",
    y = "Change from previous year",
    caption = national_caption
  ) +
  theme_maradian()

dir.create(
  table_directory,
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(
  figure_directory,
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(
  candidate_figure_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

write_csv(
  annual_table,
  annual_table_path,
  na = ""
)
write_csv(
  summary_table,
  summary_table_path,
  na = ""
)

figure_data_paths <- c(
  levels = save_maradian_figure_data(
    plot_data %>%
      transmute(
        year = study_year,
        measure = as.character(measure),
        value
      ),
    figure_data_directory,
    candidate_figure_stems[["levels"]]
  ),
  indexed = save_maradian_figure_data(
    indexed_plot_data %>%
      transmute(
        year = study_year,
        measure = as.character(measure),
        source_value = value,
        index_2020
      ),
    figure_data_directory,
    candidate_figure_stems[["indexed"]]
  ),
  annual_change = save_maradian_figure_data(
    annual_change_plot_data %>%
      transmute(
        year = study_year,
        measure = as.character(measure),
        annual_percentage_change
      ),
    figure_data_directory,
    candidate_figure_stems[["annual_change"]]
  )
)

figure_manifest_path <- update_maradian_figure_manifest(
  data.frame(
    figure_id = c("01", "01a", "01b", "01c"),
    figure_stem = c(
      primary_figure_stem,
      candidate_figure_stems[["levels"]],
      candidate_figure_stems[["indexed"]],
      candidate_figure_stems[["annual_change"]]
    ),
    data_file = c(
      figure_data_paths[["levels"]],
      figure_data_paths[["levels"]],
      figure_data_paths[["indexed"]],
      figure_data_paths[["annual_change"]]
    ),
    figure_role = c(
      "primary",
      "candidate_primary_duplicate",
      "alternative",
      "alternative"
    ),
    analysis_scope = "national_beneficiary",
    analytical_window = c(
      "2020-2025",
      "2020-2025",
      "2020-2025",
      "2021-2025"
    ),
    notes = c(
      "Same plotted data as figure 01a.",
      "Panels use independent vertical scales.",
      "Values indexed to 2020 within measure.",
      "Percentage change from previous calendar year."
    ),
    stringsAsFactors = FALSE
  ),
  table_directory
)

caption_table_path <- save_maradian_caption_table(
  national_caption_table,
  table_directory,
  "figure_captions_national"
)

figure_paths <- c(
  save_maradian_plot_variants(
    national_levels_figure,
    figure_directory,
    primary_figure_stem
  ),
  save_maradian_plot_variants(
    national_levels_figure,
    candidate_figure_directory,
    candidate_figure_stems[["levels"]]
  ),
  save_maradian_plot_variants(
    national_indexed_figure,
    candidate_figure_directory,
    candidate_figure_stems[["indexed"]]
  ),
  save_maradian_plot_variants(
    national_annual_change_figure,
    candidate_figure_directory,
    candidate_figure_stems[["annual_change"]]
  )
)

cat("created ", annual_table_path, "\n", sep = "")
cat("created ", summary_table_path, "\n", sep = "")
for (path in figure_data_paths) {
  cat("created ", path, "\n", sep = "")
}
cat("updated ", figure_manifest_path, "\n", sep = "")
cat("created ", caption_table_path, "\n", sep = "")
for (path in figure_paths) {
  cat("created ", path, "\n", sep = "")
}
cat("National tables and visualisation candidates passed.\n")
