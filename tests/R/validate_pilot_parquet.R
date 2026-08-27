suppressPackageStartupMessages(
  library(arrow)
)

open_medic_directory <- file.path(
  "data",
  "interim",
  "open_medic",
  "pilot"
)

insee_directory <- file.path(
  "data",
  "interim",
  "insee",
  "pilot"
)

expected_open_medic_rows <- c(
  open_medic_atc4_national_pilot.parquet = 2L,
  open_medic_atc4_age_sex_pilot.parquet = 17L,
  open_medic_atc4_region_pilot.parquet = 28L,
  open_medic_atc4_age_sex_region_pilot.parquet = 152L,
  open_medic_atc5_national_pilot.parquet = 5L
)

required_open_medic_columns <- c(
  "year",
  "atc_level",
  "aggregation",
  "atc_code",
  "atc_label",
  "atc_name",
  "analysis_role",
  "age_code",
  "sex_code",
  "region_code",
  "beneficiaries",
  "reimbursed_expenditure_eur",
  "reimbursement_base_eur",
  "boxes",
  "source_file",
  "source_encoding"
)

for (filename in names(expected_open_medic_rows)) {
  path <- file.path(
    open_medic_directory,
    filename
  )

  data <- read_parquet(
    path,
    as_data_frame = TRUE
  )

  stopifnot(
    nrow(data) == expected_open_medic_rows[[filename]],
    setequal(
      names(data),
      required_open_medic_columns
    ),
    setequal(
      unique(data$year),
      c(2019L, 2025L)
    ),
    all(!is.na(data$beneficiaries)),
    all(data$beneficiaries >= 0)
  )

  cat(
    filename,
    ": passed (",
    nrow(data),
    " rows)\n",
    sep = ""
  )
}

january <- read_parquet(
  file.path(
    insee_directory,
    "insee_population_january1_pilot.parquet"
  ),
  as_data_frame = TRUE
)

annual <- read_parquet(
  file.path(
    insee_directory,
    "insee_annual_denominators_pilot.parquet"
  ),
  as_data_frame = TRUE
)

standard <- read_parquet(
  file.path(
    insee_directory,
    "insee_standard_population_2025_pilot.parquet"
  ),
  as_data_frame = TRUE
)

stopifnot(
  nrow(january) == 2400L,
  setequal(
    unique(january$reference_year),
    c(2019L, 2020L, 2025L, 2026L)
  ),
  all(january$population_january1 > 0)
)

expected_average <- (
  annual$population_start
  + annual$population_end
) / 2

stopifnot(
  nrow(annual) == 180L,
  setequal(
    unique(annual$study_year),
    c(2019L, 2025L)
  ),
  all(annual$population_average > 0),
  isTRUE(
    all.equal(
      annual$population_average,
      expected_average
    )
  )
)

stopifnot(
  nrow(standard) == 6L,
  identical(
    unique(standard$analysis_region_code),
    "FR"
  ),
  abs(
    sum(standard$standard_weight) - 1
  ) < 1e-12
)

cat(
  "INSEE January population: passed (",
  nrow(january),
  " rows)\n",
  sep = ""
)
cat(
  "INSEE annual denominators: passed (",
  nrow(annual),
  " rows)\n",
  sep = ""
)
cat(
  "INSEE standard population: passed (",
  nrow(standard),
  " rows)\n",
  sep = ""
)

cat("\nAll cross-language pilot checks passed.\n")
