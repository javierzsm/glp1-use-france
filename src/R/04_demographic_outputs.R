suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(scales)
})

source(
  file.path("src", "R", "00_plot_theme.R"),
  local = TRUE
)

study_years <- 2020:2025
rate_multiplier <- 100000
analysis_version <- "sap-v1.0-amendment-001"

age_sex_path <- file.path(
  "data",
  "interim",
  "open_medic",
  "full",
  "open_medic_atc4_age_sex.parquet"
)

denominator_path <- file.path(
  "data",
  "interim",
  "insee",
  "full",
  "insee_annual_denominators.parquet"
)

national_path <- file.path(
  "data",
  "processed",
  "national_annual.parquet"
)

processed_directory <- file.path(
  "data",
  "processed"
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

processed_path <- file.path(
  processed_directory,
  "demographic_rates.parquet"
)

annual_table_path <- file.path(
  table_directory,
  "table_03_demographic_rates_2020_2025.csv"
)

change_table_path <- file.path(
  table_directory,
  "table_03_age_sex_change_2020_2025.csv"
)

qc_table_path <- file.path(
  table_directory,
  "qc_03_demographic_reconciliation_2020_2025.csv"
)

primary_figure_stem <- (
  "figure_03_age_sex_rates_2020_2025"
)

candidate_figure_stems <- c(
  levels = "figure_03a_age_sex_rates_2020_2025",
  indexed = "figure_03b_age_sex_indexed_2020_2025",
  change = "figure_03c_age_sex_change_2020_2025"
)

age_labels <- c(
  "0" = "0-19 years",
  "20" = "20-59 years",
  "60" = "60 years or older"
)

sex_labels <- c(
  "1" = "Male",
  "2" = "Female"
)

age_levels <- unname(age_labels)
sex_levels <- unname(sex_labels)

age_sex_source <- read_parquet(
  age_sex_path,
  as_data_frame = TRUE
) %>%
  mutate(
    age_code = as.character(age_code),
    sex_code = as.character(sex_code)
  ) %>%
  filter(year %in% study_years)

denominator_source <- read_parquet(
  denominator_path,
  as_data_frame = TRUE
) %>%
  mutate(
    age_code = as.character(age_code),
    sex_code = as.character(sex_code)
  )

national <- read_parquet(
  national_path,
  as_data_frame = TRUE
) %>%
  filter(study_year %in% study_years) %>%
  arrange(study_year)

required_age_sex_columns <- c(
  "year",
  "atc_level",
  "aggregation",
  "atc_code",
  "age_code",
  "sex_code",
  "beneficiaries",
  "boxes",
  "source_file"
)

required_denominator_columns <- c(
  "study_year",
  "analysis_region_code",
  "age_code",
  "sex_code",
  "population_average",
  "population_start_status",
  "population_end_status"
)

stopifnot(
  all(required_age_sex_columns %in% names(age_sex_source)),
  all(
    required_denominator_columns %in%
      names(denominator_source)
  ),
  identical(unique(age_sex_source$atc_level), "ATC4"),
  identical(
    unique(age_sex_source$aggregation),
    "age_sex"
  ),
  identical(unique(age_sex_source$atc_code), "A10BJ"),
  setequal(age_sex_source$year, study_years),
  !anyDuplicated(
    age_sex_source[c("year", "age_code", "sex_code")]
  ),
  all(age_sex_source$beneficiaries >= 0),
  identical(
    unique(national$analysis_version),
    analysis_version
  )
)

known_strata <- age_sex_source %>%
  filter(
    age_code %in% names(age_labels),
    sex_code %in% names(sex_labels)
  ) %>%
  mutate(
    age_group = factor(
      unname(age_labels[age_code]),
      levels = age_levels
    ),
    sex = factor(
      unname(sex_labels[sex_code]),
      levels = sex_levels
    )
  )

unknown_strata <- age_sex_source %>%
  filter(
    !age_code %in% names(age_labels) |
      !sex_code %in% names(sex_labels)
  )

stopifnot(
  nrow(known_strata) == length(study_years) * 6L,
  !anyDuplicated(
    known_strata[c("year", "age_code", "sex_code")]
  )
)

population <- denominator_source %>%
  filter(
    study_year %in% study_years,
    analysis_region_code == "FR",
    age_code %in% names(age_labels),
    sex_code %in% names(sex_labels)
  ) %>%
  transmute(
    year = study_year,
    age_code,
    sex_code,
    population_average,
    population_start_status,
    population_end_status
  )

stopifnot(
  nrow(population) == length(study_years) * 6L,
  !anyDuplicated(
    population[c("year", "age_code", "sex_code")]
  ),
  all(population$population_average > 0)
)

six_stratum_rates <- known_strata %>%
  transmute(
    study_year = year,
    demographic_scope = "age_sex",
    age_code,
    age_group = as.character(age_group),
    sex_code,
    sex = as.character(sex),
    beneficiaries = as.numeric(beneficiaries),
    boxes = as.numeric(boxes),
    open_medic_source_file = source_file
  ) %>%
  left_join(
    population %>% rename(study_year = year),
    by = c("study_year", "age_code", "sex_code"),
    relationship = "one-to-one"
  ) %>%
  arrange(age_code, sex_code, study_year) %>%
  group_by(age_code, sex_code) %>%
  mutate(
    beneficiary_rate_per_100000 = (
      beneficiaries / population_average * rate_multiplier
    ),
    beneficiary_rate_index_2020 = (
      beneficiary_rate_per_100000 /
        first(beneficiary_rate_per_100000) * 100
    ),
    beneficiary_rate_percentage_change = (
      beneficiary_rate_per_100000 /
        lag(beneficiary_rate_per_100000) - 1
    ) * 100
  ) %>%
  ungroup()

stopifnot(
  nrow(six_stratum_rates) == 36L,
  all(six_stratum_rates$population_average > 0),
  all(is.finite(
    six_stratum_rates$beneficiary_rate_per_100000
  )),
  all(
    six_stratum_rates %>%
      filter(study_year == 2020L) %>%
      pull(beneficiary_rate_index_2020) == 100
  )
)

age_specific_rates <- six_stratum_rates %>%
  group_by(study_year, age_code, age_group) %>%
  summarise(
    demographic_scope = "age",
    sex_code = "ALL",
    sex = "All sexes",
    beneficiaries = sum(beneficiaries),
    boxes = sum(boxes),
    population_average = sum(population_average),
    population_start_status = paste(
      sort(unique(population_start_status)),
      collapse = "|"
    ),
    population_end_status = paste(
      sort(unique(population_end_status)),
      collapse = "|"
    ),
    open_medic_source_file = paste(
      sort(unique(open_medic_source_file)),
      collapse = "|"
    ),
    .groups = "drop"
  ) %>%
  arrange(age_code, study_year) %>%
  group_by(age_code) %>%
  mutate(
    beneficiary_rate_per_100000 = (
      beneficiaries / population_average * rate_multiplier
    ),
    beneficiary_rate_index_2020 = (
      beneficiary_rate_per_100000 /
        first(beneficiary_rate_per_100000) * 100
    ),
    beneficiary_rate_percentage_change = (
      beneficiary_rate_per_100000 /
        lag(beneficiary_rate_per_100000) - 1
    ) * 100
  ) %>%
  ungroup()

sex_specific_rates <- six_stratum_rates %>%
  group_by(study_year, sex_code, sex) %>%
  summarise(
    demographic_scope = "sex",
    age_code = "ALL",
    age_group = "All ages",
    beneficiaries = sum(beneficiaries),
    boxes = sum(boxes),
    population_average = sum(population_average),
    population_start_status = paste(
      sort(unique(population_start_status)),
      collapse = "|"
    ),
    population_end_status = paste(
      sort(unique(population_end_status)),
      collapse = "|"
    ),
    open_medic_source_file = paste(
      sort(unique(open_medic_source_file)),
      collapse = "|"
    ),
    .groups = "drop"
  ) %>%
  arrange(sex_code, study_year) %>%
  group_by(sex_code) %>%
  mutate(
    beneficiary_rate_per_100000 = (
      beneficiaries / population_average * rate_multiplier
    ),
    beneficiary_rate_index_2020 = (
      beneficiary_rate_per_100000 /
        first(beneficiary_rate_per_100000) * 100
    ),
    beneficiary_rate_percentage_change = (
      beneficiary_rate_per_100000 /
        lag(beneficiary_rate_per_100000) - 1
    ) * 100
  ) %>%
  ungroup()

demographic_rates <- bind_rows(
  six_stratum_rates,
  age_specific_rates,
  sex_specific_rates
) %>%
  mutate(
    beneficiary_measure_status = "direct_atc4_age_sex",
    amendment_id = "001",
    analysis_version = analysis_version,
    denominator_source_file = denominator_path
  ) %>%
  arrange(
    demographic_scope,
    age_code,
    sex_code,
    study_year
  )

stopifnot(
  nrow(demographic_rates) == 66L,
  sum(demographic_rates$demographic_scope == "age_sex") == 36L,
  sum(demographic_rates$demographic_scope == "age") == 18L,
  sum(demographic_rates$demographic_scope == "sex") == 12L
)

all_stratified_totals <- age_sex_source %>%
  group_by(year) %>%
  summarise(
    stratified_beneficiaries = sum(beneficiaries),
    stratified_boxes = sum(boxes),
    .groups = "drop"
  )

known_totals <- known_strata %>%
  group_by(year) %>%
  summarise(
    known_beneficiaries = sum(beneficiaries),
    known_boxes = sum(boxes),
    .groups = "drop"
  )

unknown_totals <- unknown_strata %>%
  group_by(year) %>%
  summarise(
    unknown_beneficiaries = sum(beneficiaries),
    unknown_boxes = sum(boxes),
    unknown_rows = n(),
    .groups = "drop"
  )

demographic_qc <- national %>%
  transmute(
    year = study_year,
    national_beneficiaries = beneficiaries,
    national_boxes = boxes
  ) %>%
  left_join(
    all_stratified_totals,
    by = "year",
    relationship = "one-to-one"
  ) %>%
  left_join(
    known_totals,
    by = "year",
    relationship = "one-to-one"
  ) %>%
  left_join(
    unknown_totals,
    by = "year",
    relationship = "one-to-one"
  ) %>%
  mutate(
    beneficiary_difference = (
      stratified_beneficiaries - national_beneficiaries
    ),
    boxes_difference = stratified_boxes - national_boxes,
    exact_beneficiary_reconciliation = (
      beneficiary_difference == 0
    ),
    unknown_beneficiary_share_pct = if_else(
      exact_beneficiary_reconciliation,
      unknown_beneficiaries / national_beneficiaries * 100,
      NA_real_
    ),
    reconciliation_status = if_else(
      exact_beneficiary_reconciliation,
      "exact",
      "small_nonadditivity_reviewed"
    ),
    amendment_id = "001",
    analysis_version = analysis_version
  )

stopifnot(
  nrow(demographic_qc) == length(study_years),
  all(demographic_qc$boxes_difference == 0),
  max(abs(demographic_qc$beneficiary_difference)) <= 12,
  all(
    demographic_qc$unknown_beneficiaries /
      demographic_qc$stratified_beneficiaries < 0.001
  )
)

endpoint_change <- six_stratum_rates %>%
  group_by(age_code, age_group, sex_code, sex) %>%
  summarise(
    start_year = first(study_year),
    end_year = last(study_year),
    start_rate_per_100000 = first(
      beneficiary_rate_per_100000
    ),
    end_rate_per_100000 = last(
      beneficiary_rate_per_100000
    ),
    absolute_change_per_100000 = (
      end_rate_per_100000 - start_rate_per_100000
    ),
    percentage_change = (
      end_rate_per_100000 / start_rate_per_100000 - 1
    ) * 100,
    compound_annual_growth_rate_percentage = (
      (end_rate_per_100000 / start_rate_per_100000) ^
        (1 / (end_year - start_year)) - 1
    ) * 100,
    .groups = "drop"
  )

demographic_caption <- wrap_maradian_text(
  c(
    "Source: Open Medic and the French National Institute",
    "of Statistics and Economic Studies.",
    "Rates use average annual population denominators.",
    "Unknown or masked age and sex categories were excluded",
    "without redistribution or imputation.",
    "Beneficiary analyses cover 2020-2025 under amendment 001."
  )
)

demographic_levels_caption <- wrap_maradian_text(
  c(
    "Source: Open Medic and the French National Institute",
    "of Statistics and Economic Studies.",
    "Rates use average annual population denominators.",
    "Unknown or masked age and sex categories were excluded",
    "without redistribution or imputation.",
    "Age-group panels use independent vertical scales.",
    "Beneficiary analyses cover 2020-2025 under amendment 001."
  )
)

demographic_change_caption <- wrap_maradian_text(
  c(
    "Source: Open Medic and the French National Institute",
    "of Statistics and Economic Studies.",
    "Rates use average annual population denominators.",
    "Unknown or masked age and sex categories were excluded",
    "without redistribution or imputation.",
    "Large relative changes in ages 0-19 reflect low 2020",
    "baseline rates.",
    "Beneficiary analyses cover 2020-2025 under amendment 001."
  )
)

plot_six_strata <- six_stratum_rates %>%
  mutate(
    age_group = factor(age_group, levels = age_levels),
    sex = factor(sex, levels = sex_levels)
  )

levels_figure <- ggplot(
  plot_six_strata,
  aes(
    x = study_year,
    y = beneficiary_rate_per_100000,
    colour = sex,
    group = sex
  )
) +
  geom_line(linewidth = 1.05) +
  geom_point(size = 2.6) +
  facet_wrap(
    vars(age_group),
    ncol = 1,
    scales = "free_y"
  ) +
  scale_x_continuous(breaks = study_years) +
  scale_y_continuous(
    labels = label_number(
      scale_cut = cut_short_scale(),
      accuracy = 0.1
    ),
    expand = expansion(mult = c(0.05, 0.12))
  ) +
  scale_colour_manual(
    values = maradian_sex_colours,
    breaks = sex_levels,
    drop = FALSE
  ) +
  labs(
    title = paste(
      "Reimbursed glucagon-like peptide-1 receptor agonist",
      "use by age and sex"
    ),
    subtitle = "Age-sex-specific rates; France, 2020-2025",
    x = "Calendar year",
    y = "Beneficiaries per 100,000 residents",
    caption = demographic_levels_caption
  ) +
  theme_maradian()

indexed_figure <- ggplot(
  plot_six_strata,
  aes(
    x = study_year,
    y = beneficiary_rate_index_2020,
    colour = sex,
    group = sex
  )
) +
  geom_hline(
    yintercept = 100,
    colour = maradian_colours[["grid"]],
    linewidth = 0.5
  ) +
  geom_line(linewidth = 1.05) +
  geom_point(size = 2.6) +
  facet_wrap(
    vars(age_group),
    ncol = 1
  ) +
  scale_x_continuous(breaks = study_years) +
  scale_y_continuous(
    labels = label_number(accuracy = 1),
    expand = expansion(mult = c(0.05, 0.12))
  ) +
  scale_colour_manual(
    values = maradian_sex_colours,
    breaks = sex_levels,
    drop = FALSE
  ) +
  labs(
    title = "Relative growth in age-sex-specific beneficiary rates",
    subtitle = "Index: 2020 = 100; France, 2020-2025",
    x = "Calendar year",
    y = "Index (2020 = 100)",
    caption = demographic_caption
  ) +
  theme_maradian()

change_plot_data <- endpoint_change %>%
  mutate(
    age_group = factor(age_group, levels = rev(age_levels)),
    sex = factor(sex, levels = sex_levels)
  )

change_figure <- ggplot(
  change_plot_data,
  aes(
    x = age_group,
    y = percentage_change,
    fill = sex
  )
) +
  geom_col(
    position = position_dodge(width = 0.72),
    width = 0.65
  ) +
  geom_text(
    aes(
      label = label_percent(
        accuracy = 0.1,
        scale = 1
      )(percentage_change)
    ),
    position = position_dodge(width = 0.72),
    hjust = -0.08,
    size = 3.2,
    colour = maradian_colours[["navy"]]
  ) +
  coord_flip() +
  scale_y_continuous(
    labels = label_percent(
      accuracy = 1,
      scale = 1
    ),
    expand = expansion(mult = c(0, 0.18))
  ) +
  scale_fill_manual(
    values = maradian_sex_colours,
    breaks = sex_levels,
    drop = FALSE
  ) +
  labs(
    title = "Growth in age-sex-specific beneficiary rates",
    subtitle = "Percentage change; France, 2020-2025",
    x = NULL,
    y = "Change from 2020",
    caption = demographic_change_caption
  ) +
  theme_maradian()

dir.create(
  processed_directory,
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(
  table_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

write_parquet(
  demographic_rates,
  processed_path
)
write_csv(
  demographic_rates,
  annual_table_path,
  na = ""
)
write_csv(
  endpoint_change,
  change_table_path,
  na = ""
)
write_csv(
  demographic_qc,
  qc_table_path,
  na = ""
)

figure_data_paths <- c(
  levels = save_maradian_figure_data(
    plot_six_strata %>%
      transmute(
        year = study_year,
        age_code,
        age_group = as.character(age_group),
        sex_code,
        sex = as.character(sex),
        beneficiaries,
        population_average,
        beneficiary_rate_per_100000
      ),
    figure_data_directory,
    candidate_figure_stems[["levels"]]
  ),
  indexed = save_maradian_figure_data(
    plot_six_strata %>%
      transmute(
        year = study_year,
        age_code,
        age_group = as.character(age_group),
        sex_code,
        sex = as.character(sex),
        beneficiary_rate_per_100000,
        beneficiary_rate_index_2020
      ),
    figure_data_directory,
    candidate_figure_stems[["indexed"]]
  ),
  change = save_maradian_figure_data(
    change_plot_data %>%
      transmute(
        age_code,
        age_group = as.character(age_group),
        sex_code,
        sex = as.character(sex),
        start_year,
        end_year,
        start_rate_per_100000,
        end_rate_per_100000,
        absolute_change_per_100000,
        percentage_change,
        compound_annual_growth_rate_percentage
      ),
    figure_data_directory,
    candidate_figure_stems[["change"]]
  )
)

figure_manifest_path <- update_maradian_figure_manifest(
  data.frame(
    figure_id = c("03", "03a", "03b", "03c"),
    figure_stem = c(
      primary_figure_stem,
      candidate_figure_stems[["levels"]],
      candidate_figure_stems[["indexed"]],
      candidate_figure_stems[["change"]]
    ),
    data_file = c(
      figure_data_paths[["levels"]],
      figure_data_paths[["levels"]],
      figure_data_paths[["indexed"]],
      figure_data_paths[["change"]]
    ),
    figure_role = c(
      "primary",
      "candidate_primary_duplicate",
      "alternative",
      "alternative"
    ),
    analysis_scope = "national_age_sex",
    analytical_window = "2020-2025",
    notes = c(
      "Same plotted data as figure 03a.",
      "Age-group panels use independent vertical scales.",
      "Values indexed to 2020 within age-sex stratum.",
      "Endpoint relative change; low 0-19 baseline rates require caution."
    ),
    stringsAsFactors = FALSE
  ),
  table_directory
)

figure_paths <- c(
  save_maradian_plot(
    levels_figure,
    figure_directory,
    primary_figure_stem,
    height = 8.2
  ),
  save_maradian_plot(
    levels_figure,
    candidate_figure_directory,
    candidate_figure_stems[["levels"]],
    height = 8.2
  ),
  save_maradian_plot(
    indexed_figure,
    candidate_figure_directory,
    candidate_figure_stems[["indexed"]],
    height = 8.2
  ),
  save_maradian_plot(
    change_figure,
    candidate_figure_directory,
    candidate_figure_stems[["change"]]
  )
)

cat("created ", processed_path, "\n", sep = "")
cat("created ", annual_table_path, "\n", sep = "")
cat("created ", change_table_path, "\n", sep = "")
cat("created ", qc_table_path, "\n", sep = "")
for (path in figure_data_paths) {
  cat("created ", path, "\n", sep = "")
}
cat("updated ", figure_manifest_path, "\n", sep = "")
for (path in figure_paths) {
  cat("created ", path, "\n", sep = "")
}
cat("Demographic datasets, tables and figures passed.\n")
