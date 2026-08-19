# =============================================================================
# R/theme.R
#
# Shared visual identity for both products.
#
# This is the ONLY file in R/ permitted a side effect on load: it calls
# ggplot2::theme_set() (D-025). Everything else here is a definition.
#
# ---------------------------------------------------------------------------
# PALETTE VALUES ARE PLACEHOLDERS — see I-022.
#
# D-013 says to adopt the existing CAQ MDT prototype's theme.R verbatim, for
# the palette, scale_colour_caq(), scale_fill_caq() and the theme_set() block.
# That prototype is not present in this repository, so its actual hex values
# were not available when this file was written. The colours below are a
# neutral, colour-blind-safe stand-in chosen so the products render correctly
# today. Replace them with the prototype's real values before the demonstration
# — the function names and signatures are deliberately identical so that
# substitution is a change to this one constant and nothing else.
# ---------------------------------------------------------------------------
#
# No showtext, no font_add_google() here (D-022). The app gets its typeface from
# bslib at the theme level; the report uses a system sans-serif. Fetching fonts
# at render time is a network dependency inside a build host (I-003).
# =============================================================================


#' CAQ categorical palette
#'
#' Ordered so the first three entries carry the three tumour streams, which is
#' the most common colour mapping in both products.
CAQ_PALETTE <- c(
  "#1F5673",  # deep teal
  "#C1666B",  # muted red
  "#4E937A",  # green
  "#E0A458",  # amber
  "#6B7A8F",  # slate
  "#8E6C88",  # plum
  "#3C787E",  # petrol
  "#B36A5E"   # terracotta
)

#' Semantic colours used for indicator direction and suppression
#'
#' `suppressed` is deliberately a flat grey: a suppressed cell must read as
#' absent information, never as a low or high value (D-012, D-023).
CAQ_COLOURS <- list(
  better     = "#4E937A",
  worse      = "#C1666B",
  neutral    = "#6B7A8F",
  reference  = "#333333",
  suppressed = "#BFBFBF"
)


#' Discrete colour scale using the CAQ palette
#'
#' @param ... Passed to ggplot2::discrete_scale().
#' @return A ggplot2 scale.
scale_colour_caq <- function(...) {
  ggplot2::discrete_scale(
    aesthetics = "colour",
    palette = function(n) {
      if (n > base::length(CAQ_PALETTE)) {
        base::stop("scale_colour_caq(): ", n, " levels requested but the palette has ",
                   base::length(CAQ_PALETTE), ".", call. = FALSE)
      }
      CAQ_PALETTE[base::seq_len(n)]
    },
    ...
  )
}

#' Discrete fill scale using the CAQ palette
#'
#' @param ... Passed to ggplot2::discrete_scale().
#' @return A ggplot2 scale.
scale_fill_caq <- function(...) {
  ggplot2::discrete_scale(
    aesthetics = "fill",
    palette = function(n) {
      if (n > base::length(CAQ_PALETTE)) {
        base::stop("scale_fill_caq(): ", n, " levels requested but the palette has ",
                   base::length(CAQ_PALETTE), ".", call. = FALSE)
      }
      CAQ_PALETTE[base::seq_len(n)]
    },
    ...
  )
}

#' Alias kept for the American spelling
scale_color_caq <- scale_colour_caq


#' The shared ggplot2 theme
#'
#' @param base_size Base font size in points.
#' @return A ggplot2 theme object.
theme_caq <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title      = ggplot2::element_text(face = "bold", size = base_size * 1.15),
      plot.subtitle   = ggplot2::element_text(colour = "#555555"),
      # Captions carry the synthetic-data statement and suppression footnotes
      # (D-002, D-012), so they must stay legible rather than decorative.
      plot.caption    = ggplot2::element_text(colour = "#555555", hjust = 0,
                                              size = base_size * 0.8),
      plot.caption.position = "plot",
      plot.title.position   = "plot",
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      strip.text      = ggplot2::element_text(face = "bold"),
      legend.position = "bottom"
    )
}

# The one permitted side effect in R/ (D-025).
ggplot2::theme_set(theme_caq())
