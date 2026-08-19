# =============================================================================
# R/smoke_shared.R
#
# DAY 1 DEPLOYMENT PROBE — TEMPORARY. Replaced on Day 2 by the real shared
# layer (data_prep.R / metrics.R / plots.R / suppression.R).
#
# Purpose (I-001):
#   This file is sourced by BOTH deployable content items — app.R and
#   facility-report.qmd. That is the whole point. Under D-017 the repository has
#   a flat root, so both products should resolve "R/smoke_shared.R" and
#   "data/smoke_data.csv" identically. If that assumption is wrong on Posit
#   Connect Cloud, we need to know today, not on Day 4 with the real shared
#   indicator layer built on top of it.
#
#   Deliberately uses plain relative paths rather than here::here(). We are
#   testing the working-directory assumption, so we must not paper over it.
#
# Exports:
#   smoke_diagnostics()  — tibble of environment facts, rendered by both products
#   smoke_read_data()    — reads the committed CSV
#   smoke_plot()         — a minimal ggplot2 chart, to prove the graphics device
# =============================================================================


#' Collect environment diagnostics for the deployment probe
#'
#' Answers I-001 checks 3, 4 and 5 by reporting what the runtime environment
#' actually looks like, rather than what we assume it looks like.
#'
#' @param product Character label identifying which content item is calling
#'   ("Quarto report" or "Shiny app"), so the two outputs can be compared.
#' @return A tibble with one row per diagnostic check.
smoke_diagnostics <- function(product) {

  # Resolve the data file relative to the working directory. mustWork = FALSE so
  # that a missing file reports as a failed check rather than throwing — a
  # diagnostic tool should never fall over on the thing it is diagnosing.
  data_path <- base::normalizePath("data/smoke_data.csv", mustWork = FALSE)

  tibble::tibble(
    check = c(
      "Content item",
      "R version",
      "Working directory",
      "Shared R/ file sourced",
      "Data file found",
      "Resolved data path",
      "dplyr version",
      "ggplot2 version",
      "Platform"
    ),
    value = c(
      product,
      base::paste(base::R.version$major, base::R.version$minor, sep = "."),
      base::getwd(),
      "TRUE",  # If this file did not source, nothing here would run at all.
      base::as.character(base::file.exists("data/smoke_data.csv")),
      data_path,
      base::as.character(utils::packageVersion("dplyr")),
      base::as.character(utils::packageVersion("ggplot2")),
      base::paste(base::R.version$platform, collapse = "")
    )
  )
}


#' Read the committed probe dataset
#'
#' Column types are declared explicitly rather than guessed. This is the habit we
#' want in the real prep layer — readr's type guessing reads only the first 1000
#' rows by default and silently produces the wrong type on larger files.
#'
#' @return A tibble of the probe data.
smoke_read_data <- function() {
  readr::read_csv(
    "data/smoke_data.csv",
    col_types = readr::cols(
      facility_id = readr::col_character(),
      year        = readr::col_integer(),
      n_cases     = readr::col_integer(),
      n_events    = readr::col_integer()
    )
  ) |>
    # Placeholder rate calculation — stands in for the real indicator logic that
    # will live in R/metrics.R from Day 2.
    dplyr::mutate(rate = n_events / n_cases)
}


#' Minimal chart to prove the graphics device renders after deployment
#'
#' Answers I-001 check 6. Uses no custom fonts: under D-022 showtext is dropped,
#' and font resolution for the app is handled by bslib at the theme level.
#'
#' @param dat A tibble as returned by smoke_read_data().
#' @return A ggplot object.
smoke_plot <- function(dat) {
  ggplot2::ggplot(
    dat,
    ggplot2::aes(x = year, y = rate, colour = facility_id)
  ) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::labs(
      title  = "Deployment probe \u2014 placeholder data",
      x      = "Year",
      y      = "Rate",
      colour = "Facility"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "bottom")
}
