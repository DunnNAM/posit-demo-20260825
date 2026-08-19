# =============================================================================
# R/theme.R
#
# Shared visual identity for both products.
#
# Adopted from the CAQ presentation repository's src/theme.R (D-013), which is
# the source of truth for the palette. The hex values, the `caq_colours` names,
# the `.caq_scale_order` sequence and the base theme are taken from there
# unchanged — so a future re-sync is a copy of two constants.
#
# This is the ONLY file in R/ permitted a side effect on load: ggplot2::theme_set()
# (D-025).
#
# ---------------------------------------------------------------------------
# THREE DELIBERATE DEVIATIONS FROM THE UPSTREAM FILE, all documented in I-022:
#
# 1. The upstream `base::message()` on load is dropped. Shiny auto-sources every
#    file in R/ on every app start (D-025), so it would print on each startup
#    for no benefit, and it is a side effect beyond the permitted theme_set().
#
# 2. Caption and title positioning are added to the base theme. The captions
#    carry the synthetic-data statement (D-002) and the suppression footnotes
#    (D-012), so they must be legible and left-aligned to the plot rather than
#    small grey text under the axis.
#
# 3. The discrete scales interpolate when a variable has more levels than the
#    palette. Upstream uses scale_colour_manual() with 7 values, which errors at
#    render time on anything larger — and this project offers age_group_5yr
#    (14 levels) and facility (15) as stratifiers (D-019). For 7 levels or
#    fewer the output is identical to upstream's.
# ---------------------------------------------------------------------------
#
# No showtext, no font_add_google() here (D-022). The app takes its typeface
# from bslib; the report uses a system sans-serif. Fetching fonts at render time
# is a network dependency inside a build host (I-003).
# =============================================================================


#' CAQ colour palette
#'
#' Names and values adopted verbatim from the presentation repository.
caq_colours <- c(
  "blue1"            = "#5B89A6",
  "blue2"            = "#426175",
  "green1"           = "#56958F",
  "dark_grey"        = "#3A3A3A",
  "magenta"          = "#993366",
  "yellow"           = "#F4D35E",
  "salmon"           = "#F88379",
  "light_background" = "#D4CFC5",
  "dark_background"  = "#426175",
  "neutral1"         = "#C4C7CA",
  "neutral2"         = "#E5E0DA",
  "neutral3"         = "#D8DADC"
)

#' Ordered sequence for discrete scales — primary colours lead
.caq_scale_order <- c(
  "blue1", "magenta", "green1", "salmon", "yellow", "blue2", "dark_grey"
)

#' Semantic colours, mapped onto the palette above
#'
#' `suppressed` is deliberately a flat neutral: a suppressed cell must read as
#' absent information, never as a low or high value (D-012, D-023).
CAQ_SEMANTIC <- c(
  better     = base::unname(caq_colours[["green1"]]),
  worse      = base::unname(caq_colours[["magenta"]]),
  neutral    = base::unname(caq_colours[["blue1"]]),
  reference  = base::unname(caq_colours[["dark_grey"]]),
  suppressed = base::unname(caq_colours[["neutral1"]])
)


#' Build n colours from the CAQ palette
#'
#' Returns the ordered palette directly when it is large enough — identical to
#' the upstream manual scale — and interpolates across it when a variable has
#' more levels than the palette holds.
#'
#' @param n Number of colours required.
#' @param extend If FALSE, error rather than interpolate.
#' @return Character vector of n hex colours.
caq_pal <- function(n, extend = TRUE) {
  base_cols <- base::unname(caq_colours[.caq_scale_order])
  if (n <= base::length(base_cols)) {
    return(base_cols[base::seq_len(n)])
  }
  if (!extend) {
    base::stop("caq_pal(): ", n, " levels requested but the CAQ discrete palette has ",
               base::length(base_cols),
               ". Use a variable with fewer levels, or extend = TRUE.", call. = FALSE)
  }
  # Interpolating keeps a chart readable, but a 14-level categorical colour
  # scale is hard to read whatever the colours. Prefer position over colour for
  # high-cardinality variables such as age group.
  grDevices::colorRampPalette(base_cols)(n)
}


#' Discrete colour scale using the CAQ palette
#'
#' @param extend Passed to caq_pal().
#' @param ... Passed to ggplot2::discrete_scale().
#' @return A ggplot2 scale.
scale_colour_caq <- function(extend = TRUE, ...) {
  ggplot2::discrete_scale(
    aesthetics = "colour",
    palette = function(n) caq_pal(n, extend = extend),
    ...
  )
}

#' Discrete fill scale using the CAQ palette
#'
#' @param extend Passed to caq_pal().
#' @param ... Passed to ggplot2::discrete_scale().
#' @return A ggplot2 scale.
scale_fill_caq <- function(extend = TRUE, ...) {
  ggplot2::discrete_scale(
    aesthetics = "fill",
    palette = function(n) caq_pal(n, extend = extend),
    ...
  )
}

#' Alias kept for the American spelling
scale_color_caq <- scale_colour_caq


#' The shared ggplot2 theme
#'
#' Base and colours adopted from the presentation repository; caption and title
#' positioning added for this project's footnote requirements (deviation 2).
#'
#' @param base_size Base font size in points.
#' @return A ggplot2 theme object.
theme_caq <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      text            = ggplot2::element_text(colour = caq_colours[["dark_grey"]]),
      plot.title      = ggplot2::element_text(colour = caq_colours[["blue2"]], face = "bold"),
      plot.subtitle   = ggplot2::element_text(colour = caq_colours[["blue1"]]),
      axis.title      = ggplot2::element_text(colour = caq_colours[["blue2"]]),
      legend.position = "bottom",

      # Added for this project: the synthetic-data statement (D-002) and the
      # suppression footnotes (D-012) live in the caption and must be readable.
      plot.caption          = ggplot2::element_text(colour = caq_colours[["dark_grey"]],
                                                    hjust = 0, size = base_size * 0.8),
      plot.caption.position = "plot",
      plot.title.position   = "plot"
    )
}

# The one permitted side effect in R/ (D-025).
ggplot2::theme_set(theme_caq())
