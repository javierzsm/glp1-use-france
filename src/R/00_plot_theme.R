suppressPackageStartupMessages({
  library(ggplot2)
  library(scales)
})

maradian_colours <- c(
  navy = "#16324F",
  blue = "#2878B5",
  teal = "#00A6A6",
  green = "#3BA272",
  gold = "#F2B134",
  coral = "#E76F51",
  violet = "#7B61A8",
  neutral = "#68717A",
  background = "#FAFAF8",
  grid = "#D9DEE3"
)

maradian_metric_colours <- c(
  "Annual beneficiaries" = unname(
    maradian_colours[["blue"]]
  ),
  "Beneficiaries per 100,000 residents" = unname(
    maradian_colours[["teal"]]
  )
)

maradian_sex_colours <- c(
  Male = unname(maradian_colours[["blue"]]),
  Female = unname(maradian_colours[["coral"]])
)

maradian_atc5_colours <- c(
  A10BJ01 = unname(maradian_colours[["blue"]]),
  A10BJ02 = unname(maradian_colours[["teal"]]),
  A10BJ03 = unname(maradian_colours[["gold"]]),
  A10BJ04 = unname(maradian_colours[["green"]]),
  A10BJ05 = unname(maradian_colours[["coral"]]),
  A10BJ06 = unname(maradian_colours[["violet"]]),
  A10BJ07 = unname(maradian_colours[["navy"]])
)

wrap_maradian_text <- function(text, width = 105) {
  paste(
    strwrap(
      paste(text, collapse = " "),
      width = width
    ),
    collapse = "\n"
  )
}

label_maradian_compact <- function(values) {
  labels <- number(
    values,
    accuracy = 1,
    big.mark = ","
  )
  million_values <- abs(values) >= 1e6
  thousand_values <- (
    abs(values) >= 1e3 & !million_values
  )

  labels[million_values] <- paste0(
    number(
      values[million_values] / 1e6,
      accuracy = 0.01
    ),
    "M"
  )
  labels[thousand_values] <- paste0(
    number(
      values[thousand_values] / 1e3,
      accuracy = 0.1
    ),
    "K"
  )

  labels
}

label_maradian_signed_compact <- function(values) {
  paste0(
    ifelse(values > 0, "+", ""),
    label_maradian_compact(values)
  )
}

theme_maradian <- function(
  base_size = 12,
  base_family = "sans"
) {
  theme_minimal(
    base_size = base_size,
    base_family = base_family
  ) +
    theme(
      plot.background = element_rect(
        fill = maradian_colours[["background"]],
        colour = NA
      ),
      panel.background = element_rect(
        fill = maradian_colours[["background"]],
        colour = NA
      ),
      plot.title = element_text(
        face = "bold",
        size = rel(1.25),
        colour = maradian_colours[["navy"]]
      ),
      plot.subtitle = element_text(
        colour = maradian_colours[["neutral"]],
        margin = margin(b = 10)
      ),
      strip.text = element_text(
        face = "bold",
        hjust = 0,
        colour = maradian_colours[["navy"]]
      ),
      panel.grid.major = element_line(
        colour = maradian_colours[["grid"]],
        linewidth = 0.35
      ),
      panel.grid.minor = element_blank(),
      axis.title = element_text(
        colour = maradian_colours[["navy"]]
      ),
      axis.text = element_text(
        colour = maradian_colours[["neutral"]]
      ),
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.text = element_text(
        colour = maradian_colours[["navy"]]
      ),
      plot.caption = element_text(
        colour = maradian_colours[["neutral"]],
        hjust = 0,
        size = rel(0.75),
        margin = margin(t = 10)
      ),
      plot.caption.position = "plot",
      plot.title.position = "plot"
    )
}

save_maradian_plot <- function(
  plot,
  directory,
  filename_stem,
  width = 9,
  height = 7
) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )

  png_path <- file.path(
    directory,
    paste0(filename_stem, ".png")
  )
  pdf_path <- file.path(
    directory,
    paste0(filename_stem, ".pdf")
  )

  ggsave(
    png_path,
    plot = plot,
    width = width,
    height = height,
    units = "in",
    dpi = 300,
    bg = maradian_colours[["background"]]
  )
  ggsave(
    pdf_path,
    plot = plot,
    width = width,
    height = height,
    units = "in",
    device = "pdf",
    bg = maradian_colours[["background"]]
  )

  stopifnot(
    file.exists(png_path),
    file.info(png_path)$size > 0,
    file.exists(pdf_path),
    file.info(pdf_path)$size > 0
  )

  c(png_path, pdf_path)
}

save_maradian_figure_data <- function(
  data,
  directory,
  filename_stem
) {
  dir.create(
    directory,
    recursive = TRUE,
    showWarnings = FALSE
  )

  data_path <- file.path(
    directory,
    paste0(filename_stem, ".csv")
  )

  readr::write_csv(
    as.data.frame(data),
    data_path,
    na = ""
  )

  stopifnot(
    file.exists(data_path),
    file.info(data_path)$size > 0
  )

  data_path
}

update_maradian_figure_manifest <- function(
  entries,
  table_directory
) {
  required_columns <- c(
    "figure_id",
    "figure_stem",
    "data_file",
    "figure_role",
    "analysis_scope",
    "analytical_window",
    "notes"
  )

  stopifnot(
    all(required_columns %in% names(entries)),
    !anyDuplicated(entries$figure_id)
  )

  dir.create(
    table_directory,
    recursive = TRUE,
    showWarnings = FALSE
  )

  manifest_path <- file.path(
    table_directory,
    "figure_data_manifest.csv"
  )

  existing <- if (file.exists(manifest_path)) {
    readr::read_csv(
      manifest_path,
      show_col_types = FALSE
    )
  } else {
    entries[0, required_columns]
  }

  stopifnot(
    all(required_columns %in% names(existing))
  )

  retained <- existing[
    !existing$figure_id %in% entries$figure_id,
    required_columns
  ]

  manifest <- dplyr::arrange(
    dplyr::bind_rows(
      retained,
      entries[, required_columns]
    ),
    figure_id
  )

  readr::write_csv(
    manifest,
    manifest_path,
    na = ""
  )

  stopifnot(
    file.exists(manifest_path),
    file.info(manifest_path)$size > 0,
    !anyDuplicated(manifest$figure_id)
  )

  manifest_path
}
