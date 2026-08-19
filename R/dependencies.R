# =============================================================================
# R/dependencies.R
#
# DEPENDENCY DECLARATION ONLY — THIS FILE IS NEVER SOURCED OR RUN.
#
# Purpose (D-015, I-002):
#   renv discovers project dependencies by statically scanning every .R and .qmd
#   file in the project for library(), require() and pkg::fun() calls. It does
#   NOT execute anything. This file therefore exists solely so that
#   renv::snapshot() writes a complete renv.lock, including packages that are
#   used in only one module or only in one code path.
#
#   This replaces the pacman::p_load() pattern used in the earlier CAQ MDT
#   prototype. Package names passed as bare symbols to p_load() are invisible to
#   renv's scanner, which would produce a near-empty lockfile and a failed
#   restore on Posit Connect Cloud.
#
# Day 1 note (I-001, check 2):
#   The heavier packages below (plotly, gt, reactable) are declared from Day 1 on
#   purpose. The deployment probe is our opportunity to measure how long a full
#   renv restore takes on Connect Cloud. Finding out that restore is slow is far
#   cheaper today than on the morning of the presentation.
#
#   If restore proves slow, prune this list — see the I-001 fallback note.
# =============================================================================

# ── Shiny application ────────────────────────────────────────────────────────
library(shiny)      # Application framework
library(bslib)      # Bootstrap 5 theming and layout (page_sidebar, cards)
library(bsicons)    # Icons for value boxes and headers
library(htmltools)  # Raw tag construction, e.g. suppression footnotes (I-004)

# ── Data manipulation ────────────────────────────────────────────────────────
library(dplyr)      # Core transformation verbs
library(tidyr)      # Reshaping for plot-ready data
library(tibble)     # Tibble construction in the generator and metrics layer
library(readr)      # CSV read/write with explicit column typing
library(forcats)    # Ordered factors for age groups, stage, SEIFA quintile
library(stringr)    # String handling in labels
library(lubridate)  # Diagnosis date handling

# ── Visualisation ────────────────────────────────────────────────────────────
library(ggplot2)    # All static charts
library(scales)     # Axis formatting (percent, comma)
library(plotly)     # ggplotly() for funnel plots ONLY (D-014)

# ── Tabular output ───────────────────────────────────────────────────────────
library(gt)         # Report tables (Quarto)
library(reactable)  # Application tables (Shiny)

# ── Reporting ────────────────────────────────────────────────────────────────
library(knitr)      # Quarto's R engine
library(rmarkdown)  # Pulled in by the Quarto render pipeline
