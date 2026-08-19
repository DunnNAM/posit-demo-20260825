# =============================================================================
# dependencies.R  (REPOSITORY ROOT — deliberately NOT in R/)
#
# DEPENDENCY DECLARATION ONLY — NOT SOURCED BY THE APP OR THE REPORT.
#
# Why this file sits at the root, not in R/ (D-025, I-013):
#   Shiny automatically sources every .R file in an R/ directory next to app.R.
#   An earlier version of this file lived in R/ and was therefore executed on
#   app startup, attaching every package listed below whether the app used it or
#   not — directly contradicting its own header comment. Moving it to the root
#   restores the intended behaviour: renv scans every .R file in the project
#   regardless of location, so dependency detection is unaffected, but Shiny
#   leaves it alone.
#
# Purpose (D-015, I-002):
#   renv discovers dependencies by statically scanning .R and .qmd files for
#   library(), require() and pkg::fun() calls. It does NOT execute anything.
#   This file exists so renv::snapshot() writes a complete renv.lock, including
#   packages used in only one module or one code path.
#
#   This replaces the pacman::p_load() pattern from the earlier CAQ MDT
#   prototype. Package names passed as bare symbols to p_load() are invisible to
#   renv's scanner, producing a near-empty lockfile and a failed restore on
#   Posit Connect Cloud.
#
# Day 1 note (I-001, check 2):
#   The heavier packages (plotly, gt, reactable) are declared from Day 1 on
#   purpose, so the deployment probe measures a full-weight renv restore on
#   Connect Cloud. Discovering that restore is slow is far cheaper today than on
#   the morning of the presentation. If it proves slow, prune this list — see
#   the I-001 fallback note.
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
