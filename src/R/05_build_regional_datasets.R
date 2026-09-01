suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(readr)
  library(tidyr)
})

study_years <- 2020:2025
age_codes <- c("0", "20", "60")
sex_codes <- c("1", "2")
rate_multiplier <- 100000
analysis_version <- "sap-v1.0-amendments-001-002"
currency_reconciliation_tolerance_eur <- 0.02
floating_point_tolerance <- sqrt(.Machine$double.eps)

regional_path <- file.path(
  "data", "interim", "open_medic", "full",
  "open_medic_atc4_region.parquet"
)

regional_age_sex_path <- file.path(
  "data", "interim", "open_medic", "full",
  "open_medic_atc4_age_sex_region.parquet"
)

denominator_path <- file.path(
  "data", "interim", "insee", "full",
  "insee_annual_denominators.parquet"
)

national_path <- file.path(
  "data", "processed", "national_annual.parquet"
)

crosswalk_path <- file.path(
  "data", "metadata", "insee_region_crosswalk.csv"
)

processed_directory <- file.path("data", "processed")
table_directory <- file.path("output", "tables")

regional_annual_path <- file.path(
  processed_directory,
  "regional_annual.parquet"
)

regional_age_sex_output_path <- file.path(
  processed_directory,
  "regional_age_sex_rates.parquet"
)

regional_standardised_path <- file.path(
  processed_directory,
  "regional_standardised_rates.parquet"
)

regional_annual_table_path <- file.path(
  table_directory,
  "table_05_regional_annual_2020_2025.csv"
)

regional_age_sex_table_path <- file.path(
  table_directory,
  "table_05_regional_age_sex_rates_2020_2025.csv"
)

regional_standardised_table_path <- file.path(
  table_directory,
  "table_05_regional_standardised_rates_2020_2025.csv"
)

reconciliation_path <- file.path(
  table_directory,
  "qc_05_regional_reconciliation_2020_2025.csv"
)

cell_completeness_path <- file.path(
  table_directory,
  "qc_05_regional_cell_completeness_2020_2025.csv"
)

unknown_strata_path <- file.path(
  table_directory,
  "qc_05_regional_unknown_strata_2020_2025.csv"
)

regional_source <- read_parquet(
  regional_path,
  as_data_frame = TRUE
) %>%
  mutate(
    region_code = as.character(region_code),
    age_code = as.character(age_code),
    sex_code = as.character(sex_code)
  ) %>%
  filter(year %in% study_years)

regional_age_sex_source <- read_parquet(
  regional_age_sex_path,
  as_data_frame = TRUE
) %>%
  mutate(
    region_code = as.character(region_code),
    age_code = as.character(age_code),
    sex_code = as.character(sex_code)
  ) %>%
  filter(year %in% study_years)

denominator_source <- read_parquet(
  denominator_path,
  as_data_frame = TRUE
) %>%
  mutate(
    analysis_region_code = as.character(
      analysis_region_code
    ),
    age_code = as.character(age_code),
    sex_code = as.character(sex_code)
  )

national <- read_parquet(
  national_path,
  as_data_frame = TRUE
) %>%
  filter(study_year %in% study_years) %>%
  arrange(study_year)

region_lookup <- read_csv(
  crosswalk_path,
  col_types = cols(.default = col_character())
) %>%
  filter(analysis_scope == "regional") %>%
  distinct(
    analysis_region_code,
    analysis_region_name,
    analysis_scope,
    aggregation_rule
  ) %>%
  arrange(analysis_region_code)

analysis_regions <- region_lookup$analysis_region_code

stopifnot(
  nrow(region_lookup) == 13L,
  !anyDuplicated(region_lookup$analysis_region_code),
  setequal(
    analysis_regions,
    c(
      "5", "11", "24", "27", "28", "32", "44",
      "52", "53", "75", "76", "84", "93"
    )
  ),
  identical(unique(regional_source$atc_level), "ATC4"),
  identical(unique(regional_source$aggregation), "region"),
  identical(unique(regional_source$atc_code), "A10BJ"),
  identical(
    unique(regional_age_sex_source$aggregation),
    "age_sex_region"
  ),
  identical(
    unique(regional_age_sex_source$atc_code),
    "A10BJ"
  ),
  !anyDuplicated(
    regional_source[c("year", "region_code")]
  ),
  !anyDuplicated(
    regional_age_sex_source[
      c("year", "region_code", "age_code", "sex_code")
    ]
  )
)

regional_direct <- regional_source %>%
  filter(region_code %in% analysis_regions) %>%
  left_join(
    region_lookup,
    by = c("region_code" = "analysis_region_code"),
    relationship = "many-to-one"
  )

stopifnot(
  nrow(regional_direct) == length(study_years) * 13L,
  !any(is.na(regional_direct$analysis_region_name))
)

regional_population_strata <- denominator_source %>%
  filter(
    study_year %in% study_years,
    analysis_region_code %in% analysis_regions,
    age_code %in% age_codes,
    sex_code %in% sex_codes
  ) %>%
  select(
    study_year,
    analysis_region_code,
    age_code,
    sex_code,
    population_average,
    population_start_status,
    population_end_status
  )

stopifnot(
  nrow(regional_population_strata) == (
    length(study_years) * 13L * 6L
  ),
  !anyDuplicated(
    regional_population_strata[
      c(
        "study_year",
        "analysis_region_code",
        "age_code",
        "sex_code"
      )
    ]
  ),
  all(regional_population_strata$population_average > 0)
)

regional_population <- regional_population_strata %>%
  group_by(study_year, analysis_region_code) %>%
  summarise(
    population_average = sum(population_average),
    denominator_strata = n(),
    .groups = "drop"
  )

regional_annual <- regional_direct %>%
  transmute(
    study_year = year,
    region_code,
    region_name = analysis_region_name,
    beneficiaries = as.numeric(beneficiaries),
    boxes = as.numeric(boxes),
    reimbursement_base_eur = as.numeric(
      reimbursement_base_eur
    ),
    reimbursed_expenditure_eur = as.numeric(
      reimbursed_expenditure_eur
    ),
    open_medic_source_file = source_file
  ) %>%
  left_join(
    regional_population,
    by = c(
      "study_year",
      "region_code" = "analysis_region_code"
    ),
    relationship = "one-to-one"
  ) %>%
  group_by(region_code) %>%
  arrange(study_year, .by_group = TRUE) %>%
  mutate(
    beneficiary_rate_per_100000 = (
      beneficiaries / population_average * rate_multiplier
    ),
    boxes_per_100000 = (
      boxes / population_average * rate_multiplier
    ),
    beneficiaries_absolute_change = (
      beneficiaries - lag(beneficiaries)
    ),
    beneficiaries_percentage_change = (
      beneficiaries / lag(beneficiaries) - 1
    ) * 100,
    beneficiary_rate_absolute_change = (
      beneficiary_rate_per_100000 -
        lag(beneficiary_rate_per_100000)
    ),
    beneficiary_rate_percentage_change = (
      beneficiary_rate_per_100000 /
        lag(beneficiary_rate_per_100000) - 1
    ) * 100,
    boxes_percentage_change = (
      boxes / lag(boxes) - 1
    ) * 100
  ) %>%
  ungroup() %>%
  mutate(
    beneficiary_measure_status = "direct_atc4_region",
    additive_measure_status = "direct_atc4_region",
    historical_window_amendment_id = "001",
    amendment_id = "002",
    analysis_version = analysis_version,
    denominator_source_file = denominator_path
  ) %>%
  arrange(study_year, region_code)

stopifnot(
  nrow(regional_annual) == length(study_years) * 13L,
  all(regional_annual$denominator_strata == 6L),
  all(is.finite(
    regional_annual$beneficiary_rate_per_100000
  )),
  all(regional_annual$beneficiary_rate_per_100000 >= 0)
)

primary_source <- regional_age_sex_source %>%
  filter(
    region_code %in% analysis_regions,
    age_code %in% age_codes,
    sex_code %in% sex_codes
  ) %>%
  transmute(
    study_year = year,
    region_code,
    age_code,
    sex_code,
    observed_beneficiaries = as.numeric(beneficiaries),
    observed_boxes = as.numeric(boxes),
    observed_reimbursement_base_eur = as.numeric(
      reimbursement_base_eur
    ),
    observed_reimbursed_expenditure_eur = as.numeric(
      reimbursed_expenditure_eur
    ),
    open_medic_source_file = source_file
  )

unknown_strata <- regional_age_sex_source %>%
  filter(
    region_code %in% analysis_regions,
    !age_code %in% age_codes |
      !sex_code %in% sex_codes
  ) %>%
  arrange(year, region_code, age_code, sex_code)

unknown_sex_rows <- unknown_strata %>%
  filter(!sex_code %in% sex_codes)

stopifnot(nrow(unknown_sex_rows) == 0L)

unknown_age_by_sex <- unknown_strata %>%
  filter(
    !age_code %in% age_codes,
    sex_code %in% sex_codes
  ) %>%
  group_by(year, region_code, sex_code) %>%
  summarise(
    unknown_age_beneficiaries = sum(beneficiaries),
    unknown_age_boxes = sum(boxes),
    unknown_age_rows = n(),
    .groups = "drop"
  ) %>%
  rename(study_year = year)

expected_cells <- crossing(
  study_year = study_years,
  region_code = analysis_regions,
  age_code = age_codes,
  sex_code = sex_codes
)

regional_age_sex <- expected_cells %>%
  left_join(
    region_lookup %>%
      select(
        analysis_region_code,
        analysis_region_name
      ),
    by = c("region_code" = "analysis_region_code"),
    relationship = "many-to-one"
  ) %>%
  left_join(
    primary_source,
    by = c(
      "study_year",
      "region_code",
      "age_code",
      "sex_code"
    ),
    relationship = "one-to-one"
  ) %>%
  left_join(
    unknown_age_by_sex,
    by = c("study_year", "region_code", "sex_code"),
    relationship = "many-to-one"
  ) %>%
  left_join(
    regional_population_strata,
    by = c(
      "study_year",
      "region_code" = "analysis_region_code",
      "age_code",
      "sex_code"
    ),
    relationship = "one-to-one"
  ) %>%
  mutate(
    cell_status = case_when(
      !is.na(observed_beneficiaries) ~ "observed",
      !is.na(unknown_age_beneficiaries) ~ (
        "ambiguous_due_to_unknown_age"
      ),
      TRUE ~ "structural_zero_supported"
    ),
    beneficiaries = case_when(
      cell_status == "observed" ~ observed_beneficiaries,
      cell_status == "structural_zero_supported" ~ 0,
      TRUE ~ NA_real_
    ),
    boxes = case_when(
      cell_status == "observed" ~ observed_boxes,
      cell_status == "structural_zero_supported" ~ 0,
      TRUE ~ NA_real_
    ),
    beneficiary_rate_per_100000 = (
      beneficiaries / population_average * rate_multiplier
    ),
    beneficiary_lower_bound = case_when(
      cell_status == "ambiguous_due_to_unknown_age" ~ 0,
      TRUE ~ beneficiaries
    ),
    beneficiary_upper_bound = case_when(
      cell_status == "ambiguous_due_to_unknown_age" ~ (
        as.numeric(unknown_age_beneficiaries)
      ),
      TRUE ~ beneficiaries
    ),
    beneficiary_rate_lower_per_100000 = (
      beneficiary_lower_bound /
        population_average * rate_multiplier
    ),
    beneficiary_rate_upper_per_100000 = (
      beneficiary_upper_bound /
        population_average * rate_multiplier
    ),
    region_name = analysis_region_name,
    historical_window_amendment_id = "001",
    amendment_id = "002",
    analysis_version = analysis_version
  ) %>%
  select(
    study_year,
    region_code,
    region_name,
    age_code,
    sex_code,
    cell_status,
    beneficiaries,
    beneficiary_lower_bound,
    beneficiary_upper_bound,
    population_average,
    beneficiary_rate_per_100000,
    beneficiary_rate_lower_per_100000,
    beneficiary_rate_upper_per_100000,
    boxes,
    unknown_age_beneficiaries,
    unknown_age_boxes,
    population_start_status,
    population_end_status,
    open_medic_source_file,
    historical_window_amendment_id,
    amendment_id,
    analysis_version
  ) %>%
  arrange(study_year, region_code, age_code, sex_code)

missing_cells <- regional_age_sex %>%
  filter(cell_status != "observed")

stopifnot(
  nrow(regional_age_sex) == length(study_years) * 13L * 6L,
  !anyDuplicated(
    regional_age_sex[
      c(
        "study_year",
        "region_code",
        "age_code",
        "sex_code"
      )
    ]
  ),
  all(missing_cells$age_code == "0"),
  all(regional_age_sex$population_average > 0)
)

ambiguous_counts <- regional_age_sex %>%
  filter(cell_status == "ambiguous_due_to_unknown_age") %>%
  count(study_year, region_code, sex_code)

stopifnot(
  nrow(ambiguous_counts) == 0L |
    all(ambiguous_counts$n <= 1L)
)

standard_population <- denominator_source %>%
  filter(
    study_year == 2025L,
    analysis_region_code == "FR",
    age_code %in% age_codes,
    sex_code %in% sex_codes
  ) %>%
  transmute(
    age_code,
    sex_code,
    standard_population = population_average
  ) %>%
  mutate(
    standard_weight = (
      standard_population / sum(standard_population)
    )
  )

stopifnot(
  nrow(standard_population) == 6L,
  abs(sum(standard_population$standard_weight) - 1) < 1e-12
)

regional_age_sex <- regional_age_sex %>%
  left_join(
    standard_population,
    by = c("age_code", "sex_code"),
    relationship = "many-to-one"
  )

regional_standardised <- regional_age_sex %>%
  group_by(study_year, region_code, region_name) %>%
  summarise(
    observed_cells = sum(cell_status == "observed"),
    structural_zero_cells = sum(
      cell_status == "structural_zero_supported"
    ),
    ambiguous_cells = sum(
      cell_status == "ambiguous_due_to_unknown_age"
    ),
    standardised_rate_per_100000 = if (
      all(!is.na(beneficiary_rate_per_100000))
    ) {
      sum(
        beneficiary_rate_per_100000 * standard_weight
      )
    } else {
      NA_real_
    },
    standardised_rate_lower_per_100000 = sum(
      beneficiary_rate_lower_per_100000 * standard_weight
    ),
    standardised_rate_upper_per_100000 = sum(
      beneficiary_rate_upper_per_100000 * standard_weight
    ),
    standardisation_status = case_when(
      ambiguous_cells > 0 ~ "interval_due_to_unknown_age",
      structural_zero_cells > 0 ~ (
        "point_with_structural_zero"
      ),
      TRUE ~ "point_complete_observed"
    ),
    .groups = "drop"
  ) %>%
  left_join(
    regional_annual %>%
      select(
        study_year,
        region_code,
        crude_rate_per_100000 = (
          beneficiary_rate_per_100000
        )
      ),
    by = c("study_year", "region_code"),
    relationship = "one-to-one"
  ) %>%
  mutate(
    standard_population_year = 2025L,
    standard_population_scope = "France_entire",
    historical_window_amendment_id = "001",
    amendment_id = "002",
    analysis_version = analysis_version
  ) %>%
  arrange(study_year, region_code)

stopifnot(
  nrow(regional_standardised) == length(study_years) * 13L,
  all(
    regional_standardised$standardised_rate_lower_per_100000 <=
      regional_standardised$standardised_rate_upper_per_100000
  ),
  all(
    !is.na(regional_standardised$standardised_rate_per_100000) ==
      (regional_standardised$ambiguous_cells == 0L)
  )
)

age_sex_reconciliation <- regional_age_sex_source %>%
  filter(region_code %in% analysis_regions) %>%
  group_by(year, region_code) %>%
  summarise(
    stratified_beneficiaries = sum(beneficiaries),
    stratified_boxes = sum(boxes),
    stratified_expenditure_eur = sum(
      reimbursed_expenditure_eur
    ),
    stratified_rows = n(),
    .groups = "drop"
  ) %>%
  left_join(
    regional_direct %>%
      select(
        year,
        region_code,
        direct_beneficiaries = beneficiaries,
        direct_boxes = boxes,
        direct_expenditure_eur = reimbursed_expenditure_eur
      ),
    by = c("year", "region_code"),
    relationship = "one-to-one"
  ) %>%
  mutate(
    beneficiary_difference = (
      stratified_beneficiaries - direct_beneficiaries
    ),
    boxes_difference = stratified_boxes - direct_boxes,
    expenditure_difference_eur = (
      stratified_expenditure_eur - direct_expenditure_eur
    ),
    reconciliation_scope = "within_region_age_sex"
  )

national_reconciliation <- regional_source %>%
  group_by(year) %>%
  summarise(
    stratified_beneficiaries = sum(beneficiaries),
    stratified_boxes = sum(boxes),
    stratified_expenditure_eur = sum(
      reimbursed_expenditure_eur
    ),
    stratified_rows = n(),
    .groups = "drop"
  ) %>%
  left_join(
    national %>%
      transmute(
        year = study_year,
        direct_beneficiaries = beneficiaries,
        direct_boxes = boxes,
        direct_expenditure_eur = reimbursed_expenditure_eur
      ),
    by = "year",
    relationship = "one-to-one"
  ) %>%
  mutate(
    beneficiary_difference = (
      stratified_beneficiaries - direct_beneficiaries
    ),
    boxes_difference = stratified_boxes - direct_boxes,
    expenditure_difference_eur = (
      stratified_expenditure_eur - direct_expenditure_eur
    ),
    reconciliation_scope = "regions_to_national"
  )

regional_reconciliation <- bind_rows(
  age_sex_reconciliation,
  national_reconciliation %>%
    mutate(region_code = "ALL")
) %>%
  mutate(
    historical_window_amendment_id = "001",
    amendment_id = "002",
    analysis_version = analysis_version
  ) %>%
  arrange(year, reconciliation_scope, region_code)

stopifnot(
  all(age_sex_reconciliation$boxes_difference == 0),
  max(abs(
    age_sex_reconciliation$beneficiary_difference
  )) <= 1,
  all(abs(
    age_sex_reconciliation$expenditure_difference_eur
  ) <= (
    currency_reconciliation_tolerance_eur +
      floating_point_tolerance
  )),
  all(national_reconciliation$boxes_difference == 0),
  all(abs(
    national_reconciliation$expenditure_difference_eur
  ) <= (
    currency_reconciliation_tolerance_eur +
      floating_point_tolerance
  ))
)

cell_completeness <- regional_age_sex %>%
  count(
    study_year,
    region_code,
    region_name,
    cell_status,
    name = "cells"
  ) %>%
  complete(
    study_year,
    nesting(region_code, region_name),
    cell_status = c(
      "observed",
      "structural_zero_supported",
      "ambiguous_due_to_unknown_age"
    ),
    fill = list(cells = 0L)
  ) %>%
  arrange(study_year, region_code, cell_status)

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

write_parquet(regional_annual, regional_annual_path)
write_parquet(
  regional_age_sex,
  regional_age_sex_output_path
)
write_parquet(
  regional_standardised,
  regional_standardised_path
)

write_csv(regional_annual, regional_annual_table_path, na = "")
write_csv(
  regional_age_sex,
  regional_age_sex_table_path,
  na = ""
)
write_csv(
  regional_standardised,
  regional_standardised_table_path,
  na = ""
)
write_csv(
  regional_reconciliation,
  reconciliation_path,
  na = ""
)
write_csv(
  cell_completeness,
  cell_completeness_path,
  na = ""
)
write_csv(unknown_strata, unknown_strata_path, na = "")

created_paths <- c(
  regional_annual_path,
  regional_age_sex_output_path,
  regional_standardised_path,
  regional_annual_table_path,
  regional_age_sex_table_path,
  regional_standardised_table_path,
  reconciliation_path,
  cell_completeness_path,
  unknown_strata_path
)

stopifnot(
  all(file.exists(created_paths)),
  all(file.info(created_paths)$size > 0)
)

for (path in created_paths) {
  cat("created ", path, "\n", sep = "")
}

cat(
  "Regional analytical datasets and QC tables passed.\n"
)
