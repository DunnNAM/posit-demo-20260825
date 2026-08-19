# =============================================================================
# data-raw/generate_synthetic_data.R
#
# Generates the complete synthetic dataset for the CAQ Posit Connect Cloud
# demonstrator. Run once; the resulting CSVs in data/ are committed (D-001).
#
#   Rscript --vanilla data-raw/generate_synthetic_data.R
#
# ALL DATA PRODUCED HERE IS INVENTED. No real patient, facility, HHS or
# clinical series informs any parameter below. Every number is fixed in the
# decision register so the generator and the demonstration cannot drift apart
# (D-002, D-029).
#
# This script is NOT sourced by either product — it lives in data-raw/, outside
# R/, so Shiny's auto-sourcing never touches it (D-025).
#
# Reading order for the parameters: D-029 fixes the stage distributions and the
# stage-conditioned surgery probabilities; D-030 fixes the S2/S3 sizing on top
# of them; D-011 defines what the three planted signals are for.
# =============================================================================

library(dplyr)
library(tibble)
library(readr)

# Every path below is relative to the repository root, never absolute (I-016).
# Fail immediately and legibly if the script is run from anywhere else, rather
# than writing data/ into whatever directory happened to be current.
if (!dir.exists("data-raw") || !file.exists("dependencies.R")) {
  stop("Run this script from the repository root: Rscript --vanilla data-raw/generate_synthetic_data.R",
       call. = FALSE)
}

# Fixed seed so the dataset is reproducible and the script is itself a demo
# asset (D-001). Changing this invalidates every figure quoted in the report.
set.seed(20260824)

# -----------------------------------------------------------------------------
# 1. Dimensions
# -----------------------------------------------------------------------------

# Names are deliberately, obviously fictional (Australian plants) so that no
# reader can mistake them for real Queensland HHSs or hospitals. The repository
# is public (I-005).
hhs <- tibble::tibble(
  hhs_id   = c("H1", "H2", "H3", "H4", "H5", "H6"),
  hhs_name = c("Ironbark", "Jacaranda", "Boronia", "Wattle", "Kurrajong", "Melaleuca")
)

# Share of the diagnosed cohort resident in each HHS. Uneven, so that HHS-level
# denominators differ enough for funnel-plot control limits to vary visibly.
HHS_RESIDENCE_WEIGHTS <- c(H1 = 0.28, H2 = 0.20, H3 = 0.18, H4 = 0.14, H5 = 0.12, H6 = 0.08)

# 15 facilities, unevenly distributed across the 6 HHSs. `catchment_weight` is
# the relative chance of a surgical patient being treated here before the
# same-HHS preference below is applied.
#
# F09, F13 and F15 are deliberately low-volume (D-012 / brief §6 "Realism"):
# they widen the funnel-plot control limits at the small-denominator end and
# give small-cell suppression something real to act on.
#
# F04 carries planted signal S1 (D-011). It is given a healthy share so that a
# single facility-year holds enough surgical colorectal cases (~120) for an
# annual rate to be readable rather than noise.
facilities <- tibble::tribble(
  ~facility_id, ~facility_name,              ~facility_hhs, ~facility_type, ~catchment_weight,
  "F01",        "Ironbark Base Hospital",    "H1",          "Tertiary",     0.150,
  "F02",        "Ironbark Northside",        "H1",          "Regional",     0.085,
  "F03",        "Ironbark Riverview",        "H1",          "Regional",     0.070,
  "F04",        "Ironbark Southbank",        "H1",          "Regional",     0.110,
  "F05",        "Jacaranda General",         "H2",          "Tertiary",     0.115,
  "F06",        "Jacaranda West",            "H2",          "Regional",     0.070,
  "F07",        "Jacaranda Parklands",       "H2",          "Regional",     0.055,
  "F08",        "Boronia Base Hospital",     "H3",          "Tertiary",     0.105,
  "F09",        "Boronia Ridge",             "H3",          "Rural",        0.018,
  "F10",        "Boronia Coastal",           "H3",          "Regional",     0.060,
  "F11",        "Wattle Base Hospital",      "H4",          "Regional",     0.075,
  "F12",        "Wattle Downs",              "H4",          "Regional",     0.045,
  "F13",        "Kurrajong District",        "H5",          "Rural",        0.014,
  "F14",        "Kurrajong Central",         "H5",          "Regional",     0.017,
  "F15",        "Melaleuca District",        "H6",          "Rural",        0.011
) |>
  dplyr::mutate(
    volume_band = dplyr::case_when(
      catchment_weight >= 0.100 ~ "High",
      catchment_weight >= 0.040 ~ "Medium",
      TRUE                      ~ "Low"
    )
  )

STREAMS <- c("Breast", "Colorectal", "Lung")
YEARS   <- 2015:2024

# Cohort size per stream. Brief §6: 10,000-20,000 per stream, ~45,000 total.
STREAM_N <- c(Breast = 15000L, Colorectal = 16000L, Lung = 14000L)

# Mild growth in incidence across the decade, so the yearly series has a gentle
# denominator trend rather than being flat.
YEAR_WEIGHTS <- stats::setNames(seq(0.88, 1.12, length.out = length(YEARS)), YEARS)

STAGES <- c("I", "II", "III", "IV", "Unknown")

# -----------------------------------------------------------------------------
# 2. Clinical parameters — all invented, all fixed in D-029
# -----------------------------------------------------------------------------

# Stage distribution by stream, all-diagnosed cohort (D-029).
STAGE_DIST <- list(
  Breast     = c(I = 0.40, II = 0.35, III = 0.15, IV = 0.07, Unknown = 0.03),
  Colorectal = c(I = 0.20, II = 0.25, III = 0.30, IV = 0.20, Unknown = 0.05),
  Lung       = c(I = 0.15, II = 0.10, III = 0.25, IV = 0.45, Unknown = 0.05)
)

# Probability of surgery GIVEN stage (D-029). Stage must be drawn before
# surgery and surgery conditioned on it — this ordering is what makes signal S3
# able to explain part of signal S2 (D-011).
SURGERY_P <- list(
  Breast     = c(I = 0.95, II = 0.92, III = 0.80, IV = 0.30, Unknown = 0.50),
  Colorectal = c(I = 0.90, II = 0.88, III = 0.80, IV = 0.35, Unknown = 0.40),
  Lung       = c(I = 0.65, II = 0.50, III = 0.18, IV = 0.03, Unknown = 0.10)
)

# --- Planted signals S2 and S3 (D-011, sized by D-030) -----------------------
# Two HHSs of residence, Lung only.
S2_HHS <- c("H5", "H6")

# S3: stage skewed later in those HHSs. Acting alone this drops the lung
# surgery rate from ~21.1% to ~16.1%.
STAGE_DIST_LUNG_S3 <- c(I = 0.09, II = 0.07, III = 0.26, IV = 0.53, Unknown = 0.05)

# S2: the service-access residual, applied on top of the stage skew. 0.80 is
# not a free choice — the two effects interact, and 0.80 is the value that
# lands the stage-adjusted gap at roughly half the crude gap (D-030). If
# STAGE_DIST_LUNG_S3 is ever retuned this must be re-solved.
S2_ACCESS_MULTIPLIER <- 0.80

# --- Planted signal S1 (D-011) ----------------------------------------------
# Colorectal, one facility, prolonged length of stay (IND-04).
#
# Tracks the all-facility rate 2015-17, deteriorates progressively 2018-2023,
# then corrects sharply in 2024. The shape is the entire argument for the
# dashboard: aggregated into 2015-19 vs 2020-24 the report can show only that
# this facility got worse. It cannot show that the rate peaked at 27% in 2023,
# and it cannot show that the facility had already fixed it by 2024.
S1_FACILITY <- "F04"
S1_STREAM   <- "Colorectal"
S1_PROLONGED_LOS_BY_YEAR <- c(
  `2015` = 0.12, `2016` = 0.12, `2017` = 0.12, `2018` = 0.14, `2019` = 0.16,
  `2020` = 0.18, `2021` = 0.21, `2022` = 0.24, `2023` = 0.27, `2024` = 0.09
)

# Baseline surgical-outcome rates by stream. Everything except the S1 facility
# uses these unchanged.
PROLONGED_LOS_P <- c(Breast = 0.04, Colorectal = 0.12, Lung = 0.14)
HAC_P           <- c(Breast = 0.05, Colorectal = 0.10, Lung = 0.12)
READMIT_P       <- c(Breast = 0.04, Colorectal = 0.08, Lung = 0.09)

# Age at diagnosis, by stream.
AGE_MEAN <- c(Breast = 62, Colorectal = 68, Lung = 70)
AGE_SD   <- c(Breast = 12, Colorectal = 12, Lung = 10)

# -----------------------------------------------------------------------------
# 3. The diagnosed cohort
# -----------------------------------------------------------------------------

n_total <- sum(STREAM_N)

patients <- tibble::tibble(
  patient_id    = sprintf("P%06d", seq_len(n_total)),
  tumour_stream = rep(names(STREAM_N), times = STREAM_N)
)

patients <- patients |>
  dplyr::mutate(
    diagnosis_year = sample(YEARS, dplyr::n(), replace = TRUE, prob = YEAR_WEIGHTS),
    # A random day within the diagnosis year. Supports finer-grained time views
    # in the app than the year alone (brief §6).
    diagnosis_date = as.Date(paste0(diagnosis_year, "-01-01")) +
      floor(stats::runif(dplyr::n()) * 365),
    hhs_residence = sample(names(HHS_RESIDENCE_WEIGHTS), dplyr::n(),
                           replace = TRUE, prob = HHS_RESIDENCE_WEIGHTS),
    age = round(stats::rnorm(dplyr::n(), AGE_MEAN[tumour_stream], AGE_SD[tumour_stream])),
    age = pmin(pmax(age, 25L), 95L),
    # Breast is female-only (D-028): no male breast cohort is generated.
    sex = dplyr::if_else(
      tumour_stream == "Breast",
      "Female",
      sample(c("Male", "Female"), dplyr::n(), replace = TRUE, prob = c(0.55, 0.45))
    ),
    # Drawn independently of every other variable. SEIFA is a stratifier here,
    # not a planted signal — the only designed effects are S1, S2 and S3 (D-011).
    seifa_quintile = sample(paste0("Q", 1:5), dplyr::n(), replace = TRUE,
                            prob = c(0.22, 0.21, 0.20, 0.19, 0.18))
  )

# --- Stage, drawn BEFORE surgery (D-011) -------------------------------------
# Lung patients resident in the two S2 HHSs draw from the skewed distribution;
# everyone else draws from their stream's baseline.
patients$stage <- NA_character_

for (s in STREAMS) {
  idx <- which(patients$tumour_stream == s)
  patients$stage[idx] <- sample(STAGES, length(idx), replace = TRUE, prob = STAGE_DIST[[s]])
}

s3_idx <- which(patients$tumour_stream == "Lung" & patients$hhs_residence %in% S2_HHS)
patients$stage[s3_idx] <- sample(STAGES, length(s3_idx), replace = TRUE,
                                 prob = STAGE_DIST_LUNG_S3)

# --- Surgery, conditioned on stage (D-029, D-030) ----------------------------
p_surgery <- mapply(
  function(stream, stage) SURGERY_P[[stream]][[stage]],
  patients$tumour_stream, patients$stage
)

# The S2 access residual, applied only to lung in the two nominated HHSs.
p_surgery[s3_idx] <- p_surgery[s3_idx] * S2_ACCESS_MULTIPLIER

patients$had_surgery <- stats::runif(n_total) < p_surgery

# -----------------------------------------------------------------------------
# 4. Facility assignment — surgical patients only
# -----------------------------------------------------------------------------
# Patients attach to a facility ONLY if they had surgery. This is the
# eligibility rule that drives the whole architecture: IND-01 and IND-06 are
# therefore cohort-wide and analysable only by HHS of residence, never by
# facility (D-008, brief §4).

# Patients are treated in their own HHS where they can be, but not always.
#
# The multiplier has to be large because it competes with catchment weight: the
# HHSs holding one or two small facilities (H5, H6) have very little local
# capacity, so a modest preference sends most of their residents elsewhere. At
# 4x the statewide cross-HHS flow came out at 53%, which no one would believe.
# At 15x it settles near 30%, concentrated in exactly the HHSs that lack a
# tertiary facility — which is realistic, and consistent with the service-access
# story S2 tells about those same two HHSs (D-011).
SAME_HHS_PREFERENCE <- 15

surg_idx <- which(patients$had_surgery)
patients$facility_id <- NA_character_

for (h in hhs$hhs_id) {
  idx <- surg_idx[patients$hhs_residence[surg_idx] == h]
  if (length(idx) == 0L) next
  w <- facilities$catchment_weight *
    dplyr::if_else(facilities$facility_hhs == h, SAME_HHS_PREFERENCE, 1)
  patients$facility_id[idx] <- sample(facilities$facility_id, length(idx),
                                      replace = TRUE, prob = w)
}

# -----------------------------------------------------------------------------
# 5. Surgical outcomes
# -----------------------------------------------------------------------------
# Eligibility is expressed as NA (D-007): every column below is NA for patients
# who did not have surgery, and the denominator for those indicators is
# !is.na(result_col).

n_surg <- length(surg_idx)
surg_stream <- patients$tumour_stream[surg_idx]
surg_year   <- as.character(patients$diagnosis_year[surg_idx])
surg_fac    <- patients$facility_id[surg_idx]
surg_stage  <- patients$stage[surg_idx]

# --- IND-02 time to surgery --------------------------------------------------
# Waits vary by stream — lung carries a longer diagnostic and staging workup
# before resection, breast the shortest pathway — and by facility.
#
# The facility variation is deliberate but is NOT a planted signal. It is
# drawn from a narrow band so that facilities differ enough for the funnel plot
# and the facility report to be worth reading, while no facility sits outside
# the control limits. The only facility-level outlier in this dataset is F04 on
# IND-04, which is S1 (D-011). Without this, every facility returned an
# identical median of 30 days and the facility-level view of IND-02 was empty.
TTS_SCALE <- c(Breast = 6.4, Colorectal = 7.5, Lung = 8.8)

facility_tts_mult <- stats::setNames(
  stats::runif(nrow(facilities), 0.88, 1.16),
  facilities$facility_id
)

days_to_surgery <- round(
  stats::rgamma(n_surg, shape = 4, scale = TTS_SCALE[surg_stream]) *
    facility_tts_mult[surg_fac]
) + 3L

# --- IND-04 prolonged LOS, carrying signal S1 --------------------------------
# The prolonged-LOS FLAG is drawn first, from a target probability, and
# los_days is then drawn conditional on it. Drawing the length of stay first
# and thresholding at 21 days would leave the indicator rate at the mercy of
# the distribution's tail, and S1 has to land at a specified magnitude every
# time the script is run (D-011).
p_prolonged <- PROLONGED_LOS_P[surg_stream]
prolonged_los_flag <- stats::runif(n_surg) < p_prolonged

# S1 is assigned by EXACT COUNT per facility-year, not by Bernoulli draw.
#
# Why: a facility-year at F04 holds ~125 surgical colorectal cases, where
# binomial noise on a 12% rate is about +/-3pp. Drawn independently, the
# 2015-17 baseline years landed at 18.5%, 20.0% and 14.3% — above the
# 2018-19 values they are supposed to sit below. The chart then shows a dip
# in the middle of a series whose whole purpose is to rise and recover, and
# the demonstration's central narration becomes false on screen.
#
# S1 is a designed artefact (D-011), so it is constructed rather than sampled:
# each year gets exactly its target number of prolonged stays. A small jitter
# is retained so the series still wobbles like a real one instead of tracing
# the parameter vector exactly.
s1_rows <- which(surg_stream == S1_STREAM & surg_fac == S1_FACILITY)

for (y in names(S1_PROLONGED_LOS_BY_YEAR)) {
  rows_y <- s1_rows[surg_year[s1_rows] == y]
  if (length(rows_y) == 0L) next
  p_y <- S1_PROLONGED_LOS_BY_YEAR[[y]] * stats::runif(1, 0.93, 1.07)
  k <- round(length(rows_y) * p_y)
  prolonged_los_flag[rows_y] <- FALSE
  if (k > 0L) prolonged_los_flag[sample(rows_y, k)] <- TRUE
}

# Length of stay consistent with the flag: >21 days when prolonged, 1-21 when
# not. Base stay varies by stream (breast surgery is a much shorter admission).
base_los <- c(Breast = 3, Colorectal = 9, Lung = 8)[surg_stream]
los_days <- ifelse(
  prolonged_los_flag,
  22L + stats::rpois(n_surg, lambda = 9),
  pmin(pmax(round(stats::rnorm(n_surg, base_los, 3)), 1L), 21L)
)

# --- IND-03 hospital-acquired complication -----------------------------------
# Raised for later-stage disease and for longer admissions, so the indicator
# behaves sensibly when the app stratifies by stage.
p_hac <- HAC_P[surg_stream] *
  dplyr::case_when(surg_stage %in% c("III", "IV") ~ 1.4, TRUE ~ 1.0) *
  dplyr::if_else(prolonged_los_flag, 1.8, 1.0)
hac_flag <- stats::runif(n_surg) < pmin(p_hac, 0.95)

# --- IND-05 28-day unplanned readmission -------------------------------------
p_readmit <- READMIT_P[surg_stream] *
  dplyr::if_else(hac_flag, 1.9, 1.0) *
  dplyr::if_else(prolonged_los_flag, 1.4, 1.0)
readmit_28d_flag <- stats::runif(n_surg) < pmin(p_readmit, 0.95)

# Write the surgical columns back, leaving NA everywhere else (D-007).
patients$days_to_surgery    <- NA_integer_
patients$hac_flag           <- NA
patients$los_days           <- NA_integer_
patients$prolonged_los_flag <- NA
patients$readmit_28d_flag   <- NA

patients$days_to_surgery[surg_idx]    <- as.integer(days_to_surgery)
patients$hac_flag[surg_idx]           <- hac_flag
patients$los_days[surg_idx]           <- as.integer(los_days)
patients$prolonged_los_flag[surg_idx] <- prolonged_los_flag
patients$readmit_28d_flag[surg_idx]   <- readmit_28d_flag

# --- Derived groupings -------------------------------------------------------
# diagnosis_period is deliberately NOT stored — it is derived once in
# R/data_prep.R so the report and app can never disagree on the cut (D-020).
patients <- patients |>
  dplyr::mutate(
    age_group_5yr = cut(age, breaks = c(seq(25, 90, by = 5), Inf),
                        right = FALSE, ordered_result = TRUE),
    age_group_10yr = cut(age, breaks = c(seq(25, 85, by = 10), Inf),
                         right = FALSE, ordered_result = TRUE)
  ) |>
  dplyr::select(
    patient_id, tumour_stream, diagnosis_date, diagnosis_year,
    age, age_group_5yr, age_group_10yr, sex, hhs_residence, seifa_quintile,
    stage, had_surgery, facility_id, days_to_surgery, hac_flag,
    los_days, prolonged_los_flag, readmit_28d_flag
  ) |>
  dplyr::arrange(diagnosis_date, patient_id)

# -----------------------------------------------------------------------------
# 6. Metadata tables
# -----------------------------------------------------------------------------

# facility_dims_allowed is the guardrail that makes an invalid stratification
# unrenderable rather than merely discouraged (D-008). IND-01 and IND-06 are
# cohort-wide: patients without surgery have no facility, so grouping either by
# any facility dimension is a category error.
indicator_definitions <- tibble::tribble(
  ~indicator_id, ~label,                              ~short_label,     ~measure_type,  ~cohort,         ~result_col,           ~facility_dims_allowed, ~direction, ~format,
  "IND-01",      "Surgery rate",                      "Surgery rate",   "proportion",   "all_diagnosed", "had_surgery",         FALSE,                  "higher",   "percent",
  "IND-02",      "Time to surgery",                   "Time to surgery","median_iqr",   "surgical",      "days_to_surgery",     TRUE,                   "lower",    "days",
  "IND-03",      "Hospital-acquired complication",    "HAC",            "proportion",   "surgical",      "hac_flag",            TRUE,                   "lower",    "percent",
  "IND-04",      "Prolonged length of stay (>21 days)","Prolonged LOS", "proportion",   "surgical",      "prolonged_los_flag",  TRUE,                   "lower",    "percent",
  "IND-05",      "28-day unplanned readmission",      "Readmission",    "proportion",   "surgical",      "readmit_28d_flag",    TRUE,                   "lower",    "percent",
  "IND-06",      "Stage at diagnosis",                "Stage",          "distribution", "all_diagnosed", "stage",               FALSE,                  "none",     "percent"
) |>
  dplyr::mutate(
    definition_text = c(
      "Proportion of all diagnosed patients who underwent surgical resection. Analysed by HHS of residence only.",
      "Median and interquartile range of days from diagnosis to surgery, surgical patients only.",
      "Proportion of surgical patients recording a hospital-acquired complication.",
      "Proportion of surgical patients with a post-operative length of stay exceeding 21 days.",
      "Proportion of surgical patients with an unplanned readmission within 28 days of discharge.",
      "Distribution of stage at diagnosis across all diagnosed patients. Analysed by HHS of residence only."
    )
  )

# Persona-to-scope mapping for the "View as" switcher. This is a demonstration
# device, not authentication — in production the scope would come from the
# authenticated session, not a dropdown (D-004).
user_roles <- tibble::tribble(
  ~persona_id, ~persona_label,        ~scope_type, ~scope_value, ~tumour_stream_scope,
  "statewide", "Statewide Director",  "all",       NA,           NA,
  "hhs_exec",  "HHS Executive",       "hhs",       "H2",         NA,
  "fac_dir",   "Facility Director",   "facility",  "F04",        NA,
  "clinician", "Clinician",           "facility",  "F04",        "Colorectal"
)

# -----------------------------------------------------------------------------
# 7. Validation — assert the signals landed, do not trust the RNG
# -----------------------------------------------------------------------------
# These are stopifnot() assertions, not messages: if a parameter change moves a
# signal outside its intended magnitude the script must fail loudly rather than
# quietly write a dataset the report's narrative no longer describes.

cat("\n=== VALIDATION ===\n\n")

# --- Structure ---------------------------------------------------------------
stopifnot(nrow(patients) == n_total)
stopifnot(!any(duplicated(patients$patient_id)))
stopifnot(all(patients$sex[patients$tumour_stream == "Breast"] == "Female"))

# Eligibility as NA (D-007): the six surgical columns are NA if and only if the
# patient did not have surgery.
na_cols <- c("facility_id", "days_to_surgery", "hac_flag", "los_days",
             "prolonged_los_flag", "readmit_28d_flag")
for (cl in na_cols) {
  stopifnot(all(is.na(patients[[cl]]) == !patients$had_surgery))
}
cat("Structure: ", nrow(patients), " rows, NA eligibility consistent across all six columns.\n", sep = "")

# --- Surgery rate by stream against D-029 ------------------------------------
by_stream <- patients |>
  dplyr::group_by(tumour_stream) |>
  dplyr::summarise(n = dplyr::n(), surgery_rate = mean(had_surgery), .groups = "drop")
print(as.data.frame(by_stream))

expected <- c(Breast = 0.858, Colorectal = 0.730, Lung = 0.194)
for (s in STREAMS) {
  got <- by_stream$surgery_rate[by_stream$tumour_stream == s]
  stopifnot(abs(got - expected[[s]]) < 0.02)
}
cat("Surgery rates match the D-029 implied values within 2pp.\n\n")

# --- S2 / S3: crude gap, stage-adjusted gap, and the ratio between them -------
lung <- patients |> dplyr::filter(tumour_stream == "Lung")
lung$s2 <- lung$hhs_residence %in% S2_HHS

crude_rest <- mean(lung$had_surgery[!lung$s2])
crude_s2   <- mean(lung$had_surgery[lung$s2])
crude_gap  <- crude_rest - crude_s2

# Direct standardisation: apply the S2 HHSs' stage-specific surgery rates to
# the stage distribution of the rest of the state. What remains is the part of
# the gap that stage does NOT explain — the service-access residual.
stage_mix_rest <- prop.table(table(lung$stage[!lung$s2]))
rate_by_stage_s2 <- tapply(lung$had_surgery[lung$s2], lung$stage[lung$s2], mean)
rate_by_stage_s2 <- rate_by_stage_s2[names(stage_mix_rest)]
adjusted_s2 <- sum(stage_mix_rest * rate_by_stage_s2)
adjusted_gap <- crude_rest - adjusted_s2

cat(sprintf("S2 lung surgery rate, rest of state : %.1f%%\n", 100 * crude_rest))
cat(sprintf("S2 lung surgery rate, H5 + H6       : %.1f%%\n", 100 * crude_s2))
cat(sprintf("  crude gap                         : %.1f pp\n", 100 * crude_gap))
cat(sprintf("  stage-adjusted gap (access)       : %.1f pp\n", 100 * adjusted_gap))
cat(sprintf("  adjusted / crude                  : %.2f  (D-030 target 0.40-0.60)\n\n",
            adjusted_gap / crude_gap))

stopifnot(crude_gap > 0.06, crude_gap < 0.11)
stopifnot(adjusted_gap / crude_gap > 0.40, adjusted_gap / crude_gap < 0.60)

# --- S1: the by-year series versus its two-period aggregation ----------------
s1 <- patients |>
  dplyr::filter(tumour_stream == S1_STREAM, had_surgery, facility_id == S1_FACILITY) |>
  dplyr::group_by(diagnosis_year) |>
  dplyr::summarise(n = dplyr::n(), rate = mean(prolonged_los_flag), .groups = "drop")
print(as.data.frame(s1))

overall_colorectal <- patients |>
  dplyr::filter(tumour_stream == S1_STREAM, had_surgery) |>
  dplyr::pull(prolonged_los_flag) |>
  mean()

p1 <- with(s1, weighted.mean(rate[diagnosis_year <= 2019], n[diagnosis_year <= 2019]))
p2 <- with(s1, weighted.mean(rate[diagnosis_year >= 2020], n[diagnosis_year >= 2020]))
peak <- max(s1$rate)
final <- s1$rate[s1$diagnosis_year == 2024]

cat(sprintf("\nS1 facility %s, colorectal prolonged LOS:\n", S1_FACILITY))
cat(sprintf("  all-facility colorectal rate      : %.1f%%\n", 100 * overall_colorectal))
cat(sprintf("  REPORT sees  2015-19              : %.1f%%\n", 100 * p1))
cat(sprintf("  REPORT sees  2020-24              : %.1f%%\n", 100 * p2))
cat(sprintf("    period-to-period change         : %.1f pp\n", 100 * (p2 - p1)))
cat(sprintf("  APP reveals  peak (%d)           : %.1f%%\n",
            s1$diagnosis_year[which.max(s1$rate)], 100 * peak))
cat(sprintf("  APP reveals  2024 after fix       : %.1f%%\n", 100 * final))
cat(sprintf("    peak-to-2024 recovery           : %.1f pp\n\n", 100 * (peak - final)))

# The demonstration's central claim, asserted rather than asserted-in-prose:
# the aggregation must UNDER-CALL what actually happened. The peak must exceed
# what the second period average shows, and the 2024 correction must be
# invisible in the period figures — 2024 must sit below the baseline period.
rate_of <- function(y) s1$rate[s1$diagnosis_year == y]
baseline_years <- s1$rate[s1$diagnosis_year <= 2017]

# 1. The baseline years must actually track the all-facility rate. This is the
#    check that failed before exact-count assignment was introduced.
stopifnot(all(abs(baseline_years - overall_colorectal) < 0.03))

# 2. Progressive deterioration 2018-2023, allowing a small wobble year to year
#    but requiring the trend to hold end to end.
stopifnot(rate_of(2023) > rate_of(2018) + 0.08)
stopifnot(which.max(s1$rate) == which(s1$diagnosis_year == 2023))

# 3. Sharp correction in 2024, back below where the series started.
stopifnot(final < mean(baseline_years))

# 4. The point of the whole exercise: the two-period aggregation must UNDER-CALL
#    what happened. The peak must sit well above what the second period shows,
#    and the recovery must be larger than the period-to-period change the
#    report is able to display.
stopifnot(peak > p2 + 0.03)
stopifnot((peak - final) > 2 * (p2 - p1))

# 5. Enough cases per facility-year for an annual rate to be worth plotting.
stopifnot(min(s1$n) >= 60)

# --- Low-volume facilities exist and will trigger suppression ----------------
# Printed before it is asserted on, so a failure here is diagnosable from the
# console rather than requiring the script to be re-run by hand.
fac_n <- patients |>
  dplyr::filter(had_surgery) |>
  dplyr::count(facility_id, name = "n_surgical")
cat("\nLowest-volume facilities (total surgical cases, all years):\n")
print(as.data.frame(fac_n[order(fac_n$n_surgical), ][1:4, ]))

# What the design actually requires (D-012, D-023, brief §6 "Realism") is not a
# particular headcount but two properties: funnel plots need points at the
# small-denominator end where the control limits are wide, and suppression
# needs cells that genuinely fall below the threshold.
small_cells <- patients |>
  dplyr::filter(had_surgery) |>
  dplyr::count(facility_id, diagnosis_year, tumour_stream)
cat(sprintf("Facility x year x stream cells below n=5: %d of %d\n",
            sum(small_cells$n < 5), nrow(small_cells)))

stopifnot(sum(fac_n$n_surgical < 800) >= 3)   # wide funnel limits
stopifnot(sum(small_cells$n < 5) >= 5)        # suppression has work to do

# --- Plausibility checks on things a clinical audience would notice ----------
# Neither of these is a planted signal; both are properties that were wrong on
# the first run and would have been visible on screen.

surg <- patients |>
  dplyr::filter(had_surgery) |>
  dplyr::left_join(facilities, by = "facility_id")

cross_hhs <- mean(surg$facility_hhs != surg$hhs_residence)
cat(sprintf("\nTreated outside HHS of residence: %.1f%%\n", 100 * cross_hhs))
stopifnot(cross_hhs > 0.20, cross_hhs < 0.40)

tts <- surg |>
  dplyr::group_by(tumour_stream) |>
  dplyr::summarise(median_days = stats::median(days_to_surgery), .groups = "drop")
print(as.data.frame(tts))
# IND-02 must actually differ by stream — it did not on the first run.
stopifnot(diff(range(tts$median_days)) >= 5)

fac_tts <- surg |>
  dplyr::group_by(facility_id) |>
  dplyr::summarise(median_days = stats::median(days_to_surgery), .groups = "drop")
cat(sprintf("Facility median time to surgery ranges %d to %d days.\n",
            min(fac_tts$median_days), max(fac_tts$median_days)))
# Facilities must differ, but none may look like a planted outlier (D-011).
stopifnot(diff(range(fac_tts$median_days)) >= 4)
stopifnot(max(fac_tts$median_days) / min(fac_tts$median_days) < 1.6)

cat("\n=== ALL ASSERTIONS PASSED ===\n\n")

# -----------------------------------------------------------------------------
# 8. Write
# -----------------------------------------------------------------------------

dir.create("data", showWarnings = FALSE)

readr::write_csv(patients, "data/patients.csv")
readr::write_csv(facilities, "data/facilities.csv")
readr::write_csv(hhs, "data/hhs.csv")
readr::write_csv(indicator_definitions, "data/indicator_definitions.csv")
readr::write_csv(user_roles, "data/user_roles.csv")

cat("Written to data/:\n")
for (f in c("patients.csv", "facilities.csv", "hhs.csv",
            "indicator_definitions.csv", "user_roles.csv")) {
  cat(sprintf("  %-28s %8.1f KB\n", f, file.size(file.path("data", f)) / 1024))
}
