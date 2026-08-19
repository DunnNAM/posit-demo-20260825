# =============================================================================
# R/data_prep.R
#
# Reads the five committed CSVs, restores the types CSV cannot carry, derives
# what must not be stored, and joins once into a single analysis-ready tibble
# consumed by BOTH products (D-010).
#
# Definitions only — nothing here runs on load (D-025).
#
# Paths are relative-from-root and never absolute (I-016). The Shiny app runs
# from /cloud/project and the report renders in an ephemeral temporary copy;
# both are the root of the repository tree, so "data/patients.csv" resolves in
# each. The report's setup chunk sets knitr root.dir accordingly.
# =============================================================================


#' Columns that identify a treating facility
#'
#' Grouping an all-diagnosed indicator by any of these is a category error:
#' patients attach to a facility only if they had surgery, so the non-surgical
#' population would be silently dropped from the denominator. Enforced in
#' R/metrics.R rather than trusted to the UI (D-008).
CAQ_FACILITY_DIMS <- c(
  "facility_id", "facility_name", "facility_hhs",
  "facility_hhs_name", "facility_type", "volume_band"
)

#' Stage levels, in clinical order
#'
#' "Unknown" is last but it is a level like any other — counted in every
#' denominator, never dropped (D-034). Note that `stage` is never NA: under
#' D-007 NA means "not eligible for this indicator", which is a different
#' statement from "stage not known".
CAQ_STAGE_LEVELS <- c("I", "II", "III", "IV", "Unknown")

#' Five-year period labels (D-020)
CAQ_PERIOD_LEVELS <- c("2015-19", "2020-24")


#' Order interval labels produced by cut() by their lower bound
#'
#' cut() returns labels like "[65,70)". Written to CSV and read back they are
#' plain character, and their ordering is lost (I-019). Sorting them as strings
#' happens to work for this dataset's breaks, which is precisely why it must not
#' be relied on — a relabelling to "65-69" would silently reorder every age axis
#' with no error. This derives the order from the numbers instead.
#'
#' @param x Character vector of interval labels.
#' @return The unique labels, ordered by numeric lower bound.
caq_order_interval_labels <- function(x) {
  lab <- base::sort(base::unique(x[!base::is.na(x)]))
  lower <- base::as.numeric(base::sub("^[\\[\\(]([-0-9.]+),.*$", "\\1", lab))
  if (base::any(base::is.na(lower))) {
    base::stop("caq_order_interval_labels(): could not parse a lower bound from: ",
               base::paste(lab[base::is.na(lower)], collapse = ", "), call. = FALSE)
  }
  lab[base::order(lower)]
}


#' Read and prepare the analysis dataset
#'
#' @param data_dir Directory holding the committed CSVs, relative to the
#'   repository root.
#' @return A list with:
#'   `patients`   analysis-ready tibble, one row per patient, dimensions joined
#'   `facilities` facility dimension
#'   `hhs`        HHS dimension
#'   `indicators` indicator metadata driving the UI and the metrics layer
#'   `personas`   persona-to-scope mapping for the "View as" switcher (D-004)
caq_load_data <- function(data_dir = "data") {

  path <- function(f) base::file.path(data_dir, f)

  # Column types are declared, never guessed. readr guesses from the first 1000
  # rows by default, which on a 45,000-row file is a silent-wrong-type risk.
  patients <- readr::read_csv(
    path("patients.csv"),
    col_types = readr::cols(
      patient_id         = readr::col_character(),
      tumour_stream      = readr::col_character(),
      diagnosis_date     = readr::col_date(),
      diagnosis_year     = readr::col_integer(),
      age                = readr::col_integer(),
      age_group_5yr      = readr::col_character(),
      age_group_10yr     = readr::col_character(),
      sex                = readr::col_character(),
      hhs_residence      = readr::col_character(),
      seifa_quintile     = readr::col_character(),
      stage              = readr::col_character(),
      had_surgery        = readr::col_logical(),
      facility_id        = readr::col_character(),
      days_to_surgery    = readr::col_integer(),
      hac_flag           = readr::col_logical(),
      los_days           = readr::col_integer(),
      prolonged_los_flag = readr::col_logical(),
      readmit_28d_flag   = readr::col_logical()
    )
  )

  facilities <- readr::read_csv(
    path("facilities.csv"),
    col_types = readr::cols(
      facility_id      = readr::col_character(),
      facility_name    = readr::col_character(),
      facility_hhs     = readr::col_character(),
      facility_type    = readr::col_character(),
      catchment_weight = readr::col_double(),
      volume_band      = readr::col_character()
    )
  )

  hhs <- readr::read_csv(
    path("hhs.csv"),
    col_types = readr::cols(
      hhs_id   = readr::col_character(),
      hhs_name = readr::col_character()
    )
  )

  indicators <- readr::read_csv(
    path("indicator_definitions.csv"),
    col_types = readr::cols(
      indicator_id          = readr::col_character(),
      label                 = readr::col_character(),
      short_label           = readr::col_character(),
      measure_type          = readr::col_character(),
      cohort                = readr::col_character(),
      result_col            = readr::col_character(),
      facility_dims_allowed = readr::col_logical(),
      direction             = readr::col_character(),
      format                = readr::col_character(),
      definition_text       = readr::col_character()
    )
  )

  personas <- readr::read_csv(
    path("user_roles.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )

  hhs_lookup <- stats::setNames(hhs$hhs_name, hhs$hhs_id)

  patients <- patients |>
    dplyr::left_join(
      dplyr::select(facilities, "facility_id", "facility_name", "facility_hhs",
                    "facility_type", "volume_band"),
      by = "facility_id"
    ) |>
    dplyr::mutate(
      # Five-year period is DERIVED, never stored, so the report and the app
      # cannot disagree on the cut (D-020).
      diagnosis_period = base::factor(
        base::ifelse(diagnosis_year <= 2019, CAQ_PERIOD_LEVELS[1], CAQ_PERIOD_LEVELS[2]),
        levels = CAQ_PERIOD_LEVELS
      ),

      # Explicit factor levels — CSV carries none (I-019).
      stage = base::factor(stage, levels = CAQ_STAGE_LEVELS),
      sex   = base::factor(sex, levels = c("Female", "Male")),
      seifa_quintile = base::factor(seifa_quintile, levels = base::paste0("Q", 1:5)),
      age_group_5yr  = base::factor(age_group_5yr,
                                    levels = caq_order_interval_labels(age_group_5yr),
                                    ordered = TRUE),
      age_group_10yr = base::factor(age_group_10yr,
                                    levels = caq_order_interval_labels(age_group_10yr),
                                    ordered = TRUE),
      tumour_stream = base::factor(tumour_stream),

      # HHS codes are joined to names for display. Residence is present for
      # every patient; facility HHS only for those who had surgery, so its NA
      # is meaningful and is left as NA (D-007).
      hhs_residence_name = base::factor(base::unname(hhs_lookup[hhs_residence]),
                                        levels = hhs$hhs_name),
      facility_hhs_name  = base::factor(base::unname(hhs_lookup[facility_hhs]),
                                        levels = hhs$hhs_name),
      hhs_residence      = base::factor(hhs_residence, levels = hhs$hhs_id),
      facility_hhs       = base::factor(facility_hhs, levels = hhs$hhs_id)
    )

  # Fail loudly rather than let a malformed factor reach a chart axis.
  if (base::any(base::is.na(patients$stage))) {
    base::stop("caq_load_data(): stage contains NA after factor conversion. ",
               "stage must always carry one of: ",
               base::paste(CAQ_STAGE_LEVELS, collapse = ", "),
               " — NA means ineligible (D-007), not unstaged (D-034).", call. = FALSE)
  }
  if (base::any(base::is.na(patients$hhs_residence))) {
    base::stop("caq_load_data(): hhs_residence contains a code absent from hhs.csv.",
               call. = FALSE)
  }

  base::list(
    patients   = patients,
    facilities = facilities,
    hhs        = hhs,
    indicators = indicators,
    personas   = personas
  )
}


#' Stratification variables offered to the user, with display labels
#'
#' Fixed by D-019. First Nations status and remoteness are deliberately absent:
#' a synthetic disparity appearing on screen invites a reaction to a finding
#' that does not exist.
#'
#' @return A named character vector, names being display labels.
caq_stratifiers <- function() {
  c(
    "Tumour stream"             = "tumour_stream",
    "Year of diagnosis"         = "diagnosis_year",
    "Five-year period"          = "diagnosis_period",
    "Age group (5-year)"        = "age_group_5yr",
    "Age group (10-year)"       = "age_group_10yr",
    "Sex"                       = "sex",
    "HHS of residence"          = "hhs_residence_name",
    "SEIFA quintile"            = "seifa_quintile",
    "Stage at diagnosis"        = "stage",
    "Treating facility"         = "facility_name",
    "HHS of treating facility"  = "facility_hhs_name"
  )
}
