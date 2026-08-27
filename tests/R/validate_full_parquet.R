suppressPackageStartupMessages(
  library(arrow)
)

open_medic_inventory <- read.csv(
  file.path(
    "data",
    "metadata",
    "open_medic_inventory.csv"
  ),
  stringsAsFactors = FALSE
)

stopifnot(
  nrow(open_medic_inventory) == 35L,
  setequal(
    unique(open_medic_inventory$year),
    2019:2025
  ),
  length(unique(open_medic_inventory$output_file)) == 5L,
  all(
    open_medic_inventory$duplicate_target_key_rows == 0L
  ),
  all(
    open_medic_inventory$negative_beneficiary_cells == 0L
  )
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

for (output_file in unique(
  open_medic_inventory$output_file
)) {
  records <- open_medic_inventory[
    open_medic_inventory$output_file == output_file,
    ,
    drop = FALSE
  ]

  expected_rows <- sum(records$target_rows)
  data <- read_parquet(
    output_file,
    as_data_frame = TRUE
  )

  candidate_keys <- c(
    "year",
    "atc_code",
    "age_code",
    "sex_code",
    "region_code"
  )
  active_keys <- candidate_keys[
    vapply(
      data[candidate_keys],
      function(column) !all(is.na(column)),
      logical(1)
    )
  ]

  stopifnot(
    nrow(data) == expected_rows,
    setequal(
      names(data),
      required_open_medic_columns
    ),
    setequal(unique(data$year), 2019:2025),
    all(!is.na(data$beneficiaries)),
    all(data$beneficiaries >= 0),
    !anyDuplicated(data[active_keys])
  )

  cat(
    basename(output_file),
    ": passed (",
    nrow(data),
    " rows)\n",
    sep = ""
  )
}

insee_inventory <- read.csv(
  file.path(
    "data",
    "metadata",
    "insee_inventory.csv"
  ),
  stringsAsFactors = FALSE
)

stopifnot(
  nrow(insee_inventory) == 8L,
  setequal(
    unique(insee_inventory$reference_year),
    2019:2026
  ),
  all(insee_inventory$sex_totals_reconciled),
  all(insee_inventory$age_totals_reconciled)
)

insee_directory <- file.path(
  "data",
  "interim",
  "insee",
  "full"
)

january <- read_parquet(
  file.path(
    insee_directory,
    "insee_population_january1.parquet"
  ),
  as_data_frame = TRUE
)

annual <- read_parquet(
  file.path(
    insee_directory,
    "insee_annual_denominators.parquet"
  ),
  as_data_frame = TRUE
)

standard <- read_parquet(
  file.path(
    insee_directory,
    "insee_standard_population_2025.parquet"
  ),
  as_data_frame = TRUE
)

stopifnot(
  nrow(january) == 4800L,
  setequal(
    unique(january$reference_year),
    2019:2026
  ),
  all(january$population_january1 > 0),
  !anyDuplicated(
    january[c(
      "reference_year",
      "analysis_region_code",
      "sex_code",
      "age_lower"
    )]
  )
)

expected_average <- (
  annual$population_start
  + annual$population_end
) / 2

stopifnot(
  nrow(annual) == 630L,
  setequal(unique(annual$study_year), 2019:2025),
  all(annual$population_average > 0),
  isTRUE(
    all.equal(
      annual$population_average,
      expected_average
    )
  ),
  !anyDuplicated(
    annual[c(
      "study_year",
      "analysis_region_code",
      "sex_code",
      "age_code"
    )]
  )
)

stopifnot(
  nrow(standard) == 6L,
  identical(
    unique(standard$analysis_region_code),
    "FR"
  ),
  setequal(unique(standard$sex_code), c("1", "2")),
  setequal(unique(standard$age_code), c("0", "20", "60")),
  all(standard$standard_weight > 0),
  abs(sum(standard$standard_weight) - 1) < 1e-12
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

cat("\nAll cross-language full-dataset checks passed.\n")
