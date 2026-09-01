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

study_years <- 2020:2025
comparison_years <- 2023:2025
analysis_version <- "sap-v1.0-amendments-001-002"

regional_annual_path <- file.path(
  "data", "processed", "regional_annual.parquet"
)

regional_age_sex_path <- file.path(
  "data", "processed", "regional_age_sex_rates.parquet"
)

regional_standardised_path <- file.path(
  "data", "processed", "regional_standardised_rates.parquet"
)

table_directory <- file.path("output", "tables")
figure_data_directory <- file.path(
  table_directory, "figure_data"
)
figure_directory <- file.path("output", "figures")
candidate_figure_directory <- file.path(
  figure_directory, "candidates"
)
supplement_figure_directory <- file.path(
  figure_directory,
  "supplement",
  "regional_age_sex"
)

rank_table_path <- file.path(
  table_directory,
  "table_06_regional_rank_2025.csv"
)
change_table_path <- file.path(
  table_directory,
  "table_06_regional_change_2021_2025.csv"
)
variation_table_path <- file.path(
  table_directory,
  "table_06_regional_variation_2020_2025.csv"
)
map_ready_table_path <- file.path(
  table_directory,
  "table_06_regional_map_ready_2025.csv"
)

primary_figure_stem <- (
  "figure_04_regional_standardised_rates_2025"
)

candidate_figure_stems <- c(
  rank = "figure_04a_regional_standardised_rates_2025",
  crude_standardised = (
    "figure_04b_regional_crude_standardised_2025"
  ),
  change = "figure_04c_regional_annual_change_2023_2025",
  heatmap = "figure_04d_regional_crude_rate_heatmap_2020_2025",
  trends = "figure_04e_regional_standardised_trends_2020_2025",
  rebound = "figure_04f_regional_growth_rebound_2024_2025"
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

regional_annual <- read_parquet(
  regional_annual_path,
  as_data_frame = TRUE
) %>%
  mutate(region_code = as.character(region_code)) %>%
  arrange(region_code, study_year)

regional_age_sex <- read_parquet(
  regional_age_sex_path,
  as_data_frame = TRUE
) %>%
  mutate(
    region_code = as.character(region_code),
    age_code = as.character(age_code),
    sex_code = as.character(sex_code)
  ) %>%
  arrange(region_code, age_code, sex_code, study_year)

regional_standardised <- read_parquet(
  regional_standardised_path,
  as_data_frame = TRUE
) %>%
  mutate(region_code = as.character(region_code)) %>%
  arrange(region_code, study_year)

stopifnot(
  nrow(regional_annual) == 78L,
  nrow(regional_age_sex) == 468L,
  nrow(regional_standardised) == 78L,
  setequal(regional_annual$study_year, study_years),
  setequal(regional_age_sex$study_year, study_years),
  setequal(regional_standardised$study_year, study_years),
  n_distinct(regional_annual$region_code) == 13L,
  n_distinct(regional_age_sex$region_code) == 13L,
  n_distinct(regional_standardised$region_code) == 13L,
  identical(
    unique(regional_annual$analysis_version),
    analysis_version
  ),
  identical(
    unique(regional_age_sex$analysis_version),
    analysis_version
  ),
  identical(
    unique(regional_standardised$analysis_version),
    analysis_version
  ),
  !anyDuplicated(
    regional_annual[c("study_year", "region_code")]
  ),
  !anyDuplicated(
    regional_standardised[c("study_year", "region_code")]
  ),
  !anyDuplicated(
    regional_age_sex[
      c(
        "study_year",
        "region_code",
        "age_code",
        "sex_code"
      )
    ]
  )
)

region_display_lookup <- regional_annual %>%
  distinct(region_code, region_name) %>%
  mutate(
    region_display = case_when(
      region_code == "5" ~ "Overseas regions/departments",
      region_code == "93" ~ "Provence-Alpes-Côte d'Azur/Corse",
      TRUE ~ region_name
    ),
    geographic_scope = if_else(
      region_code == "5",
      "Overseas aggregate",
      "Metropolitan grouping"
    )
  )

regional_annual <- regional_annual %>%
  left_join(
    region_display_lookup,
    by = c("region_code", "region_name"),
    relationship = "many-to-one"
  ) %>%
  group_by(region_code) %>%
  arrange(study_year, .by_group = TRUE) %>%
  mutate(
    expenditure_percentage_change = (
      reimbursed_expenditure_eur /
        lag(reimbursed_expenditure_eur) - 1
    ) * 100
  ) %>%
  ungroup()

regional_standardised <- regional_standardised %>%
  left_join(
    region_display_lookup,
    by = c("region_code", "region_name"),
    relationship = "many-to-one"
  ) %>%
  group_by(region_code) %>%
  arrange(study_year, .by_group = TRUE) %>%
  mutate(
    standardised_plot_rate_per_100000 = if_else(
      !is.na(standardised_rate_per_100000),
      standardised_rate_per_100000,
      (
        standardised_rate_lower_per_100000 +
          standardised_rate_upper_per_100000
      ) / 2
    ),
    standardised_rate_percentage_change = (
      standardised_rate_per_100000 /
        lag(standardised_rate_per_100000) - 1
    ) * 100
  ) %>%
  ungroup()

regional_age_sex <- regional_age_sex %>%
  left_join(
    region_display_lookup,
    by = c("region_code", "region_name"),
    relationship = "many-to-one"
  ) %>%
  mutate(
    age_group = factor(
      unname(age_labels[age_code]),
      levels = unname(age_labels)
    ),
    sex = factor(
      unname(sex_labels[sex_code]),
      levels = unname(sex_labels)
    ),
    beneficiary_rate_plot_per_100000 = if_else(
      !is.na(beneficiary_rate_per_100000),
      beneficiary_rate_per_100000,
      (
        beneficiary_rate_lower_per_100000 +
          beneficiary_rate_upper_per_100000
      ) / 2
    )
  )

stopifnot(
  all(!is.na(regional_annual$region_display)),
  all(!is.na(regional_standardised$region_display)),
  all(!is.na(regional_age_sex$region_display)),
  all(!is.na(regional_age_sex$age_group)),
  all(!is.na(regional_age_sex$sex)),
  all(
    regional_standardised %>%
      filter(study_year >= 2022L) %>%
      pull(ambiguous_cells) == 0L
  )
)

rank_2025 <- regional_standardised %>%
  filter(study_year == 2025L) %>%
  left_join(
    regional_annual %>%
      filter(study_year == 2025L) %>%
      select(
        region_code,
        beneficiaries,
        boxes,
        reimbursed_expenditure_eur
      ),
    by = "region_code",
    relationship = "one-to-one"
  ) %>%
  arrange(desc(standardised_rate_per_100000)) %>%
  mutate(
    standardised_rank = row_number(),
    crude_rank = rank(
      -crude_rate_per_100000,
      ties.method = "min"
    ),
    national_scope_rank = standardised_rank,
    metropolitan_rank = if_else(
      region_code == "5",
      NA_integer_,
      rank(
        if_else(
          region_code == "5",
          NA_real_,
          -standardised_rate_per_100000
        ),
        na.last = "keep",
        ties.method = "min"
      )
    ),
    crude_standardised_difference = (
      standardised_rate_per_100000 -
        crude_rate_per_100000
    ),
    ratio_to_regional_median = (
      standardised_rate_per_100000 /
        median(standardised_rate_per_100000)
    )
  )

regional_changes <- regional_annual %>%
  select(
    study_year,
    region_code,
    region_name,
    region_display,
    geographic_scope,
    beneficiaries,
    beneficiary_rate_per_100000,
    boxes,
    reimbursed_expenditure_eur,
    beneficiaries_absolute_change,
    beneficiaries_percentage_change,
    beneficiary_rate_absolute_change,
    beneficiary_rate_percentage_change,
    boxes_percentage_change,
    expenditure_percentage_change
  ) %>%
  left_join(
    regional_standardised %>%
      select(
        study_year,
        region_code,
        standardised_rate_per_100000,
        standardised_rate_percentage_change,
        standardisation_status
      ),
    by = c("study_year", "region_code"),
    relationship = "one-to-one"
  ) %>%
  filter(study_year >= 2021L) %>%
  arrange(study_year, region_code)

regional_variation_input <- bind_rows(
  regional_standardised %>%
    mutate(sensitivity_scope = "all_13_regional_groupings"),
  regional_standardised %>%
    filter(region_code != "5") %>%
    mutate(sensitivity_scope = "metropolitan_12_groupings")
)

regional_variation <- regional_variation_input %>%
  group_by(study_year, sensitivity_scope) %>%
  summarise(
    regions = n(),
    crude_rate_min_per_100000 = min(crude_rate_per_100000),
    crude_rate_median_per_100000 = median(
      crude_rate_per_100000
    ),
    crude_rate_max_per_100000 = max(crude_rate_per_100000),
    crude_rate_range_per_100000 = (
      crude_rate_max_per_100000 -
        crude_rate_min_per_100000
    ),
    crude_rate_max_min_ratio = (
      crude_rate_max_per_100000 /
        crude_rate_min_per_100000
    ),
    crude_rate_coefficient_variation_pct = (
      sd(crude_rate_per_100000) /
        mean(crude_rate_per_100000) * 100
    ),
    standardised_complete_regions = sum(
      !is.na(standardised_rate_per_100000)
    ),
    standardised_rate_min_per_100000 = if (
      all(!is.na(standardised_rate_per_100000))
    ) {
      min(standardised_rate_per_100000)
    } else {
      NA_real_
    },
    standardised_rate_median_per_100000 = if (
      all(!is.na(standardised_rate_per_100000))
    ) {
      median(standardised_rate_per_100000)
    } else {
      NA_real_
    },
    standardised_rate_max_per_100000 = if (
      all(!is.na(standardised_rate_per_100000))
    ) {
      max(standardised_rate_per_100000)
    } else {
      NA_real_
    },
    standardised_rate_range_per_100000 = if (
      all(!is.na(standardised_rate_per_100000))
    ) {
      max(standardised_rate_per_100000) -
        min(standardised_rate_per_100000)
    } else {
      NA_real_
    },
    standardised_rate_max_min_ratio = if (
      all(!is.na(standardised_rate_per_100000))
    ) {
      max(standardised_rate_per_100000) /
        min(standardised_rate_per_100000)
    } else {
      NA_real_
    },
    standardised_rate_coefficient_variation_pct = if (
      all(!is.na(standardised_rate_per_100000))
    ) {
      sd(standardised_rate_per_100000) /
        mean(standardised_rate_per_100000) * 100
    } else {
      NA_real_
    },
    standardised_summary_status = if_else(
      standardised_complete_regions == regions,
      "complete_point_estimates",
      "not_summarised_due_to_interval_estimates"
    ),
    .groups = "drop"
  ) %>%
  mutate(
    historical_window_amendment_id = "001",
    amendment_id = "002",
    analysis_version = analysis_version
  )

map_ready_2025 <- rank_2025 %>%
  transmute(
    study_year,
    region_code,
    region_name,
    geographic_scope,
    beneficiaries,
    crude_rate_per_100000,
    standardised_rate_per_100000,
    standardised_rank,
    standardisation_status,
    geometry_status = "official_geometry_not_yet_joined",
    historical_window_amendment_id,
    amendment_id,
    analysis_version
  )

stopifnot(
  nrow(rank_2025) == 13L,
  nrow(regional_changes) == 65L,
  nrow(regional_variation) == 12L,
  nrow(map_ready_2025) == 13L,
  !any(is.na(rank_2025$standardised_rate_per_100000)),
  setequal(rank_2025$standardised_rank, 1:13),
  all(
    regional_variation$standardised_complete_regions[
      regional_variation$study_year >= 2022L
    ] == regional_variation$regions[
      regional_variation$study_year >= 2022L
    ]
  )
)

regional_caption <- wrap_maradian_text(
  c(
    "Source: Open Medic and the French National Institute",
    "of Statistics and Economic Studies.",
    "Rates use average annual population denominators.",
    "Standardised rates use the 2025 France-wide age-sex",
    "distribution. Regional group 93 combines Provence-Alpes-",
    "Côte d'Azur and Corse; group 5 aggregates overseas regions",
    "and departments. Analyses are descriptive."
  )
)

regional_interval_caption <- wrap_maradian_text(
  c(
    "Source: Open Medic and the French National Institute",
    "of Statistics and Economic Studies.",
    "Standardised rates use the 2025 France-wide age-sex",
    "distribution. Vertical ranges in 2020-2021 represent",
    "disclosure-control uncertainty, not confidence intervals.",
    "Regional group 93 combines Provence-Alpes-Côte d'Azur",
    "and Corse; group 5 aggregates overseas regions and",
    "departments. Analyses are descriptive."
  )
)

change_caption <- wrap_maradian_text(
  c(
    "Source: Open Medic and the French National Institute",
    "of Statistics and Economic Studies.",
    "Changes are calculated from age-sex-standardised rates.",
    "All 13 regional groupings had point estimates from 2022.",
    "Analyses are descriptive and do not identify causes."
  )
)

rank_plot_data <- rank_2025 %>%
  arrange(standardised_rate_per_100000) %>%
  mutate(
    region_display = factor(
      region_display,
      levels = region_display
    )
  )

rank_figure <- ggplot(
  rank_plot_data,
  aes(
    x = standardised_rate_per_100000,
    y = region_display,
    fill = geographic_scope
  )
) +
  geom_col(width = 0.68) +
  geom_text(
    aes(
      label = label_number(
        accuracy = 0.1,
        big.mark = ","
      )(standardised_rate_per_100000)
    ),
    hjust = -0.08,
    size = 3.1,
    colour = maradian_colours[["navy"]]
  ) +
  scale_x_continuous(
    labels = label_number(
      accuracy = 1,
      big.mark = ","
    ),
    expand = expansion(mult = c(0, 0.17))
  ) +
  scale_fill_manual(
    values = c(
      "Metropolitan grouping" = maradian_colours[["blue"]],
      "Overseas aggregate" = maradian_colours[["coral"]]
    )
  ) +
  labs(
    title = paste(
      "Age-sex-standardised reimbursed glucagon-like",
      "peptide-1 receptor agonist use"
    ),
    subtitle = "Regional rates per 100,000 residents; France, 2025",
    x = "Beneficiaries per 100,000 residents",
    y = NULL,
    caption = regional_caption
  ) +
  theme_maradian()

dumbbell_plot_data <- rank_2025 %>%
  arrange(standardised_rate_per_100000) %>%
  mutate(
    region_display = factor(
      region_display,
      levels = region_display
    )
  )

dumbbell_figure <- ggplot(
  dumbbell_plot_data,
  aes(y = region_display)
) +
  geom_segment(
    aes(
      x = crude_rate_per_100000,
      xend = standardised_rate_per_100000,
      yend = region_display
    ),
    linewidth = 0.8,
    colour = maradian_colours[["grid"]]
  ) +
  geom_point(
    aes(
      x = crude_rate_per_100000,
      colour = "Crude rate"
    ),
    size = 2.8
  ) +
  geom_point(
    aes(
      x = standardised_rate_per_100000,
      colour = "Age-sex-standardised rate"
    ),
    size = 2.8
  ) +
  scale_x_continuous(
    labels = label_number(accuracy = 1, big.mark = ","),
    expand = expansion(mult = c(0.05, 0.08))
  ) +
  scale_colour_manual(
    values = c(
      "Crude rate" = maradian_colours[["teal"]],
      "Age-sex-standardised rate" = (
        maradian_colours[["violet"]]
      )
    )
  ) +
  labs(
    title = "Crude and age-sex-standardised regional rates",
    subtitle = "Beneficiaries per 100,000 residents; France, 2025",
    x = "Beneficiaries per 100,000 residents",
    y = NULL,
    caption = regional_caption
  ) +
  theme_maradian()

change_plot_data <- regional_changes %>%
  filter(study_year %in% comparison_years) %>%
  mutate(
    region_display = factor(
      region_display,
      levels = as.character(rank_plot_data$region_display)
    ),
    study_year = factor(
      study_year,
      levels = comparison_years
    )
  )

change_figure <- ggplot(
  change_plot_data,
  aes(
    x = study_year,
    y = region_display,
    fill = standardised_rate_percentage_change
  )
) +
  geom_tile(colour = maradian_colours[["background"]]) +
  geom_text(
    aes(
      label = label_percent(
        accuracy = 0.1,
        scale = 1
      )(standardised_rate_percentage_change)
    ),
    size = 2.8,
    colour = maradian_colours[["navy"]]
  ) +
  scale_fill_gradient2(
    low = maradian_colours[["coral"]],
    mid = maradian_colours[["background"]],
    high = maradian_colours[["teal"]],
    midpoint = 0,
    labels = label_percent(accuracy = 1, scale = 1),
    name = "Annual change"
  ) +
  labs(
    title = "Annual change in standardised regional beneficiary rates",
    subtitle = "France, 2023-2025",
    x = "Calendar year",
    y = NULL,
    caption = change_caption
  ) +
  theme_maradian() +
  theme(legend.position = "bottom")

heatmap_order <- rank_2025 %>%
  arrange(desc(standardised_rate_per_100000)) %>%
  pull(region_display)

heatmap_plot_data <- regional_annual %>%
  mutate(
    region_display = factor(
      region_display,
      levels = rev(heatmap_order)
    )
  )

heatmap_figure <- ggplot(
  heatmap_plot_data,
  aes(
    x = study_year,
    y = region_display,
    fill = beneficiary_rate_per_100000
  )
) +
  geom_tile(colour = maradian_colours[["background"]]) +
  scale_x_continuous(breaks = study_years) +
  scale_fill_gradientn(
    colours = c(
      maradian_colours[["background"]],
      maradian_colours[["teal"]],
      maradian_colours[["blue"]],
      maradian_colours[["violet"]]
    ),
    labels = label_number(accuracy = 1, big.mark = ","),
    name = "Crude rate"
  ) +
  labs(
    title = "Regional variation in reimbursed beneficiary rates",
    subtitle = "Crude rates per 100,000 residents; France, 2020-2025",
    x = "Calendar year",
    y = NULL,
    caption = regional_caption
  ) +
  theme_maradian() +
  theme(legend.position = "bottom")

trend_plot_data <- regional_standardised %>%
  mutate(
    region_display = factor(
      region_display,
      levels = heatmap_order
    )
  )

trend_figure <- ggplot(
  trend_plot_data,
  aes(
    x = study_year,
    y = standardised_plot_rate_per_100000,
    group = region_code
  )
) +
  geom_line(
    aes(y = standardised_rate_per_100000),
    colour = maradian_colours[["blue"]],
    linewidth = 0.8,
    na.rm = TRUE
  ) +
  geom_point(
    data = trend_plot_data %>%
      filter(!is.na(standardised_rate_per_100000)),
    colour = maradian_colours[["blue"]],
    size = 1.7
  ) +
  geom_errorbar(
    data = trend_plot_data %>%
      filter(is.na(standardised_rate_per_100000)),
    aes(
      ymin = standardised_rate_lower_per_100000,
      ymax = standardised_rate_upper_per_100000
    ),
    width = 0.12,
    linewidth = 0.7,
    colour = maradian_colours[["coral"]]
  ) +
  geom_point(
    data = trend_plot_data %>%
      filter(is.na(standardised_rate_per_100000)),
    shape = 21,
    fill = maradian_colours[["background"]],
    colour = maradian_colours[["coral"]],
    size = 2
  ) +
  facet_wrap(vars(region_display), ncol = 4) +
  scale_x_continuous(
    breaks = c(2020, 2022, 2024),
    minor_breaks = NULL
  ) +
  scale_y_continuous(
    labels = label_number(
      accuracy = 1,
      scale_cut = cut_short_scale()
    ),
    expand = expansion(mult = c(0.05, 0.12))
  ) +
  labs(
    title = "Regional trends in standardised beneficiary rates",
    subtitle = "France, 2020-2025; common vertical scale",
    x = "Calendar year",
    y = "Beneficiaries per 100,000 residents",
    caption = regional_interval_caption
  ) +
  theme_maradian(base_size = 10)

rebound_plot_data <- regional_changes %>%
  filter(study_year %in% c(2024L, 2025L)) %>%
  select(
    region_code,
    region_name,
    region_display,
    geographic_scope,
    study_year,
    beneficiaries_percentage_change
  ) %>%
  pivot_wider(
    names_from = study_year,
    values_from = beneficiaries_percentage_change,
    names_prefix = "change_"
  ) %>%
  mutate(
    acceleration_percentage_points = change_2025 - change_2024
  )

rebound_figure <- ggplot(
  rebound_plot_data,
  aes(
    x = change_2024,
    y = change_2025,
    fill = geographic_scope
  )
) +
  geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed",
    colour = maradian_colours[["neutral"]]
  ) +
  geom_point(
    shape = 21,
    size = 4.8,
    colour = maradian_colours[["navy"]]
  ) +
  geom_text(
    aes(label = region_code),
    size = 2.5,
    colour = maradian_colours[["navy"]]
  ) +
  scale_x_continuous(
    labels = label_percent(accuracy = 1, scale = 1)
  ) +
  scale_y_continuous(
    labels = label_percent(accuracy = 1, scale = 1)
  ) +
  scale_fill_manual(
    values = c(
      "Metropolitan grouping" = maradian_colours[["blue"]],
      "Overseas aggregate" = maradian_colours[["coral"]]
    )
  ) +
  labs(
    title = "Regional beneficiary growth rebounded in 2025",
    subtitle = paste(
      "Annual percentage change; labels show regional codes"
    ),
    x = "Change from 2023 to 2024",
    y = "Change from 2024 to 2025",
    caption = change_caption
  ) +
  theme_maradian()

dir.create(
  table_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

write_csv(rank_2025, rank_table_path, na = "")
write_csv(regional_changes, change_table_path, na = "")
write_csv(regional_variation, variation_table_path, na = "")
write_csv(map_ready_2025, map_ready_table_path, na = "")

figure_data_paths <- c(
  rank = save_maradian_figure_data(
    rank_plot_data %>%
      transmute(
        study_year,
        region_code,
        region_name,
        region_display = as.character(region_display),
        geographic_scope,
        beneficiaries,
        crude_rate_per_100000,
        standardised_rate_per_100000,
        standardised_rank,
        standardisation_status
      ),
    figure_data_directory,
    candidate_figure_stems[["rank"]]
  ),
  crude_standardised = save_maradian_figure_data(
    dumbbell_plot_data %>%
      transmute(
        study_year,
        region_code,
        region_name,
        region_display = as.character(region_display),
        crude_rate_per_100000,
        standardised_rate_per_100000,
        crude_standardised_difference,
        standardisation_status
      ),
    figure_data_directory,
    candidate_figure_stems[["crude_standardised"]]
  ),
  change = save_maradian_figure_data(
    change_plot_data %>%
      transmute(
        study_year = as.integer(as.character(study_year)),
        region_code,
        region_name,
        region_display = as.character(region_display),
        beneficiaries_percentage_change,
        beneficiary_rate_percentage_change,
        boxes_percentage_change,
        expenditure_percentage_change,
        standardised_rate_percentage_change
      ),
    figure_data_directory,
    candidate_figure_stems[["change"]]
  ),
  heatmap = save_maradian_figure_data(
    heatmap_plot_data %>%
      transmute(
        study_year,
        region_code,
        region_name,
        region_display = as.character(region_display),
        beneficiaries,
        population_average,
        beneficiary_rate_per_100000
      ),
    figure_data_directory,
    candidate_figure_stems[["heatmap"]]
  ),
  trends = save_maradian_figure_data(
    trend_plot_data %>%
      transmute(
        study_year,
        region_code,
        region_name,
        region_display = as.character(region_display),
        standardised_rate_per_100000,
        standardised_rate_lower_per_100000,
        standardised_rate_upper_per_100000,
        standardised_plot_rate_per_100000,
        standardisation_status
      ),
    figure_data_directory,
    candidate_figure_stems[["trends"]]
  ),
  rebound = save_maradian_figure_data(
    rebound_plot_data,
    figure_data_directory,
    candidate_figure_stems[["rebound"]]
  )
)

main_manifest_entries <- data.frame(
  figure_id = c(
    "04", "04a", "04b", "04c", "04d", "04e", "04f"
  ),
  figure_stem = c(
    primary_figure_stem,
    candidate_figure_stems[["rank"]],
    candidate_figure_stems[["crude_standardised"]],
    candidate_figure_stems[["change"]],
    candidate_figure_stems[["heatmap"]],
    candidate_figure_stems[["trends"]],
    candidate_figure_stems[["rebound"]]
  ),
  data_file = c(
    figure_data_paths[["rank"]],
    figure_data_paths[["rank"]],
    figure_data_paths[["crude_standardised"]],
    figure_data_paths[["change"]],
    figure_data_paths[["heatmap"]],
    figure_data_paths[["trends"]],
    figure_data_paths[["rebound"]]
  ),
  figure_role = c(
    "primary",
    "candidate_primary_duplicate",
    rep("alternative", 5)
  ),
  analysis_scope = c(
    rep("regional", 7)
  ),
  analytical_window = c(
    "2025",
    "2025",
    "2025",
    "2023-2025",
    "2020-2025",
    "2020-2025",
    "2024-2025"
  ),
  notes = c(
    "Same plotted data as figure 04a.",
    "2025 standardised ranking; overseas aggregate highlighted.",
    "Crude and age-sex-standardised rates compared directly.",
    "Annual change in standardised rates; all cells are point estimates.",
    "Exact crude rates; ordered by 2025 standardised rate.",
    "Intervals in 2020-2021 are disclosure-control bounds, not confidence intervals.",
    "Regional codes identify points; diagonal denotes unchanged growth."
  ),
  stringsAsFactors = FALSE
)

age_sex_figure_data_paths <- character()
age_sex_figure_paths <- character()
age_sex_manifest_entries <- list()

regional_codes <- sort(unique(regional_age_sex$region_code))

for (current_region_code in regional_codes) {
  current_data <- regional_age_sex %>%
    filter(region_code == current_region_code) %>%
    arrange(age_code, sex_code, study_year)

  stopifnot(
    nrow(current_data) == 36L,
    n_distinct(current_data$region_name) == 1L
  )

  current_region_name <- unique(current_data$region_name)
  current_stem <- paste0(
    "figure_s04_",
    current_region_code,
    "_age_sex_rates_2020_2025"
  )

  current_figure <- ggplot(
    current_data,
    aes(
      x = study_year,
      y = beneficiary_rate_plot_per_100000,
      colour = sex,
      group = sex
    )
  ) +
    geom_line(
      aes(y = beneficiary_rate_per_100000),
      linewidth = 0.95,
      na.rm = TRUE
    ) +
    geom_point(
      data = current_data %>%
        filter(!is.na(beneficiary_rate_per_100000)),
      size = 2.2
    ) +
    geom_errorbar(
      data = current_data %>%
        filter(is.na(beneficiary_rate_per_100000)),
      aes(
        ymin = beneficiary_rate_lower_per_100000,
        ymax = beneficiary_rate_upper_per_100000
      ),
      width = 0.12,
      linewidth = 0.7
    ) +
    geom_point(
      data = current_data %>%
        filter(
          cell_status == "structural_zero_supported"
        ),
      shape = 21,
      fill = maradian_colours[["gold"]],
      size = 2.4
    ) +
    facet_wrap(
      vars(age_group),
      ncol = 1,
      scales = "free_y"
    ) +
    scale_x_continuous(breaks = study_years) +
    scale_y_continuous(
      labels = label_number(
        accuracy = 0.1,
        scale_cut = cut_short_scale()
      ),
      expand = expansion(mult = c(0.05, 0.14))
    ) +
    scale_colour_manual(
      values = maradian_sex_colours,
      breaks = unname(sex_labels),
      drop = FALSE
    ) +
    labs(
      title = paste(
        "Reimbursed glucagon-like peptide-1 receptor agonist",
        "use by age and sex"
      ),
      subtitle = paste0(
        current_region_name,
        "; age-sex-specific rates, 2020-2025"
      ),
      x = "Calendar year",
      y = "Beneficiaries per 100,000 residents",
      caption = wrap_maradian_text(
        c(
          "Source: Open Medic and the French National Institute",
          "of Statistics and Economic Studies.",
          "Vertical ranges represent disclosure-control uncertainty,",
          "not confidence intervals. Gold-filled markers denote",
          "supported structural zeros. Panels use independent",
          "vertical scales. Analyses are descriptive."
        )
      )
    ) +
    theme_maradian()

  current_data_path <- save_maradian_figure_data(
    current_data %>%
      transmute(
        study_year,
        region_code,
        region_name,
        age_code,
        age_group = as.character(age_group),
        sex_code,
        sex = as.character(sex),
        cell_status,
        beneficiaries,
        beneficiary_lower_bound,
        beneficiary_upper_bound,
        population_average,
        beneficiary_rate_per_100000,
        beneficiary_rate_lower_per_100000,
        beneficiary_rate_upper_per_100000
      ),
    figure_data_directory,
    current_stem
  )

  current_figure_paths <- save_maradian_plot(
    current_figure,
    supplement_figure_directory,
    current_stem,
    height = 8.2
  )

  age_sex_figure_data_paths <- c(
    age_sex_figure_data_paths,
    current_data_path
  )
  age_sex_figure_paths <- c(
    age_sex_figure_paths,
    current_figure_paths
  )
  age_sex_manifest_entries[[current_region_code]] <- data.frame(
    figure_id = paste0("S04-", current_region_code),
    figure_stem = current_stem,
    data_file = current_data_path,
    figure_role = "supplementary",
    analysis_scope = "regional_age_sex",
    analytical_window = "2020-2025",
    notes = paste0(
      "Age-sex-specific regional rates for region code ",
      current_region_code,
      "; intervals reflect disclosure-control uncertainty."
    ),
    stringsAsFactors = FALSE
  )
}

manifest_entries <- bind_rows(
  main_manifest_entries,
  bind_rows(age_sex_manifest_entries)
)

figure_manifest_path <- update_maradian_figure_manifest(
  manifest_entries,
  table_directory
)

main_figure_paths <- c(
  save_maradian_plot(
    rank_figure,
    figure_directory,
    primary_figure_stem,
    width = 10,
    height = 7.5
  ),
  save_maradian_plot(
    rank_figure,
    candidate_figure_directory,
    candidate_figure_stems[["rank"]],
    width = 10,
    height = 7.5
  ),
  save_maradian_plot(
    dumbbell_figure,
    candidate_figure_directory,
    candidate_figure_stems[["crude_standardised"]],
    width = 10,
    height = 7.5
  ),
  save_maradian_plot(
    change_figure,
    candidate_figure_directory,
    candidate_figure_stems[["change"]],
    width = 10,
    height = 7.5
  ),
  save_maradian_plot(
    heatmap_figure,
    candidate_figure_directory,
    candidate_figure_stems[["heatmap"]],
    width = 10,
    height = 7.5
  ),
  save_maradian_plot(
    trend_figure,
    candidate_figure_directory,
    candidate_figure_stems[["trends"]],
    width = 11,
    height = 8.5
  ),
  save_maradian_plot(
    rebound_figure,
    candidate_figure_directory,
    candidate_figure_stems[["rebound"]],
    width = 8.5,
    height = 7
  )
)

created_paths <- c(
  rank_table_path,
  change_table_path,
  variation_table_path,
  map_ready_table_path,
  figure_data_paths,
  age_sex_figure_data_paths,
  main_figure_paths,
  age_sex_figure_paths,
  figure_manifest_path
)

stopifnot(
  all(file.exists(created_paths)),
  all(file.info(created_paths)$size > 0),
  length(age_sex_figure_data_paths) == 13L,
  length(age_sex_figure_paths) == 26L,
  nrow(manifest_entries) == 20L
)

cat("created ", rank_table_path, "\n", sep = "")
cat("created ", change_table_path, "\n", sep = "")
cat("created ", variation_table_path, "\n", sep = "")
cat("created ", map_ready_table_path, "\n", sep = "")
for (path in figure_data_paths) {
  cat("created ", path, "\n", sep = "")
}
for (path in age_sex_figure_data_paths) {
  cat("created ", path, "\n", sep = "")
}
cat("updated ", figure_manifest_path, "\n", sep = "")
for (path in main_figure_paths) {
  cat("created ", path, "\n", sep = "")
}
for (path in age_sex_figure_paths) {
  cat("created ", path, "\n", sep = "")
}
cat("Regional tables, figures and supplements passed.\n")
