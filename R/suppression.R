# =============================================================================
# R/suppression.R
#
# Small-cell suppression, implemented once and applied to results — never per
# chart (D-012).
#
# ORDER OF OPERATIONS MATTERS (D-023). Aggregation runs across ALL facilities
# first; suppression is applied to the result afterwards. Never remove a
# facility before the pooled mean and control limits are computed — funnel
# plots derive their value from the low-volume facilities, which is exactly
# what the widening limits illustrate, and dropping them early would both empty
# the informative region of the plot and shift the pooled mean.
#
# One rule, two behaviours:
#   table  — suppress the COUNT and the value; the row remains, marked
#   funnel  — retain the point and its value; suppress the identifying LABEL
#
# Both must be captioned wherever they appear. Note that ggplotly() drops
# subtitle and caption, so on funnel plots the footnote has to be separate
# htmltools text (I-004, D-014).
#
# Definitions only — nothing runs on load (D-025).
# =============================================================================


#' Default suppression threshold
#'
#' Cells with a denominator below this are suppressed (D-012). The app exposes
#' a separate, user-facing "hide facilities with fewer than x cases" control
#' which is a display filter, not this rule.
CAQ_SUPPRESSION_THRESHOLD <- 5


#' Apply small-cell suppression to a result table
#'
#' Call this AFTER caq_calculate_indicator(), never before (D-023).
#'
#' @param res A result tibble from caq_calculate_indicator().
#' @param mode "table" suppresses the value and count; "funnel" keeps both and
#'   suppresses only the identifying label.
#' @param threshold Denominator below which a cell is suppressed.
#' @param label_col For mode = "funnel", the column holding the identifying
#'   label to blank out.
#' @return `res` with a logical `suppressed` column added, and — depending on
#'   mode — values or labels blanked.
caq_suppress <- function(res,
                         mode = c("table", "funnel"),
                         threshold = CAQ_SUPPRESSION_THRESHOLD,
                         label_col = "facility_name") {

  mode <- base::match.arg(mode)

  if (!"denominator" %in% base::names(res)) {
    base::stop("caq_suppress(): no 'denominator' column. Suppression must be ",
               "applied to the output of caq_calculate_indicator(), after ",
               "aggregation (D-023).", call. = FALSE)
  }

  res$suppressed <- res$denominator < threshold

  if (mode == "table") {
    # The row stays so the reader can see that something is there and has been
    # withheld. Silently dropping the row would misrepresent the table as
    # complete.
    res$value[res$suppressed]       <- NA_real_
    res$value_lo[res$suppressed]    <- NA_real_
    res$value_hi[res$suppressed]    <- NA_real_
    if ("numerator" %in% base::names(res)) {
      res$numerator[res$suppressed] <- NA_integer_
    }
    res$denominator[res$suppressed] <- NA_integer_

  } else {
    # Funnel: the point is the whole reason the plot exists. Keep it, and
    # remove only what identifies the facility.
    if (!label_col %in% base::names(res)) {
      base::stop("caq_suppress(): label_col '", label_col, "' not found in the ",
                 "result. Funnel suppression needs the identifying column.",
                 call. = FALSE)
    }
    res[[label_col]] <- base::as.character(res[[label_col]])
    res[[label_col]][res$suppressed] <- "Facility withheld"
  }

  res
}


#' Caption describing what suppression did to a given result
#'
#' Whatever is chosen must be visible in the output, not silent — so every
#' table and plot carrying suppressed cells states it. Returns NULL when
#' nothing was suppressed, so callers can omit the caption entirely rather than
#' printing a misleading "0 cells suppressed" note.
#'
#' @param res A result tibble that has been through caq_suppress().
#' @param mode The mode that was used.
#' @param threshold The threshold that was used.
#' @return A single string, or NULL.
caq_suppression_caption <- function(res,
                                    mode = c("table", "funnel"),
                                    threshold = CAQ_SUPPRESSION_THRESHOLD) {
  mode <- base::match.arg(mode)

  if (!"suppressed" %in% base::names(res)) {
    base::stop("caq_suppression_caption(): result has not been through ",
               "caq_suppress().", call. = FALSE)
  }

  n <- base::sum(res$suppressed, na.rm = TRUE)
  if (n == 0L) return(NULL)

  if (mode == "table") {
    base::paste0(
      n, " cell", base::ifelse(n == 1L, "", "s"),
      " with fewer than ", threshold,
      " cases ", base::ifelse(n == 1L, "has", "have"),
      " been suppressed."
    )
  } else {
    base::paste0(
      n, " facilit", base::ifelse(n == 1L, "y", "ies"),
      " with fewer than ", threshold,
      " cases ", base::ifelse(n == 1L, "is", "are"),
      " shown without a name. The point is retained so the control limits ",
      "remain correct."
    )
  }
}
