# =============================================================================
# app.R  —  CAQ Posit Connect Cloud demonstrator (Shiny dashboard)
#
# STATUS: Day 1 deployment probe. Placeholder content.
#
# Per D-024, this file keeps its name for the life of the project. Real content
# replaces the placeholder content in place, so the Connect Cloud deployment
# record created today is never thrown away and every later push updates an
# already-working content item.
#
# What this probe is testing (I-001):
#   3. Working directory after deployment
#   4. Sourcing shared code from R/
#   5. Reading committed data from data/
#   6. ggplot2 rendering on the build host
#   7. bslib::font_google() resolving over the network (I-003, D-022)
#
# Packages are attached with explicit library() calls so renv can find them
# (D-015). pacman is NOT used in this project.
# =============================================================================

library(shiny)
library(bslib)
library(dplyr)
library(readr)
library(tibble)
library(ggplot2)
library(scales)
library(reactable)

# Shared layer — the assumption under test (D-017): both the app and the Quarto
# report resolve this same relative path from the repository root.
source("R/smoke_shared.R")


# ── Theme ────────────────────────────────────────────────────────────────────
# Trimmed from the earlier CAQ MDT prototype per D-013: palette and semantic
# colours retained, custom filter rail / drawer / chip machinery dropped.
#
# font_google() fetches Lato at build time. That network dependency is exactly
# what I-001 check 7 is measuring — if it fails on Connect Cloud, remove the two
# font arguments and the app falls back to the Bootstrap default stack.

caq_colours <- c(
  blue1     = "#5B89A6",
  blue2     = "#426175",
  green1    = "#56958F",
  dark_grey = "#3A3A3A",
  magenta   = "#993366",
  yellow    = "#F4D35E",
  salmon    = "#F88379"
)

caq_theme <- bslib::bs_theme(
  version      = 5,
  preset       = "flatly",
  base_font    = bslib::font_google("Lato"),
  heading_font = bslib::font_google("Lato"),
  primary      = caq_colours[["blue2"]],
  secondary    = caq_colours[["blue1"]],
  success      = caq_colours[["green1"]],
  info         = caq_colours[["blue1"]],
  warning      = caq_colours[["yellow"]],
  danger       = caq_colours[["salmon"]]
)


# ── UI ───────────────────────────────────────────────────────────────────────
# Stock bslib::page_sidebar (D-013). The real filter controls replace the
# placeholder sidebar content on Day 4.

ui <- bslib::page_sidebar(

  title = "CAQ demonstrator \u2014 deployment probe",
  theme = caq_theme,

  sidebar = bslib::sidebar(
    title = "Probe controls",
    shiny::helpText(
      "Placeholder sidebar. Real filter and stratification controls arrive on ",
      "Day 4, built from indicator_definitions.csv (D-008)."
    ),
    shiny::selectInput(
      inputId  = "facility",
      label    = "Facility",
      choices  = c("All", "PROBE-A", "PROBE-B"),
      selected = "All"
    )
  ),

  # Synthetic-data statement (D-002). Present from Day 1 so it is never
  # forgotten once real-looking content appears.
  bslib::card(
    bslib::card_header("Synthetic data"),
    shiny::p(
      "All data in this application is synthetic and generated for ",
      "demonstration purposes. It does not describe real patients, real ",
      "facilities, or real clinical performance."
    )
  ),

  bslib::card(
    bslib::card_header("Environment diagnostics (I-001)"),
    reactable::reactableOutput("diagnostics")
  ),

  bslib::card(
    bslib::card_header("Graphics device check (I-001, check 6)"),
    shiny::plotOutput("probe_plot", height = "320px")
  )
)


# ── Server ───────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  # Read once at session start rather than reactively. The real app follows the
  # same pattern (D-010): join once, filter reactively.
  probe_data <- smoke_read_data()

  # Placeholder filter, standing in for the real reactive filter chain.
  filtered <- shiny::reactive({
    if (identical(input$facility, "All")) {
      probe_data
    } else {
      dplyr::filter(probe_data, facility_id == input$facility)
    }
  })

  output$diagnostics <- reactable::renderReactable({
    reactable::reactable(
      smoke_diagnostics(product = "Shiny app"),
      columns = list(
        check = reactable::colDef(name = "Check", minWidth = 120),
        value = reactable::colDef(name = "Value", minWidth = 260)
      ),
      striped     = TRUE,
      highlight   = TRUE,
      defaultPageSize = 10
    )
  })

  output$probe_plot <- shiny::renderPlot({
    smoke_plot(filtered())
  })
}


shiny::shinyApp(ui = ui, server = server)
