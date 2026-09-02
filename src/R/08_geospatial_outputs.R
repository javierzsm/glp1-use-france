suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(patchwork)
  library(readr)
  library(scales)
  library(sf)
})

source(
  file.path("src", "R", "00_plot_theme.R"),
  local = TRUE
)

analysis_version <- "sap-v1.0-amendments-001-002-003"
geography_source_id <- "etalab_regions_2025_100m"
geography_sha256 <- (
  "af18f6cb83eaf081168d009964f8e4aa8ae1a80ef5388149201e95e015020652"
)

geometry_path <- file.path(
  "data",
  "geography",
  "france_regions_2025_100m.geojson"
)
geography_metadata_path <- file.path(
  "data",
  "metadata",
  "geographic_sources.csv"
)
map_ready_path <- file.path(
  "output",
  "tables",
  "table_06_regional_map_ready_2025.csv"
)
regional_standardised_path <- file.path(
  "output",
  "tables",
  "table_05_regional_standardised_rates_2020_2025.csv"
)

table_directory <- file.path("output", "tables")
figure_data_directory <- file.path(
  table_directory,
  "figure_data"
)
figure_directory <- file.path("output", "figures")
supplement_directory <- file.path(
  figure_directory,
  "supplement",
  "geospatial"
)

primary_figure_stem <- (
  "figure_05_regional_standardised_rate_map_2025"
)
temporal_figure_stem <- (
  "figure_s05_regional_standardised_rate_maps_2022_2025"
)
qc_path <- file.path(
  table_directory,
  "qc_08_geospatial_join.csv"
)
caption_path <- file.path(
  table_directory,
  "figure_captions_geospatial.csv"
)

metropolitan_geometry_codes <- c(
  "11", "24", "27", "28", "32", "44", "52",
  "53", "75", "76", "84", "93", "94"
)
drom_geometry_codes <- c("01", "02", "03", "04", "06")
study_geometry_codes <- c(
  metropolitan_geometry_codes,
  drom_geometry_codes
)
point_standardisation_years <- 2022:2025

required_paths <- c(
  geometry_path,
  geography_metadata_path,
  map_ready_path,
  regional_standardised_path
)

stopifnot(all(file.exists(required_paths)))

sha256_file <- function(path) {
  output <- system2(
    "sha256sum",
    path,
    stdout = TRUE,
    stderr = TRUE
  )

  if (!identical(attr(output, "status"), NULL)) {
    stop("Could not calculate SHA-256 for: ", path)
  }

  strsplit(output[[1]], "[[:space:]]+")[[1]][[1]]
}

observed_geometry_sha256 <- sha256_file(geometry_path)
stopifnot(identical(observed_geometry_sha256, geography_sha256))

geography_metadata <- read_csv(
  geography_metadata_path,
  show_col_types = FALSE,
  col_types = cols(.default = col_character())
)

stopifnot(
  geography_source_id %in% geography_metadata$source_id,
  geography_metadata %>%
    filter(source_id == geography_source_id) %>%
    pull(decompressed_sha256) %>%
    identical(geography_sha256)
)

regions_raw <- st_read(
  geometry_path,
  quiet = TRUE,
  stringsAsFactors = FALSE
) %>%
  mutate(code = as.character(code))

stopifnot(
  all(c("code", "nom", "geometry") %in% names(regions_raw)),
  !anyDuplicated(regions_raw$code),
  all(st_geometry_type(regions_raw) == "MULTIPOLYGON")
)

repair_geometries_with_geos <- function(regions) {
  previous_s2_state <- sf_use_s2()
  on.exit(sf_use_s2(previous_s2_state), add = TRUE)

  geometry_valid_before_repair <- st_is_valid(regions$geometry)

  # The source contains duplicate vertices and a self-crossing coastal ring.
  # S2's geodetic repair leaves the Bretagne ring invalid, whereas GEOS
  # resolves all three defects deterministically for these plotting polygons.
  sf_use_s2(FALSE)
  regions$geometry <- st_make_valid(regions$geometry)
  geometry_valid_after_repair <- st_is_valid(regions$geometry)

  regions %>%
    mutate(
      geometry_valid_before_repair = geometry_valid_before_repair,
      geometry_valid_after_repair = geometry_valid_after_repair
    )
}

regions_selected <- regions_raw %>%
  filter(code %in% study_geometry_codes) %>%
  repair_geometries_with_geos() %>%
  mutate(
    geometry_scope = if_else(
      code %in% drom_geometry_codes,
      "DROM outline",
      "Metropolitan geometry"
    ),
    analysis_region_code = case_when(
      code %in% drom_geometry_codes ~ "5",
      code == "94" ~ "93",
      TRUE ~ code
    )
  )

stopifnot(
  nrow(regions_selected) == 18L,
  setequal(regions_selected$code, study_geometry_codes),
  all(regions_selected$geometry_valid_after_repair)
)

map_ready_2025 <- read_csv(
  map_ready_path,
  show_col_types = FALSE,
  col_types = cols(
    region_code = col_character(),
    .default = col_guess()
  )
)

regional_standardised <- read_csv(
  regional_standardised_path,
  show_col_types = FALSE,
  col_types = cols(
    region_code = col_character(),
    .default = col_guess()
  )
)

stopifnot(
  nrow(map_ready_2025) == 13L,
  setequal(
    map_ready_2025$region_code,
    c("5", setdiff(metropolitan_geometry_codes, "94"))
  ),
  !anyDuplicated(map_ready_2025$region_code),
  all(map_ready_2025$study_year == 2025L)
)

metropolitan_regions <- regions_selected %>%
  filter(geometry_scope == "Metropolitan geometry") %>%
  st_transform(2154)

drom_regions <- regions_selected %>%
  filter(geometry_scope == "DROM outline")

metropolitan_2025 <- metropolitan_regions %>%
  left_join(
    map_ready_2025 %>%
      filter(region_code != "5") %>%
      select(
        analysis_region_code = region_code,
        analysis_region_name = region_name,
        beneficiaries,
        crude_rate_per_100000,
        standardised_rate_per_100000,
        standardised_rank,
        standardisation_status,
        source_analysis_version = analysis_version
      ),
    by = "analysis_region_code",
    relationship = "many-to-one"
  )

overseas_2025 <- map_ready_2025 %>%
  filter(region_code == "5")

temporal_values <- regional_standardised %>%
  filter(
    study_year %in% point_standardisation_years,
    region_code != "5"
  ) %>%
  select(
    study_year,
    analysis_region_code = region_code,
    analysis_region_name = region_name,
    standardised_rate_per_100000,
    standardisation_status,
    source_analysis_version = analysis_version
  )

metropolitan_temporal <- metropolitan_regions[
  rep(
    seq_len(nrow(metropolitan_regions)),
    each = length(point_standardisation_years)
  ),
  c("code", "nom", "analysis_region_code")
] %>%
  rename(
    geometry_code = code,
    geometry_name = nom
  ) %>%
  mutate(
    study_year = rep(
      point_standardisation_years,
      times = nrow(metropolitan_regions)
    )
  ) %>%
  left_join(
    temporal_values,
    by = c("study_year", "analysis_region_code"),
    relationship = "many-to-one"
  )

stopifnot(
  nrow(metropolitan_2025) == 13L,
  nrow(overseas_2025) == 1L,
  nrow(temporal_values) == 48L,
  nrow(metropolitan_temporal) == 52L,
  !any(is.na(metropolitan_2025$standardised_rate_per_100000)),
  !any(is.na(metropolitan_temporal$standardised_rate_per_100000)),
  all(grepl(
    "^point_",
    metropolitan_temporal$standardisation_status
  ))
)

qc_values <- map_ready_2025 %>%
  filter(region_code != "5") %>%
  select(
    analysis_region_code = region_code,
    standardised_rate_per_100000
  )

qc_geospatial <- regions_selected %>%
  st_drop_geometry() %>%
  transmute(
    geometry_code = code,
    geometry_name = nom,
    geometry_scope,
    analysis_region_code,
    geometry_valid_before_repair,
    geometry_valid_after_repair
  ) %>%
  left_join(
    qc_values,
    by = "analysis_region_code",
    relationship = "many-to-one"
  ) %>%
  mutate(
    join_status_2025 = case_when(
      geometry_scope == "DROM outline" ~ "not_joined_by_design",
      !is.na(standardised_rate_per_100000) ~ "matched",
      TRUE ~ "unexpected_unmatched"
    ),
    temporal_point_years = if_else(
      geometry_scope == "Metropolitan geometry",
      length(point_standardisation_years),
      0L
    ),
    geography_source_id,
    geometry_sha256 = observed_geometry_sha256,
    amendment_id = "003",
    analysis_version
  )

stopifnot(
  all(
    qc_geospatial$join_status_2025[
      qc_geospatial$geometry_scope == "Metropolitan geometry"
    ] == "matched"
  ),
  all(
    qc_geospatial$join_status_2025[
      qc_geospatial$geometry_scope == "DROM outline"
    ] == "not_joined_by_design"
  )
)

rate_limits <- range(
  metropolitan_temporal$standardised_rate_per_100000,
  na.rm = TRUE
)

map_scale <- scale_fill_gradientn(
  colours = c(
    maradian_colours[["background"]],
    maradian_colours[["teal"]],
    maradian_colours[["blue"]],
    maradian_colours[["violet"]]
  ),
  limits = rate_limits,
  oob = squish,
  labels = label_number(accuracy = 1, big.mark = ","),
  name = "Beneficiaries per 100,000",
  guide = guide_colorbar(
    barwidth = grid::unit(16, "cm"),
    barheight = grid::unit(0.35, "cm"),
    title.position = "top"
  )
)

map_theme <- theme_maradian() +
  theme(
    axis.title = element_blank(),
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    panel.grid = element_blank(),
    legend.title = element_text(
      colour = maradian_colours[["navy"]],
      face = "bold",
      size = 10,
      hjust = 0.5
    )
  )

metropolitan_map_2025 <- ggplot(metropolitan_2025) +
  geom_sf(
    aes(fill = standardised_rate_per_100000),
    colour = maradian_colours[["background"]],
    linewidth = 0.45
  ) +
  map_scale +
  coord_sf(datum = NA) +
  labs(fill = "Beneficiaries per 100,000") +
  map_theme

overseas_rate_label <- label_number(
  accuracy = 0.1,
  big.mark = ","
)(overseas_2025$standardised_rate_per_100000)

primary_paper_caption <- paste0(
  "Age- and sex-standardised rates of beneficiaries with reimbursed ",
  "GLP-1 receptor agonist dispensings per 100,000 residents across ",
  "metropolitan regional groupings, 2025. Provence-Alpes-Côte d'Azur ",
  "and Corsica form a single analytical grouping and therefore share ",
  "the same estimate. Overseas territories are available only as a ",
  "combined grouping (", overseas_rate_label,
  " per 100,000) and are not mapped separately. Sources: Open Medic; ",
  "INSEE population estimates; Etalab administrative boundaries ",
  "derived from IGN ADMIN EXPRESS."
)

primary_dissemination_caption <- wrap_maradian_text(
  c(
    "Provence-Alpes-Côte d'Azur and Corsica form one analytical",
    "grouping and share the same estimate.",
    paste0(
      "Overseas territories are available only as a combined grouping (",
      overseas_rate_label, " per 100,000) and are not mapped separately."
    ),
    "Sources: Open Medic; INSEE; Etalab/IGN ADMIN EXPRESS."
  )
)

primary_publication_figure <- metropolitan_map_2025 +
  labs(
    title = NULL,
    subtitle = NULL,
    caption = NULL
  ) +
  theme(legend.position = "bottom")

primary_dissemination_figure <- metropolitan_map_2025 +
  labs(
    title = paste(
      "Age-sex-standardised reimbursed glucagon-like",
      "peptide-1 receptor agonist use"
    ),
    subtitle = "Regional rates per 100,000 residents; France, 2025",
    caption = primary_dissemination_caption
  ) +
  theme(
    legend.position = "bottom"
  )

temporal_paper_caption <- paste0(
  "Age- and sex-standardised rates of beneficiaries with reimbursed ",
  "GLP-1 receptor agonist dispensings per 100,000 residents across ",
  "metropolitan regional groupings, 2022–2025. All panels use the same ",
  "colour scale. Results for 2020–2021 are not mapped because disclosure ",
  "control produced intervals rather than complete point estimates. ",
  "Provence-Alpes-Côte d'Azur and Corsica form a single analytical ",
  "grouping. Overseas territories are available only as a combined ",
  "grouping and are not mapped separately. Sources: Open Medic; INSEE ",
  "population estimates; Etalab administrative boundaries derived from ",
  "IGN ADMIN EXPRESS."
)

temporal_dissemination_caption <- wrap_maradian_text(
  c(
    "All panels use the same colour scale. Provence-Alpes-Côte d'Azur",
    "and Corsica form one analytical grouping. Overseas territories",
    "are available only as a combined grouping and are not mapped",
    "separately. Sources: Open Medic; INSEE; Etalab/IGN ADMIN EXPRESS."
  )
)

temporal_base_figure <- ggplot(metropolitan_temporal) +
  geom_sf(
    aes(fill = standardised_rate_per_100000),
    colour = maradian_colours[["background"]],
    linewidth = 0.25
  ) +
  facet_wrap(vars(study_year), ncol = 2) +
  map_scale +
  coord_sf(datum = NA) +
  map_theme +
  theme(
    strip.text = element_text(hjust = 0.5),
    legend.position = "bottom"
  )

temporal_publication_figure <- temporal_base_figure +
  labs(
    title = NULL,
    subtitle = NULL,
    caption = NULL
  )

temporal_dissemination_figure <- temporal_base_figure +
  labs(
    title = "Regional evolution in standardised beneficiary rates",
    subtitle = "Metropolitan analysis groupings; France, 2022-2025",
    caption = temporal_dissemination_caption
  )

primary_figure_data <- bind_rows(
  metropolitan_2025 %>%
    st_drop_geometry() %>%
    transmute(
      figure_component = "metropolitan_choropleth",
      study_year = 2025L,
      geometry_code = code,
      geometry_name = nom,
      analysis_region_code,
      analysis_region_name,
      beneficiaries,
      crude_rate_per_100000,
      standardised_rate_per_100000,
      standardised_rank,
      standardisation_status,
      geography_source_id,
      amendment_id = "003",
      analysis_version = .env$analysis_version
    ),
  overseas_2025 %>%
    transmute(
      figure_component = "combined_overseas_caption_note",
      study_year,
      geometry_code = NA_character_,
      geometry_name = NA_character_,
      analysis_region_code = region_code,
      analysis_region_name = region_name,
      beneficiaries,
      crude_rate_per_100000,
      standardised_rate_per_100000,
      standardised_rank,
      standardisation_status,
      geography_source_id,
      amendment_id = "003",
      analysis_version = .env$analysis_version
    )
)

temporal_figure_data <- metropolitan_temporal %>%
  st_drop_geometry() %>%
  transmute(
    study_year,
    geometry_code,
    geometry_name,
    analysis_region_code,
    analysis_region_name,
    standardised_rate_per_100000,
    standardisation_status,
    geography_source_id,
    amendment_id = "003",
    analysis_version
  ) %>%
  arrange(study_year, geometry_code)

dir.create(table_directory, recursive = TRUE, showWarnings = FALSE)

write_csv(qc_geospatial, qc_path, na = "")

write_csv(
  tibble(
    figure_id = c("05", "S05"),
    caption = c(primary_paper_caption, temporal_paper_caption),
    sources = c(
      paste(
        "Open Medic; INSEE population estimates; Etalab administrative",
        "boundaries derived from IGN ADMIN EXPRESS."
      ),
      paste(
        "Open Medic; INSEE population estimates; Etalab administrative",
        "boundaries derived from IGN ADMIN EXPRESS."
      )
    )
  ),
  caption_path
)

primary_data_path <- save_maradian_figure_data(
  primary_figure_data,
  figure_data_directory,
  primary_figure_stem
)

temporal_data_path <- save_maradian_figure_data(
  temporal_figure_data,
  figure_data_directory,
  temporal_figure_stem
)

manifest_entries <- data.frame(
  figure_id = c("05", "S05"),
  figure_stem = c(
    primary_figure_stem,
    temporal_figure_stem
  ),
  data_file = c(
    primary_data_path,
    temporal_data_path
  ),
  figure_role = c("primary", "supplementary"),
  analysis_scope = c(
    "regional_geospatial",
    "regional_geospatial"
  ),
  analytical_window = c("2025", "2022-2025"),
  notes = c(
    paste(
      "Metropolitan choropleth with publication and dissemination",
      "renderings; combined overseas estimate is not mapped."
    ),
    paste(
      "Common-scale maps restricted to years with complete",
      "standardised point estimates."
    )
  ),
  stringsAsFactors = FALSE
)

manifest_path <- update_maradian_figure_manifest(
  manifest_entries,
  table_directory
)

primary_publication_paths <- save_maradian_plot(
  primary_publication_figure,
  figure_directory,
  paste0(primary_figure_stem, "_publication"),
  width = 12,
  height = 7.5
)

primary_dissemination_paths <- save_maradian_plot(
  primary_dissemination_figure,
  figure_directory,
  paste0(primary_figure_stem, "_dissemination"),
  width = 12,
  height = 8.5
)

temporal_publication_paths <- save_maradian_plot(
  temporal_publication_figure,
  supplement_directory,
  paste0(temporal_figure_stem, "_publication"),
  width = 11,
  height = 7.8
)

temporal_dissemination_paths <- save_maradian_plot(
  temporal_dissemination_figure,
  supplement_directory,
  paste0(temporal_figure_stem, "_dissemination"),
  width = 11,
  height = 9
)

created_paths <- c(
  qc_path,
  caption_path,
  primary_data_path,
  temporal_data_path,
  manifest_path,
  primary_publication_paths,
  primary_dissemination_paths,
  temporal_publication_paths,
  temporal_dissemination_paths
)

stopifnot(
  all(file.exists(created_paths)),
  all(file.info(created_paths)$size > 0),
  all(primary_figure_data$analysis_version == analysis_version),
  all(temporal_figure_data$analysis_version == analysis_version),
  !anyDuplicated(
    primary_figure_data[
      c("figure_component", "geometry_code")
    ]
  ),
  !anyDuplicated(
    temporal_figure_data[
      c("study_year", "geometry_code")
    ]
  )
)

for (created_path in created_paths) {
  message("created ", created_path)
}

message("Geospatial tables, QC and figures passed.")
