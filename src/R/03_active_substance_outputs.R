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

active_substance_path <- file.path(
  "data",
  "interim",
  "open_medic",
  "full",
  "open_medic_atc5_national.parquet"
)

national_path <- file.path(
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
  "table_02_active_substance_annual_2019_2025.csv"
)

contribution_table_path <- file.path(
  table_directory,
  paste0(
    "table_02_active_substance_change_",
    "contributions_2023_2025.csv"
  )
)

reconciliation_table_path <- file.path(
  table_directory,
  paste0(
    "qc_02_active_substance_reconciliation_",
    "2019_2025.csv"
  )
)

primary_figure_stem <- (
  "figure_02_active_substance_boxes_2019_2025"
)

candidate_figure_stems <- c(
  trajectories = (
    "figure_02a_active_substance_boxes_2019_2025"
  ),
  composition = (
    "figure_02b_active_substance_box_composition_2019_2025"
  ),
  contributions = paste0(
    "figure_02c_active_substance_box_change_",
    "contributions_2023_2025"
  )
)

active_substance <- read_parquet(
  active_substance_path,
  as_data_frame = TRUE
) %>%
  arrange(year, atc_code)

national <- read_parquet(
  national_path,
  as_data_frame = TRUE
) %>%
  arrange(study_year)

required_active_columns <- c(
  "year",
  "atc_level",
  "aggregation",
  "atc_code",
  "atc_name",
  "beneficiaries",
  "boxes",
  "reimbursed_expenditure_eur",
  "reimbursement_base_eur"
)

required_national_columns <- c(
  "study_year",
  "beneficiaries",
  "boxes",
  "reimbursed_expenditure_eur",
  "reimbursement_base_eur",
  "analysis_version"
)

stopifnot(
  all(required_active_columns %in% names(active_substance)),
  all(required_national_columns %in% names(national)),
  identical(unique(active_substance$atc_level), "ATC5"),
  identical(
    unique(active_substance$aggregation),
    "national"
  ),
  setequal(active_substance$year, 2019:2025),
  !anyDuplicated(
    active_substance[c("year", "atc_code")]
  ),
  all(active_substance$beneficiaries >= 0),
  all(active_substance$boxes >= 0),
  all(active_substance$reimbursed_expenditure_eur >= 0),
  all(active_substance$reimbursement_base_eur >= 0),
  identical(
    unique(national$analysis_version),
    "sap-v1.0-amendment-001"
  )
)

code_labels <- active_substance %>%
  distinct(atc_code, atc_name) %>%
  arrange(atc_code)

observed_codes <- code_labels$atc_code

stopifnot(
  !anyDuplicated(code_labels$atc_code),
  !anyDuplicated(code_labels$atc_name),
  all(observed_codes %in% names(maradian_atc5_colours))
)

observed_colour_values <- maradian_atc5_colours[
  observed_codes
]
observed_label_values <- setNames(
  code_labels$atc_name,
  code_labels$atc_code
)

active_substance_annual <- active_substance %>%
  group_by(year) %>%
  mutate(
    box_share = boxes / sum(boxes),
    expenditure_share = (
      reimbursed_expenditure_eur /
        sum(reimbursed_expenditure_eur)
    )
  ) %>%
  ungroup() %>%
  select(
    year,
    atc_code,
    atc_name,
    beneficiaries,
    boxes,
    box_share,
    reimbursement_base_eur,
    reimbursed_expenditure_eur,
    expenditure_share
  )

atc5_totals <- active_substance %>%
  group_by(year) %>%
  summarise(
    maximum_substance_beneficiaries = max(beneficiaries),
    summed_substance_beneficiaries = sum(beneficiaries),
    atc5_boxes = sum(boxes),
    atc5_reimbursement_base_eur = sum(
      reimbursement_base_eur
    ),
    atc5_reimbursed_expenditure_eur = sum(
      reimbursed_expenditure_eur
    ),
    .groups = "drop"
  )

reconciliation <- national %>%
  transmute(
    year = study_year,
    class_beneficiaries = beneficiaries,
    class_boxes = boxes,
    class_reimbursement_base_eur = reimbursement_base_eur,
    class_reimbursed_expenditure_eur = (
      reimbursed_expenditure_eur
    )
  ) %>%
  left_join(
    atc5_totals,
    by = "year",
    relationship = "one-to-one"
  ) %>%
  mutate(
    boxes_difference = class_boxes - atc5_boxes,
    reimbursement_base_difference_eur = (
      class_reimbursement_base_eur -
        atc5_reimbursement_base_eur
    ),
    reimbursed_expenditure_difference_eur = (
      class_reimbursed_expenditure_eur -
        atc5_reimbursed_expenditure_eur
    ),
    beneficiary_lower_bound_valid = if_else(
      is.na(class_beneficiaries),
      NA,
      class_beneficiaries >=
        maximum_substance_beneficiaries
    ),
    beneficiary_upper_bound_valid = if_else(
      is.na(class_beneficiaries),
      NA,
      class_beneficiaries <=
        summed_substance_beneficiaries
    ),
    additive_reconciliation_status = case_when(
      abs(boxes_difference) <= 0.5 &
        abs(reimbursement_base_difference_eur) <= 0.02 &
        abs(reimbursed_expenditure_difference_eur) <= 0.02 ~
        "within_rounding_tolerance",
      TRUE ~ "residual_difference_reviewed"
    )
  )

stopifnot(
  nrow(reconciliation) == 7L,
  all(
    reconciliation$beneficiary_lower_bound_valid[
      reconciliation$year >= 2020
    ]
  ),
  all(
    reconciliation$beneficiary_upper_bound_valid[
      reconciliation$year >= 2020
    ]
  ),
  all(
    reconciliation$additive_reconciliation_status[
      reconciliation$year %in% 2023:2025
    ] == "within_rounding_tolerance"
  )
)

contributions <- active_substance %>%
  group_by(atc_code, atc_name) %>%
  arrange(year, .by_group = TRUE) %>%
  mutate(
    previous_year = lag(year),
    beneficiary_change = beneficiaries - lag(beneficiaries),
    box_change = boxes - lag(boxes),
    reimbursement_base_change_eur = (
      reimbursement_base_eur - lag(reimbursement_base_eur)
    ),
    reimbursed_expenditure_change_eur = (
      reimbursed_expenditure_eur -
        lag(reimbursed_expenditure_eur)
    )
  ) %>%
  ungroup() %>%
  filter(year %in% c(2024L, 2025L)) %>%
  mutate(
    comparison = paste0(previous_year, "-", year)
  ) %>%
  select(
    comparison,
    previous_year,
    year,
    atc_code,
    atc_name,
    beneficiary_change,
    box_change,
    reimbursement_base_change_eur,
    reimbursed_expenditure_change_eur
  )

national_changes <- national %>%
  transmute(
    year = study_year,
    national_box_change = boxes - lag(boxes),
    national_reimbursement_base_change_eur = (
      reimbursement_base_eur - lag(reimbursement_base_eur)
    ),
    national_reimbursed_expenditure_change_eur = (
      reimbursed_expenditure_eur -
        lag(reimbursed_expenditure_eur)
    )
  )

contribution_check <- contributions %>%
  group_by(year) %>%
  summarise(
    summed_box_change = sum(box_change),
    summed_reimbursement_base_change_eur = sum(
      reimbursement_base_change_eur
    ),
    summed_reimbursed_expenditure_change_eur = sum(
      reimbursed_expenditure_change_eur
    ),
    .groups = "drop"
  ) %>%
  left_join(
    national_changes,
    by = "year",
    relationship = "one-to-one"
  )

stopifnot(
  nrow(contributions) == length(observed_codes) * 2L,
  all(
    contribution_check$summed_box_change ==
      contribution_check$national_box_change
  ),
  all(abs(
    contribution_check[[
      "summed_reimbursement_base_change_eur"
    ]] - contribution_check[[
      "national_reimbursement_base_change_eur"
    ]]
  ) <= 0.02),
  all(abs(
    contribution_check[[
      "summed_reimbursed_expenditure_change_eur"
    ]] - contribution_check[[
      "national_reimbursed_expenditure_change_eur"
    ]]
  ) <= 0.02)
)

active_caption <- wrap_maradian_text(
  c(
    "Source: Open Medic.",
    "Historical active-substance codes for 2019 were",
    "harmonised according to protocol amendment 001.",
    "Boxes and expenditure are additive across substances;",
    "beneficiary counts are not summed to estimate class users."
  )
)

trajectory_figure <- ggplot(
  active_substance_annual,
  aes(
    x = year,
    y = boxes,
    colour = atc_code,
    group = atc_code
  )
) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 2.7) +
  scale_x_continuous(breaks = 2019:2025) +
  scale_y_continuous(
    labels = label_number(
      scale_cut = cut_short_scale(),
      accuracy = 0.1
    ),
    expand = expansion(mult = c(0.03, 0.12))
  ) +
  scale_colour_manual(
    values = observed_colour_values,
    breaks = observed_codes,
    labels = observed_label_values,
    drop = FALSE
  ) +
  labs(
    title = paste(
      "Annual reimbursed boxes by glucagon-like peptide-1",
      "receptor agonist"
    ),
    subtitle = "France, 2019-2025",
    x = "Calendar year",
    y = "Reimbursed boxes",
    caption = active_caption
  ) +
  guides(
    colour = guide_legend(
      nrow = 2,
      byrow = TRUE
    )
  ) +
  theme_maradian()

composition_figure <- ggplot(
  active_substance_annual,
  aes(
    x = factor(year),
    y = box_share,
    fill = atc_code
  )
) +
  geom_col(width = 0.72) +
  scale_y_continuous(
    labels = label_percent(accuracy = 1),
    expand = expansion(mult = c(0, 0.02))
  ) +
  coord_cartesian(
    ylim = c(0, 1)
  ) +
  scale_fill_manual(
    values = observed_colour_values,
    breaks = observed_codes,
    labels = observed_label_values,
    drop = FALSE
  ) +
  labs(
    title = "Active-substance composition of reimbursed boxes",
    subtitle = paste(
      "Glucagon-like peptide-1 receptor agonists;",
      "annual shares, France, 2019-2025"
    ),
    x = "Calendar year",
    y = "Share of reimbursed boxes",
    caption = active_caption
  ) +
  guides(
    fill = guide_legend(
      nrow = 2,
      byrow = TRUE
    )
  ) +
  theme_maradian()

comparison_labels <- contribution_check %>%
  transmute(
    comparison = paste0(year - 1L, "-", year),
    national_net_box_change = national_box_change,
    comparison_label = paste0(
      comparison,
      " | net ",
      label_maradian_signed_compact(
        national_box_change
      )
    )
  )

comparison_label_values <- setNames(
  comparison_labels$comparison_label,
  comparison_labels$comparison
)

contribution_plot_data <- contributions %>%
  mutate(
    atc_name = factor(
      atc_name,
      levels = rev(code_labels$atc_name)
    ),
    comparison = factor(
      comparison,
      levels = c("2023-2024", "2024-2025")
    )
  )

contribution_figure <- ggplot(
  contribution_plot_data,
  aes(
    x = box_change,
    y = atc_name,
    fill = atc_code
  )
) +
  geom_vline(
    xintercept = 0,
    colour = maradian_colours[["neutral"]],
    linewidth = 0.55
  ) +
  geom_col(width = 0.65) +
  geom_text(
    aes(
      label = label_maradian_compact(box_change),
      hjust = if_else(box_change >= 0, -0.08, 1.08)
    ),
    size = 3.2,
    colour = maradian_colours[["navy"]]
  ) +
  facet_wrap(
    vars(comparison),
    ncol = 2,
    labeller = as_labeller(comparison_label_values)
  ) +
  scale_x_continuous(
    labels = label_number(
      scale_cut = cut_short_scale(),
      accuracy = 0.1
    ),
    expand = expansion(mult = c(0.2, 0.2))
  ) +
  scale_fill_manual(
    values = observed_colour_values,
    breaks = observed_codes,
    labels = observed_label_values,
    drop = FALSE
  ) +
  labs(
    title = paste(
      "Substance contributions to annual change",
      "in reimbursed boxes"
    ),
    subtitle = paste(
      "Glucagon-like peptide-1 receptor agonists;",
      "France, 2023-2025"
    ),
    x = "Change in reimbursed boxes",
    y = NULL,
    caption = active_caption
  ) +
  theme_maradian() +
  theme(
    legend.position = "none"
  )

dir.create(
  table_directory,
  recursive = TRUE,
  showWarnings = FALSE
)

write_csv(
  active_substance_annual,
  annual_table_path,
  na = ""
)
write_csv(
  contributions,
  contribution_table_path,
  na = ""
)
write_csv(
  reconciliation,
  reconciliation_table_path,
  na = ""
)

figure_data_paths <- c(
  trajectories = save_maradian_figure_data(
    active_substance_annual %>%
      transmute(
        year,
        atc_code,
        atc_name,
        reimbursed_boxes = boxes
      ),
    figure_data_directory,
    candidate_figure_stems[["trajectories"]]
  ),
  composition = save_maradian_figure_data(
    active_substance_annual %>%
      transmute(
        year,
        atc_code,
        atc_name,
        reimbursed_boxes = boxes,
        box_share
      ),
    figure_data_directory,
    candidate_figure_stems[["composition"]]
  ),
  contributions = save_maradian_figure_data(
    contribution_plot_data %>%
      transmute(
        comparison = as.character(comparison),
        atc_code,
        atc_name = as.character(atc_name),
        box_change
      ) %>%
      left_join(
        comparison_labels %>%
          transmute(
            comparison,
            national_net_box_change
          ),
        by = "comparison",
        relationship = "many-to-one"
      ),
    figure_data_directory,
    candidate_figure_stems[["contributions"]]
  )
)

figure_manifest_path <- update_maradian_figure_manifest(
  data.frame(
    figure_id = c("02", "02a", "02b", "02c"),
    figure_stem = c(
      primary_figure_stem,
      candidate_figure_stems[["trajectories"]],
      candidate_figure_stems[["composition"]],
      candidate_figure_stems[["contributions"]]
    ),
    data_file = c(
      figure_data_paths[["trajectories"]],
      figure_data_paths[["trajectories"]],
      figure_data_paths[["composition"]],
      figure_data_paths[["contributions"]]
    ),
    figure_role = c(
      "primary",
      "candidate_primary_duplicate",
      "alternative",
      "alternative"
    ),
    analysis_scope = "national_active_substance",
    analytical_window = c(
      "2019-2025",
      "2019-2025",
      "2019-2025",
      "2023-2025"
    ),
    notes = c(
      "Same plotted data as figure 02a.",
      "Annual reimbursed boxes by active substance.",
      "Annual shares calculated from reimbursed boxes.",
      "Substance changes sum to the displayed national net change."
    ),
    stringsAsFactors = FALSE
  ),
  table_directory
)

figure_paths <- c(
  save_maradian_plot(
    trajectory_figure,
    figure_directory,
    primary_figure_stem
  ),
  save_maradian_plot(
    trajectory_figure,
    candidate_figure_directory,
    candidate_figure_stems[["trajectories"]]
  ),
  save_maradian_plot(
    composition_figure,
    candidate_figure_directory,
    candidate_figure_stems[["composition"]]
  ),
  save_maradian_plot(
    contribution_figure,
    candidate_figure_directory,
    candidate_figure_stems[["contributions"]]
  )
)

cat("created ", annual_table_path, "\n", sep = "")
cat("created ", contribution_table_path, "\n", sep = "")
cat("created ", reconciliation_table_path, "\n", sep = "")
for (path in figure_data_paths) {
  cat("created ", path, "\n", sep = "")
}
cat("updated ", figure_manifest_path, "\n", sep = "")
for (path in figure_paths) {
  cat("created ", path, "\n", sep = "")
}
cat("Active-substance tables and figures passed.\n")
