suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
})

study_years <- 2019:2025
beneficiary_years <- 2020:2025
rate_multiplier <- 100000
analysis_version <- "sap-v1.0-amendment-001"

open_medic_path <- file.path(
  "data",
  "interim",
  "open_medic",
  "full",
  "open_medic_atc4_national.parquet"
)

active_substance_path <- file.path(
  "data",
  "interim",
  "open_medic",
  "full",
  "open_medic_atc5_national.parquet"
)

denominator_path <- file.path(
  "data",
  "interim",
  "insee",
  "full",
  "insee_annual_denominators.parquet"
)

output_directory <- file.path(
  "data",
  "processed"
)

output_path <- file.path(
  output_directory,
  "national_annual.parquet"
)

required_open_medic_columns <- c(
  "year",
  "atc_level",
  "aggregation",
  "atc_code",
  "beneficiaries",
  "reimbursed_expenditure_eur",
  "reimbursement_base_eur",
  "boxes",
  "source_file"
)

required_denominator_columns <- c(
  "study_year",
  "analysis_region_code",
  "sex_code",
  "age_code",
  "population_start",
  "population_end",
  "population_average",
  "population_start_status",
  "population_end_status"
)

national_source <- read_parquet(
  open_medic_path,
  as_data_frame = TRUE
)

active_substance_source <- read_parquet(
  active_substance_path,
  as_data_frame = TRUE
)

denominator_source <- read_parquet(
  denominator_path,
  as_data_frame = TRUE
)

stopifnot(
  all(required_open_medic_columns %in% names(national_source)),
  all(required_denominator_columns %in% names(denominator_source)),
  nrow(national_source) == length(study_years),
  setequal(national_source$year, study_years),
  identical(unique(national_source$atc_level), "ATC4"),
  identical(unique(national_source$aggregation), "national"),
  identical(unique(national_source$atc_code), "A10BJ"),
  !anyDuplicated(national_source$year),
  all(!is.na(national_source$beneficiaries)),
  all(national_source$beneficiaries >= 0),
  all(!is.na(national_source$boxes)),
  all(!is.na(national_source$reimbursed_expenditure_eur)),
  all(!is.na(national_source$reimbursement_base_eur))
)

required_active_substance_columns <- c(
  "year",
  "atc_level",
  "aggregation",
  "atc_code",
  "beneficiaries",
  "reimbursed_expenditure_eur",
  "reimbursement_base_eur",
  "boxes",
  "source_file"
)

stopifnot(
  all(
    required_active_substance_columns %in%
      names(active_substance_source)
  ),
  identical(
    unique(active_substance_source$atc_level),
    "ATC5"
  ),
  identical(
    unique(active_substance_source$aggregation),
    "national"
  )
)

historical_2019 <- active_substance_source %>%
  filter(year == 2019L) %>%
  arrange(atc_code)

stopifnot(
  nrow(historical_2019) == 4L,
  identical(
    historical_2019$atc_code,
    c("A10BJ01", "A10BJ02", "A10BJ05", "A10BJ06")
  )
)

reconstructed_2019 <- historical_2019 %>%
  summarise(
    boxes = sum(as.numeric(boxes)),
    reimbursement_base_eur = sum(
      as.numeric(reimbursement_base_eur)
    ),
    reimbursed_expenditure_eur = sum(
      as.numeric(reimbursed_expenditure_eur)
    ),
    source_file = paste(
      sort(unique(source_file)),
      collapse = "|"
    )
  )

stopifnot(
  reconstructed_2019$boxes == 3491051,
  isTRUE(all.equal(
    reconstructed_2019$reimbursement_base_eur,
    303351276.91,
    tolerance = 1e-8
  )),
  isTRUE(all.equal(
    reconstructed_2019$reimbursed_expenditure_eur,
    298670605.91,
    tolerance = 1e-8
  ))
)

national_source <- national_source %>%
  mutate(
    beneficiaries = if_else(
      year == 2019L,
      NA_real_,
      as.numeric(beneficiaries)
    ),
    boxes = if_else(
      year == 2019L,
      reconstructed_2019$boxes,
      as.numeric(boxes)
    ),
    reimbursement_base_eur = if_else(
      year == 2019L,
      reconstructed_2019$reimbursement_base_eur,
      as.numeric(reimbursement_base_eur)
    ),
    reimbursed_expenditure_eur = if_else(
      year == 2019L,
      reconstructed_2019$reimbursed_expenditure_eur,
      as.numeric(reimbursed_expenditure_eur)
    ),
    source_file = if_else(
      year == 2019L,
      reconstructed_2019$source_file,
      source_file
    ),
    beneficiary_measure_status = if_else(
      year == 2019L,
      "not_estimable_from_aggregated_source",
      "direct_atc4"
    ),
    additive_measure_status = if_else(
      year == 2019L,
      "reconstructed_from_harmonised_atc5",
      "direct_atc4"
    )
  )

france_strata <- denominator_source %>%
  filter(
    analysis_region_code == "FR",
    sex_code %in% c("1", "2"),
    age_code %in% c("0", "20", "60")
  )

stopifnot(
  nrow(france_strata) == length(study_years) * 6L,
  setequal(france_strata$study_year, study_years),
  !anyDuplicated(
    france_strata[c(
      "study_year",
      "sex_code",
      "age_code"
    )]
  ),
  all(france_strata$population_average > 0)
)

status_counts <- france_strata %>%
  group_by(study_year) %>%
  summarise(
    start_status_count = n_distinct(
      population_start_status
    ),
    end_status_count = n_distinct(
      population_end_status
    ),
    .groups = "drop"
  )

stopifnot(
  all(status_counts$start_status_count == 1L),
  all(status_counts$end_status_count == 1L)
)

national_denominators <- france_strata %>%
  group_by(study_year) %>%
  summarise(
    population_start = sum(population_start),
    population_end = sum(population_end),
    population_average = sum(population_average),
    population_start_status = first(
      population_start_status
    ),
    population_end_status = first(
      population_end_status
    ),
    denominator_strata = n(),
    .groups = "drop"
  )

stopifnot(
  nrow(national_denominators) == length(study_years),
  all(national_denominators$denominator_strata == 6L),
  all(
    national_denominators$population_average
    == (
      national_denominators$population_start
      + national_denominators$population_end
    ) / 2
  )
)

safe_ratio <- function(numerator, denominator) {
  ifelse(
    !is.na(denominator) & denominator > 0,
    numerator / denominator,
    NA_real_
  )
}

percent_change <- function(value) {
  previous <- lag(value)
  ifelse(
    !is.na(previous) & previous > 0,
    (value / previous - 1) * 100,
    NA_real_
  )
}

national_annual <- national_source %>%
  transmute(
    study_year = as.integer(year),
    atc_level,
    atc_code,
    beneficiaries = as.numeric(beneficiaries),
    boxes = as.numeric(boxes),
    reimbursement_base_eur = as.numeric(
      reimbursement_base_eur
    ),
    reimbursed_expenditure_eur = as.numeric(
      reimbursed_expenditure_eur
    ),
    beneficiary_measure_status,
    additive_measure_status,
    open_medic_source_file = source_file
  ) %>%
  left_join(
    national_denominators,
    by = "study_year",
    relationship = "one-to-one"
  ) %>%
  arrange(study_year) %>%
  mutate(
    beneficiary_rate_per_100000 = safe_ratio(
      beneficiaries,
      population_average
    ) * rate_multiplier,
    boxes_per_100000 = safe_ratio(
      boxes,
      population_average
    ) * rate_multiplier,
    boxes_per_beneficiary = safe_ratio(
      boxes,
      beneficiaries
    ),
    reimbursed_expenditure_per_beneficiary_eur = safe_ratio(
      reimbursed_expenditure_eur,
      beneficiaries
    ),
    beneficiaries_absolute_change = beneficiaries - lag(
      beneficiaries
    ),
    beneficiaries_percentage_change = percent_change(
      beneficiaries
    ),
    beneficiary_rate_absolute_change = (
      beneficiary_rate_per_100000
      - lag(beneficiary_rate_per_100000)
    ),
    beneficiary_rate_percentage_change = percent_change(
      beneficiary_rate_per_100000
    ),
    boxes_percentage_change = percent_change(boxes),
    reimbursement_base_percentage_change = percent_change(
      reimbursement_base_eur
    ),
    reimbursed_expenditure_percentage_change = percent_change(
      reimbursed_expenditure_eur
    ),
    amendment_id = "001",
    analysis_version = analysis_version,
    denominator_source_file = denominator_path
  )

required_output_columns <- c(
  "study_year",
  "atc_level",
  "atc_code",
  "beneficiaries",
  "population_average",
  "beneficiary_rate_per_100000",
  "boxes",
  "boxes_per_100000",
  "boxes_per_beneficiary",
  "reimbursement_base_eur",
  "reimbursed_expenditure_eur",
  "reimbursed_expenditure_per_beneficiary_eur",
  "beneficiary_measure_status",
  "additive_measure_status",
  "amendment_id",
  "analysis_version"
)

stopifnot(
  nrow(national_annual) == length(study_years),
  all(required_output_columns %in% names(national_annual)),
  setequal(national_annual$study_year, study_years),
  !anyDuplicated(national_annual$study_year),
  all(national_annual$population_average > 0),
  is.na(national_annual$beneficiaries[1]),
  is.na(national_annual$beneficiary_rate_per_100000[1]),
  is.na(national_annual$boxes_per_beneficiary[1]),
  is.na(national_annual[[
    "reimbursed_expenditure_per_beneficiary_eur"
  ]][1]),
  all(
    national_annual$beneficiaries[
      national_annual$study_year %in% beneficiary_years
    ] >= 0
  ),
  all(
    national_annual$beneficiary_rate_per_100000[
      national_annual$study_year %in% beneficiary_years
    ] >= 0
  ),
  all(is.finite(
    national_annual$beneficiary_rate_per_100000[
      national_annual$study_year %in% beneficiary_years
    ]
  )),
  all(is.finite(
    national_annual$boxes_per_beneficiary[
      national_annual$study_year %in% beneficiary_years
    ]
  )),
  all(
    is.finite(
      national_annual[[
        "reimbursed_expenditure_per_beneficiary_eur"
      ]][national_annual$study_year %in% beneficiary_years]
    )
  ),
  national_annual$boxes[1] == 3491051,
  national_annual$beneficiary_measure_status[1] ==
    "not_estimable_from_aggregated_source",
  national_annual$additive_measure_status[1] ==
    "reconstructed_from_harmonised_atc5",
  all(
    is.na(
      national_annual$beneficiaries_percentage_change[1:2]
    )
  ),
  all(
    is.na(
      national_annual$beneficiary_rate_percentage_change[1:2]
    )
  ),
  !is.na(national_annual$boxes_percentage_change[2])
)

dir.create(
  output_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

write_parquet(
  national_annual,
  output_path
)

cat(
  "created ",
  output_path,
  " (",
  nrow(national_annual),
  " rows)\n",
  sep = ""
)
cat("National analytical dataset checks passed.\n")
