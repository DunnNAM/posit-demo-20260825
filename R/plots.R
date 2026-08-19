# =============================================================================
# R/plots.R
#
# Shared plot functions. Used by BOTH the Quarto report and the Shiny app, so
# a chart looks and behaves the same in each (brief §7).
#
# Every function takes a result tibble from caq_calculate_indicator() and
# returns a ggplot object. Nothing here calculates an indicator value — that
# happens once, in R/metrics.R (D-010, I-011).
#
# All charts are static ggplot2. plotly is used for funnel plots ONLY (D-014),
# and that wrapping happens in the calling product, not here, so these
# functions stay product-agnostic.
#
# Definitions only — nothing runs on load (D-025).
# =============================================================================


#' Format a value according to an indicator's `format` column
#'
#' @param x Numeric vector.
#' @param format "percent" or "days".
#' @return Character vector.
caq_format_value <- function(x, format = "percent") {
  if (format == "percent") {
    scales::percent(x, accuracy = 0.1)
  } else {
    base::paste0(base::round(x, 1), " days")
  }
}


#' Bar chart of an indicator across one grouping variable
#'
#' @param res Result tibble from caq_calculate_indicator().
#' @param x Column name to place on the x axis.
#' @param def One-row indicator definition, from caq_indicator().
#' @param title,subtitle,caption Plot labels. The caption carries the
#'   synthetic-data statement and any suppression note (D-002, D-012).
#' @param highlight Optional vector of x values to pick out in the accent
#'   colour — used to draw the eye to the HHSs carrying signal S2.
#' @return A ggplot object.
caq_plot_indicator_bar <- function(res, x, def,
                                   title = def$label, subtitle = NULL,
                                   caption = NULL, highlight = NULL) {

  res$.x <- base::as.character(res[[x]])
  res$.hl <- if (base::is.null(highlight)) "no" else
    base::ifelse(res$.x %in% highlight, "yes", "no")

  p <- ggplot2::ggplot(res, ggplot2::aes(x = stats::reorder(.x, value), y = value,
                                         fill = .hl)) +
    ggplot2::geom_col(width = 0.7) +
    ggplot2::coord_flip() +
    ggplot2::scale_fill_manual(
      values = c(no = base::unname(caq_colours[["blue1"]]),
                 yes = base::unname(caq_colours[["magenta"]])),
      guide = "none"
    ) +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption,
                  x = NULL, y = def$short_label)

  if (def$format == "percent") {
    p <- p + ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1))
  }
  p
}


#' 100% stacked bar of a distribution indicator
#'
#' Every level is drawn, "Unknown" included — it is a category like any other
#' and is counted in the denominator (D-034). Dropping it would make the bar
#' sum to 100% of a different population than the caption claims.
#'
#' @param res Result tibble from a `distribution` indicator.
#' @param x Grouping column for the x axis.
#' @param level_col The result column holding the levels (e.g. "stage").
#' @param title,subtitle,caption Plot labels.
#' @return A ggplot object.
caq_plot_distribution <- function(res, x, level_col,
                                  title = NULL, subtitle = NULL, caption = NULL) {
  res$.x <- base::as.character(res[[x]])
  res$.lvl <- res[[level_col]]

  ggplot2::ggplot(res, ggplot2::aes(x = .x, y = value, fill = .lvl)) +
    ggplot2::geom_col(width = 0.7) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    scale_fill_caq(name = NULL) +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption,
                  x = NULL, y = "Share of patients")
}


#' Control limits for a funnel plot
#'
#' Exact binomial limits are overkill here; the normal approximation is what
#' CAQ practice uses and is legible on screen. Limits are computed from the
#' POOLED rate across all facilities, which is why suppression must not run
#' first (D-023).
#'
#' @param pooled Pooled proportion across all units.
#' @param n_max Largest denominator to draw limits out to.
#' @param z Vector of z values; 1.96 and 3.09 give 95% and 99.8% limits.
#' @return A tibble with n, z, lower, upper.
caq_funnel_limits <- function(pooled, n_max, z = c(1.96, 3.09)) {
  n_seq <- base::unique(base::round(base::exp(
    base::seq(base::log(5), base::log(base::max(n_max, 10)), length.out = 200)
  )))

  grid <- base::expand.grid(n = n_seq, z = z)
  se <- base::sqrt(pooled * (1 - pooled) / grid$n)

  tibble::tibble(
    n     = grid$n,
    z     = base::factor(grid$z, levels = base::sort(z),
                         labels = base::paste0(c("95%", "99.8%")[base::order(z)], " limits")),
    lower = base::pmax(pooled - grid$z * se, 0),
    upper = base::pmin(pooled + grid$z * se, 1)
  )
}


#' Funnel plot of a proportion indicator by unit
#'
#' Low-volume units keep their point — that is precisely what the widening
#' control limits exist to illustrate — and lose only their identifying label
#' if suppressed (D-023). Pass `res` through caq_suppress(mode = "funnel")
#' before plotting.
#'
#' Note the caption argument is accepted but callers wrapping this in
#' plotly::ggplotly() must render the footnote as separate text: ggplotly()
#' silently drops subtitle and caption (I-004).
#'
#' @param res Result tibble, aggregated then suppressed.
#' @param label_col Column identifying each point on hover.
#' @param def One-row indicator definition.
#' @param title,subtitle,caption Plot labels.
#' @return A ggplot object.
caq_plot_funnel <- function(res, label_col, def,
                            title = def$label, subtitle = NULL, caption = NULL) {

  pooled <- base::sum(res$numerator, na.rm = TRUE) / base::sum(res$denominator, na.rm = TRUE)
  limits <- caq_funnel_limits(pooled, n_max = base::max(res$denominator, na.rm = TRUE))

  res$.label <- base::as.character(res[[label_col]])
  # Suppressed points are drawn in the flat neutral so they read as "identity
  # withheld" rather than as a value judgement (D-012).
  res$.state <- base::ifelse(res$suppressed, "Name withheld", "Named")

  # The control limits carry NO legend, deliberately.
  #
  # ggplotly() builds trace names from the interaction of every discrete
  # aesthetic, `group` included, which produced legend entries reading
  # "(99.8% limits,1)". Removing `group` is not an option — the upper and lower
  # bounds would join into one line. So the limits are drawn without a guide and
  # the line styles are named in the footnote instead, which also keeps the
  # legend to the one thing a reader needs to act on: which points are named.
  # This is the same class of problem as I-004 — ggplotly rewrites more than the
  # caption.
  limits_long <- tidyr::pivot_longer(
    limits, cols = c("lower", "upper"),
    names_to = "bound", values_to = "limit"
  )

  ggplot2::ggplot() +
    ggplot2::geom_line(
      data = limits_long,
      ggplot2::aes(x = n, y = limit, linetype = z,
                   group = base::interaction(z, bound)),
      colour = base::unname(caq_colours[["neutral1"]]), linewidth = 0.4,
      show.legend = FALSE
    ) +
    ggplot2::geom_hline(yintercept = pooled,
                        colour = base::unname(caq_colours[["dark_grey"]]),
                        linewidth = 0.5) +
    ggplot2::geom_point(
      data = res,
      ggplot2::aes(x = denominator, y = value, colour = .state, text = .label),
      size = 2.4, alpha = 0.9
    ) +
    ggplot2::scale_colour_manual(
      values = c("Named" = base::unname(caq_colours[["blue1"]]),
                 "Name withheld" = base::unname(caq_colours[["neutral1"]])),
      name = NULL
    ) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::scale_linetype_manual(values = c("dashed", "dotted"), guide = "none") +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption,
                  x = "Number of surgical patients", y = def$short_label)
}


#' Line chart of an indicator over time
#'
#' DELIBERATELY NOT USED BY THE REPORT (D-011). The static report presents the
#' two five-year periods only; the year-by-year series is what the Shiny app
#' reveals, and showing it in the report would dissolve the central contrast
#' the demonstration is built on. Defined here because the app needs it on
#' Day 4 and plot functions are shared.
#'
#' @param res Result tibble grouped by diagnosis_year.
#' @param def One-row indicator definition.
#' @param group Optional column for multiple series.
#' @param title,subtitle,caption Plot labels.
#' @return A ggplot object.
caq_plot_trend <- function(res, def, group = NULL,
                           title = def$label, subtitle = NULL, caption = NULL) {
  p <- if (base::is.null(group)) {
    ggplot2::ggplot(res, ggplot2::aes(x = diagnosis_year, y = value))
  } else {
    res$.g <- base::as.character(res[[group]])
    ggplot2::ggplot(res, ggplot2::aes(x = diagnosis_year, y = value,
                                      colour = .g, group = .g))
  }

  p <- p +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_x_continuous(breaks = base::seq(2015, 2024, by = 1)) +
    ggplot2::labs(title = title, subtitle = subtitle, caption = caption,
                  x = NULL, y = def$short_label)

  if (!base::is.null(group)) p <- p + scale_colour_caq(name = NULL)
  if (def$format == "percent") {
    p <- p + ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1))
  }
  p
}
