# =============================================================================
# tests/verify_shared_layer.R
#
# Checks the shared R/ layer against direct calculations on the raw CSV.
#
#   Rscript --vanilla tests/verify_shared_layer.R
#
# Why this exists (I-011): the report and the app both take their numbers from
# R/metrics.R, so a defect there is invisible — both products would be wrong in
# the same direction and agree with each other perfectly. The only way to catch
# it is to compute a figure a second way, from the CSV, and compare.
#
# NOT in R/ — Shiny auto-sources everything there and this file has side
# effects by design (D-025).
# =============================================================================

library(dplyr)
library(readr)

if (!dir.exists("R") || !file.exists("dependencies.R")) {
  stop("Run from the repository root: Rscript --vanilla tests/verify_shared_layer.R",
       call. = FALSE)
}

for (f in c("R/theme.R", "R/data_prep.R", "R/metrics.R", "R/suppression.R")) {
  source(f)
}

d <- caq_load_data()
raw <- readr::read_csv("data/patients.csv", show_col_types = FALSE)

pass <- function(msg) cat("  PASS  ", msg, "\n", sep = "")
near <- function(a, b, tol = 1e-9) isTRUE(abs(a - b) < tol)

cat("\n=== SHARED LAYER VERIFICATION ===\n\n")

# --- 1. The layer agrees with a direct calculation on the CSV (I-011) --------
cat("1. Layer vs direct calculation on the raw CSV\n")

lay <- caq_calculate_indicator(d$patients, d$indicators, "IND-01")
dir <- mean(raw$had_surgery)
stopifnot(near(lay$value, dir))
pass(sprintf("IND-01 surgery rate: layer %.6f == direct %.6f", lay$value, dir))

lay <- caq_calculate_indicator(d$patients, d$indicators, "IND-04")
sub <- raw[!is.na(raw$prolonged_los_flag), ]
stopifnot(near(lay$value, mean(sub$prolonged_los_flag)),
          lay$denominator == nrow(sub))
pass(sprintf("IND-04 prolonged LOS: layer %.6f == direct %.6f, denominator %d",
             lay$value, mean(sub$prolonged_los_flag), lay$denominator))

lay <- caq_calculate_indicator(d$patients, d$indicators, "IND-02")
sub <- raw[!is.na(raw$days_to_surgery), ]
stopifnot(near(lay$value, stats::median(sub$days_to_surgery)))
pass(sprintf("IND-02 median time to surgery: layer %g == direct %g",
             lay$value, stats::median(sub$days_to_surgery)))

# --- 2. Eligibility is NA, and NA is not the same as Unknown (D-007, D-034) --
cat("\n2. Cohort restriction and the NA / Unknown distinction\n")

surgical <- caq_calculate_indicator(d$patients, d$indicators, "IND-03")
stopifnot(surgical$denominator == sum(raw$had_surgery))
pass(sprintf("IND-03 denominator is the surgical cohort only: %d of %d",
             surgical$denominator, nrow(raw)))

alldx <- caq_calculate_indicator(d$patients, d$indicators, "IND-01")
stopifnot(alldx$denominator == nrow(raw))
pass(sprintf("IND-01 denominator is every diagnosed patient: %d", alldx$denominator))

stage <- caq_calculate_indicator(d$patients, d$indicators, "IND-06")
stopifnot("Unknown" %in% as.character(stage$stage))
stopifnot(near(sum(stage$value), 1))
stopifnot(unique(stage$denominator) == nrow(raw))
pass(sprintf("IND-06 keeps Unknown (%.1f%%) and sums to 100%% over all %d patients",
             100 * stage$value[stage$stage == "Unknown"], unique(stage$denominator)))

# --- 3. D-008 guardrail: invalid stratification must be impossible ----------
cat("\n3. Facility-dimension guardrail (D-008)\n")

for (bad in c("facility_id", "facility_name", "facility_hhs_name")) {
  err <- tryCatch({
    caq_calculate_indicator(d$patients, d$indicators, "IND-01", group_by = bad)
    NULL
  }, error = function(e) conditionMessage(e))
  stopifnot(!is.null(err), grepl("facility dimension", err))
}
pass("IND-01 grouped by any facility dimension raises an error")

err <- tryCatch({
  caq_calculate_indicator(d$patients, d$indicators, "IND-06", group_by = "facility_name")
  NULL
}, error = function(e) conditionMessage(e))
stopifnot(!is.null(err))
pass("IND-06 grouped by facility raises an error")

ok <- caq_calculate_indicator(d$patients, d$indicators, "IND-04",
                              group_by = c("facility_name", "diagnosis_year"))
stopifnot(nrow(ok) > 0)
pass(sprintf("IND-04 by facility and year is permitted: %d rows", nrow(ok)))

strat <- caq_valid_stratifiers(d$indicators, "IND-01")
stopifnot(!any(strat %in% CAQ_FACILITY_DIMS))
pass(sprintf("caq_valid_stratifiers() offers %d options for IND-01, none facility-based",
             length(strat)))

# --- 4. The planted signals survive the layer (D-011) ------------------------
cat("\n4. Planted signals, calculated through the layer\n")

s1 <- caq_calculate_indicator(
  d$patients |> dplyr::filter(tumour_stream == "Colorectal", facility_id == "F04"),
  d$indicators, "IND-04", group_by = "diagnosis_year"
)
peak <- s1$value[which.max(s1$value)]
final <- s1$value[s1$diagnosis_year == 2024]
base_yrs <- mean(s1$value[s1$diagnosis_year <= 2017])
stopifnot(peak > 0.25, final < base_yrs)
pass(sprintf("S1 at F04: baseline %.1f%% -> peak %.1f%% (%d) -> %.1f%% (2024)",
             100 * base_yrs, 100 * peak, s1$diagnosis_year[which.max(s1$value)],
             100 * final))

s2 <- caq_calculate_indicator(
  d$patients |> dplyr::filter(tumour_stream == "Lung"),
  d$indicators, "IND-01", group_by = "hhs_residence"
)
low <- s2$value[s2$hhs_residence %in% c("H5", "H6")]
rest <- s2$value[!s2$hhs_residence %in% c("H5", "H6")]
stopifnot(max(low) < min(rest))
pass(sprintf("S2: H5/H6 lung surgery %.1f%%-%.1f%% vs %.1f%%-%.1f%% elsewhere",
             100 * min(low), 100 * max(low), 100 * min(rest), 100 * max(rest)))

s3 <- caq_calculate_indicator(
  d$patients |> dplyr::filter(tumour_stream == "Lung"),
  d$indicators, "IND-06", group_by = "hhs_residence"
)
iv <- s3[s3$stage == "IV", ]
stopifnot(all(iv$value[iv$hhs_residence %in% c("H5", "H6")] >
              max(iv$value[!iv$hhs_residence %in% c("H5", "H6")])))
pass("S3: stage IV share is higher in H5 and H6 than in every other HHS")

# --- 5. Suppression, applied after aggregation (D-023, D-012) ---------------
cat("\n5. Suppression\n")

cells <- caq_calculate_indicator(d$patients, d$indicators, "IND-05",
                                 group_by = c("facility_name", "diagnosis_year",
                                              "tumour_stream"))
n_small <- sum(cells$denominator < CAQ_SUPPRESSION_THRESHOLD)
stopifnot(n_small > 0)

tbl <- caq_suppress(cells, mode = "table")
stopifnot(sum(tbl$suppressed) == n_small,
          all(is.na(tbl$value[tbl$suppressed])),
          all(is.na(tbl$denominator[tbl$suppressed])),
          nrow(tbl) == nrow(cells))
pass(sprintf("table mode: %d cells suppressed, rows retained, values blanked", n_small))

fun <- caq_suppress(cells, mode = "funnel", label_col = "facility_name")
stopifnot(sum(fun$suppressed) == n_small,
          all(!is.na(fun$value[fun$suppressed])),
          all(fun$facility_name[fun$suppressed] == "Facility withheld"))
pass("funnel mode: points and values retained, identifying label removed")

# Pooled mean must be computed before suppression, not after (D-023).
#
# Be honest about the size of this: with 21 small cells out of 450 the effect
# on the pooled mean is in the fifth decimal place. The real argument for
# D-023's ordering is the funnel plot — suppressing first would delete exactly
# the low-denominator points the widening control limits exist to display. The
# pooled mean shifting at all is a secondary confirmation that the order is not
# merely cosmetic, not a headline.
pooled_before <- sum(cells$numerator) / sum(cells$denominator)
kept <- cells[cells$denominator >= CAQ_SUPPRESSION_THRESHOLD, ]
pooled_after <- sum(kept$numerator) / sum(kept$denominator)
cat(sprintf("        pooled rate aggregating first: %.7f\n", pooled_before))
cat(sprintf("        if suppressed first:           %.7f  (%d of %d points lost)\n",
            pooled_after, nrow(cells) - nrow(kept), nrow(cells)))
stopifnot(!near(pooled_before, pooled_after, 1e-12))
pass("order changes the pooled mean, and suppressing first would drop the low-n points")

cap <- caq_suppression_caption(tbl, mode = "table")
stopifnot(!is.null(cap), grepl("suppressed", cap))
pass(paste0("caption produced: \"", cap, "\""))

stopifnot(is.null(caq_suppression_caption(
  caq_suppress(caq_calculate_indicator(d$patients, d$indicators, "IND-01"),
               mode = "table"), mode = "table")))
pass("no caption when nothing was suppressed")

# --- 6. Factor levels survived the CSV round trip (I-019) -------------------
cat("\n6. Factor levels restored after reading (I-019)\n")

stopifnot(is.ordered(d$patients$age_group_5yr))
ages <- levels(d$patients$age_group_5yr)
lower <- as.numeric(sub("^\\[([0-9.]+),.*$", "\\1", ages))
stopifnot(!is.unsorted(lower))
pass(sprintf("age_group_5yr is ordered, %d levels, %s ... %s",
             length(ages), ages[1], ages[length(ages)]))

stopifnot(identical(levels(d$patients$stage), CAQ_STAGE_LEVELS))
pass(paste("stage levels:", paste(levels(d$patients$stage), collapse = ", ")))

stopifnot(identical(levels(d$patients$diagnosis_period), CAQ_PERIOD_LEVELS))
pass(paste("diagnosis_period derived, not stored:",
           paste(levels(d$patients$diagnosis_period), collapse = " / ")))

cat("\n=== ALL CHECKS PASSED ===\n\n")
