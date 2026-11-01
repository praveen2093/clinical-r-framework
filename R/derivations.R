#' Parse clinical dates
#'
#' Convert Date, POSIXt, or character input to Date using strict supported
#' formats. Missing values are preserved; malformed non-missing values error.
#'
#' @param x Date, POSIXt, or character vector. Numeric dates are not accepted.
#' @param format Optional single format string. By default ISO `YYYY-MM-DD`,
#'   `DDMONYYYY`, and `YYYYMMDD` are accepted.
#' @param variable Name used in error messages.
#' @return A Date vector with the same length as `x`.
#' @examples
#' as_clinical_date(c("2024-01-01", "20240102"))
#' @export
as_clinical_date <- function(x, format = NULL, variable = "date") {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  if (!is.character(x)) stop("`", variable, "` must be Date, POSIXt, or character.", call. = FALSE)
  if (!is.null(format) && (!is.character(format) || length(format) != 1L || is.na(format))) {
    stop("`format` must be NULL or one non-missing character value.", call. = FALSE)
  }
  formats <- if (is.null(format)) c("%Y-%m-%d", "%d%b%Y", "%Y%m%d") else format
  out <- as.Date(rep(NA_character_, length(x)))
  for (candidate in formats) {
    pending <- !is.na(x) & is.na(out)
    if (any(pending)) out[pending] <- suppressWarnings(as.Date(x[pending], format = candidate))
  }
  bad <- !is.na(x) & is.na(out)
  if (any(bad)) {
    examples <- paste(utils::head(unique(x[bad]), 3L), collapse = ", ")
    stop("Invalid ", variable, " value(s): ", examples, call. = FALSE)
  }
  out
}

#' Calculate age in completed years
#'
#' @param date_of_birth Character, Date, or POSIXt dates of birth.
#' @param reference_date Date(s) at which age is calculated; scalar values are
#'   recycled to match `date_of_birth`.
#' @return Integer age vector; missing dates produce `NA`.
#' @examples
#' calculate_age("2000-06-15", "2024-06-14")
#' @export
calculate_age <- function(date_of_birth, reference_date) {
  dob <- as_clinical_date(date_of_birth, variable = "date_of_birth")
  ref <- as_clinical_date(reference_date, variable = "reference_date")
  if (!(length(dob) == length(ref) || length(dob) == 1L || length(ref) == 1L)) {
    stop("Date vectors must have equal lengths or one must have length 1.", call. = FALSE)
  }
  size <- max(length(dob), length(ref))
  dob <- rep(dob, length.out = size)
  ref <- rep(ref, length.out = size)
  age <- as.integer(format(ref, "%Y")) - as.integer(format(dob, "%Y"))
  birthday_not_reached <- format(ref, "%m%d") < format(dob, "%m%d")
  age[birthday_not_reached] <- age[birthday_not_reached] - 1L
  age[is.na(dob) | is.na(ref)] <- NA_integer_
  if (any(age < 0L, na.rm = TRUE)) stop("Reference date precedes date of birth.", call. = FALSE)
  age
}

#' Calculate treatment duration
#'
#' The default is elapsed days (`end_date - start_date`). Set `inclusive = TRUE`
#' to count both boundary dates.
#'
#' @param start_date Treatment start date(s).
#' @param end_date Treatment end date(s); lengths must match or one be scalar.
#' @param inclusive Whether to add one day to non-missing durations.
#' @return Numeric duration in days; missing endpoints produce `NA`.
#' @examples
#' treatment_duration("2024-01-01", "2024-01-10", inclusive = TRUE)
#' @export
treatment_duration <- function(start_date, end_date, inclusive = FALSE) {
  start <- as_clinical_date(start_date, variable = "start_date")
  end <- as_clinical_date(end_date, variable = "end_date")
  if (!(length(start) == length(end) || length(start) == 1L || length(end) == 1L)) {
    stop("Date vectors must have equal lengths or one must have length 1.", call. = FALSE)
  }
  if (!is.logical(inclusive) || length(inclusive) != 1L || is.na(inclusive)) {
    stop("`inclusive` must be one non-missing logical value.", call. = FALSE)
  }
  size <- max(length(start), length(end))
  duration <- as.numeric(rep(end, length.out = size) - rep(start, length.out = size))
  if (inclusive) duration[!is.na(duration)] <- duration[!is.na(duration)] + 1
  if (any(duration < 0, na.rm = TRUE)) stop("End date precedes start date.", call. = FALSE)
  duration
}

#' Derive a baseline flag
#'
#' @param analysis_date Analysis dates.
#' @param treatment_start_date First treatment dates, scalar or matching length.
#' @return Logical vector: `TRUE` on or before treatment start, `FALSE` after,
#'   and `NA` when either date is missing.
#' @examples
#' derive_baseline_flag("2024-01-01", "2024-01-02")
#' @export
derive_baseline_flag <- function(analysis_date, treatment_start_date) {
  analysis <- as_clinical_date(analysis_date, variable = "analysis_date")
  start <- as_clinical_date(treatment_start_date, variable = "treatment_start_date")
  if (!(length(analysis) == length(start) || length(analysis) == 1L || length(start) == 1L)) {
    stop("Date vectors must have equal lengths or one must have length 1.", call. = FALSE)
  }
  size <- max(length(analysis), length(start))
  analysis <- rep(analysis, length.out = size)
  start <- rep(start, length.out = size)
  result <- analysis <= start
  result[is.na(analysis) | is.na(start)] <- NA
  result
}

#' Derive a treatment-emergent flag
#'
#' @param event_start_date Event start date(s).
#' @param treatment_start_date First treatment date(s), scalar or matching length.
#' @param treatment_end_date Last treatment date(s), scalar or matching length.
#' @return Logical vector: `TRUE` when event starts strictly after first dose and
#'   on or before last dose, `FALSE` otherwise, and `NA` for missing dates.
#' @examples
#' derive_treatment_emergent_flag("2024-01-03", "2024-01-01", "2024-01-10")
#' @export
derive_treatment_emergent_flag <- function(event_start_date, treatment_start_date, treatment_end_date) {
  event <- as_clinical_date(event_start_date, variable = "event_start_date")
  start <- as_clinical_date(treatment_start_date, variable = "treatment_start_date")
  end <- as_clinical_date(treatment_end_date, variable = "treatment_end_date")
  lengths <- c(length(event), length(start), length(end))
  size <- max(lengths)
  if (!all(lengths %in% c(1L, size))) stop("Date vectors must have equal lengths or be scalar.", call. = FALSE)
  event <- rep(event, length.out = size)
  start <- rep(start, length.out = size)
  end <- rep(end, length.out = size)
  if (any(end < start, na.rm = TRUE)) stop("Treatment end date precedes start date.", call. = FALSE)
  result <- event > start & event <= end
  result[is.na(event) | is.na(start) | is.na(end)] <- NA
  result
}

#' Derive subject-level population flags
#'
#' @param data Subject-level data frame.
#' @param treatment_start Variable identifying first treatment date.
#' @param randomization_date Variable identifying randomization date.
#' @param completion_date Optional variable identifying study completion.
#' @return Input data with `SAFFL`, `RANDFL`, `ITTFL`, and optionally `COMPLFL`
#'   character flags (`Y`/`N`).
#' @examples
#' derive_population_flags(data.frame(USUBJID = "S1", TRTSDT = "2024-01-01", RANDDT = "2023-12-20"))
#' @export
derive_population_flags <- function(data, treatment_start = "TRTSDT", randomization_date = "RANDDT", completion_date = NULL) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  required <- c(treatment_start, randomization_date, if (!is.null(completion_date)) completion_date)
  absent <- setdiff(required, names(data))
  if (length(absent)) stop("Missing required column(s): ", paste(absent, collapse = ", "), call. = FALSE)
  to_flag <- function(value) ifelse(is.na(value), "N", "Y")
  data$SAFFL <- to_flag(data[[treatment_start]])
  data$RANDFL <- to_flag(data[[randomization_date]])
  data$ITTFL <- data$RANDFL
  if (!is.null(completion_date)) data$COMPLFL <- to_flag(data[[completion_date]])
  data
}