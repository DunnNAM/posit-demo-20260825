# =============================================================================
# R/metrics.R
#
# THE single place indicator values are calculated. Neither the report nor the
# app computes its own numbers (D-010, I-011) — if the two ever disagree on a
# figure in front of this audience, the demonstration is over.
#
# Calculation is driven by indicator_definitions.csv, not by hardcoded logic
# (D-008). Adding an indicator is a row in that CSV, not an edit here.
#
# Definitions only — nothing runs on load (D-025).
# =============================================================================


#' Look up one indicator definition
#'
#' @param indicators The indicator metadata tibble from caq_load_data().
#' @param indicator_id e.g. "IND-04".
#' @return A one-row tibble.
caq_indicator <- function(indicators, indicator_id) {
  def <- indicators[indicators$indicator_id == indicator_id, ]
  if (base::nrow(def) != 1L) {
    base::stop("caq_indicator(): '", indicator_id, "' matched ", base::nrow(def),
               " rows in indicator_definitions.csv.", call. = FALSE)
  }
  def
}


#' Stratifiers that are valid for a given indicator
#'
#' The guardrail behind D-008. IND-01 (surgery rate) and IND-06 (stage) are
#' cohort-wide: a patient attaches to a facility only if they had surgery, so
#' grouping either by a facility dimension would silently drop everyone who did
#' not have surgery from the denominator. The app builds its group-by menu from
#' this function, so the invalid option never renders rather than merely being
#' discouraged.
#'
#' @param indicators Indicator metadata tibble.
#' @param indicator_id e.g. "IND-01".
#' @return Named character vector of column names, suitable for a selectInput.
caq_valid_stratifiers <- function(indicators, indicator_id) {
  def <- caq_indicator(indicators, indicator_id)
  strat <- caq_stratifiers()

  if (!def$facility_dims_allowed) {
    strat <- strat[!strat %in% CAQ_FACILITY_DIMS]
  }

  # Grouping an indicator by its own result column is not meaningful — every
  # group would be constant. Stage is the live case: IND-06 is the stage
  # distribution, so "stage" must not also appear as its stratifier.
  strat[strat != def$result_col]
}


#' Calculate an indicator
#'
#' @param dat The analysis-ready patients tibble from caq_load_data().
#' @param indicators Indicator metadata tibble.
#' @param indicator_id e.g. "IND-04".
#' @param group_by Character vector of column names to group by. May be empty
#'   for a single overall figure.
#' @return A tibble with the grouping columns plus:
#'   `denominator` — cohort size in the group, always present so that
#'                   R/suppression.R can act on any result uniformly
#'   `numerator`   — events (proportion and distribution only)
#'   `value`       — the rate, proportion, or median
#'   `value_lo` / `value_hi` — IQR bounds for median_iqr, else NA
caq_calculate_indicator <- function(dat, indicators, indicator_id,
                                    group_by = base::character()) {

  def <- caq_indicator(indicators, indicator_id)
  result_col <- def$result_col

  missing <- base::setdiff(group_by, base::names(dat))
  if (base::length(missing) > 0L) {
    base::stop("caq_calculate_indicator(): unknown grouping column(s): ",
               base::paste(missing, collapse = ", "), call. = FALSE)
  }

  # D-008, enforced here rather than trusted to the caller.
  if (!def$facility_dims_allowed) {
    bad <- base::intersect(group_by, CAQ_FACILITY_DIMS)
    if (base::length(bad) > 0L) {
      base::stop(
        indicator_id, " (", def$label, ") is a ", def$cohort,
        " indicator and cannot be grouped by a facility dimension: ",
        base::paste(bad, collapse = ", "),
        ". Patients attach to a facility only if they had surgery, so this ",
        "would drop the non-surgical cohort from the denominator (D-008).",
        call. = FALSE
      )
    }
  }

  # Cohort restriction. Under D-007 eligibility is expressed as NA, so the
  # surgical-cohort denominator is exactly the non-NA rows of the result column.
  # Note this is NOT a general "drop the missing values" step — for stage,
  # "Unknown" is a value and stays in (D-034).
  d <- dat
  if (def$cohort == "surgical") {
    d <- d[!base::is.na(d[[result_col]]), , drop = FALSE]
  } else if (def$cohort != "all_diagnosed") {
    base::stop("caq_calculate_indicator(): unrecognised cohort '", def$cohort,
               "' for ", indicator_id, ".", call. = FALSE)
  }

  # Copied to a fixed name so the summarise below needs no non-standard
  # evaluation gymnastics to reach a column whose name varies by indicator.
  d$metric_value <- d[[result_col]]

  if (def$measure_type %in% c("proportion", "median_iqr") &&
      base::any(base::is.na(d$metric_value))) {
    base::stop("caq_calculate_indicator(): ", indicator_id,
               " has NA in '", result_col, "' after cohort restriction. ",
               "The denominator would be wrong.", call. = FALSE)
  }

  grouped <- dplyr::group_by(d, dplyr::across(dplyr::all_of(group_by)))

  res <- switch(
    def$measure_type,

    "proportion" = dplyr::summarise(
      grouped,
      denominator = dplyr::n(),
      numerator   = base::sum(metric_value),
      value       = numerator / denominator,
      value_lo    = NA_real_,
      value_hi    = NA_real_,
      .groups     = "drop"
    ),

    "median_iqr" = dplyr::summarise(
      grouped,
      denominator = dplyr::n(),
      numerator   = NA_integer_,
      value       = stats::median(metric_value),
      value_lo    = stats::quantile(metric_value, 0.25, names = FALSE),
      value_hi    = stats::quantile(metric_value, 0.75, names = FALSE),
      .groups     = "drop"
    ),

    # A distribution adds one row per level of the result column. Every level is
    # retained, "Unknown" included, and the denominator is the whole group
    # (D-034). .drop = FALSE so a level absent from a group still reports zero
    # rather than vanishing from the chart.
    "distribution" = {
      lvl <- dplyr::group_by(
        d,
        dplyr::across(dplyr::all_of(base::c(group_by, result_col))),
        .drop = FALSE
      )
      counts <- dplyr::summarise(lvl, numerator = dplyr::n(), .groups = "drop")
      counts |>
        dplyr::group_by(dplyr::across(dplyr::all_of(group_by))) |>
        dplyr::mutate(
          denominator = base::sum(numerator),
          value       = numerator / denominator,
          value_lo    = NA_real_,
          value_hi    = NA_real_
        ) |>
        dplyr::ungroup()
    },

    base::stop("caq_calculate_indicator(): unrecognised measure_type '",
               def$measure_type, "' for ", indicator_id, ".", call. = FALSE)
  )

  dplyr::mutate(res, indicator_id = def$indicator_id, .before = 1)
}
