`%||%` <- function(x, y) if (is.null(x)) y else x

.validation_schemas <- list(
  DM = list(required = c("STUDYID", "USUBJID", "SUBJID", "SITEID", "AGE", "SEX", "RACE", "ARM", "ACTARM", "RFSTDTC", "RFENDTC"),
            types = c(USUBJID = "character", AGE = "numeric"), key = "USUBJID", subject = "USUBJID",
            nonmissing = c("STUDYID", "USUBJID"), categories = list(SEX = c("M", "F", "U", "UNDIFFERENTIATED")),
            ranges = list(AGE = c(0, 120)), dates = c("RFSTDTC", "RFENDTC")),
  AE = list(required = c("STUDYID", "USUBJID", "AESEQ", "AETERM", "AESTDTC", "AEENDTC", "AESEV", "AESER"),
            types = c(USUBJID = "character", AESEQ = "numeric"), key = c("USUBJID", "AESEQ"), subject = "USUBJID",
            nonmissing = c("STUDYID", "USUBJID", "AESEQ", "AETERM"), categories = list(AESEV = c("MILD", "MODERATE", "SEVERE"), AESER = c("Y", "N")),
            dates = c("AESTDTC", "AEENDTC")),
  LB = list(required = c("STUDYID", "USUBJID", "LBSEQ", "LBTESTCD", "LBORRES", "LBSTRESN", "LBDTC"),
            types = c(USUBJID = "character", LBSEQ = "numeric", LBSTRESN = "numeric"), key = c("USUBJID", "LBSEQ"), subject = "USUBJID",
            nonmissing = c("STUDYID", "USUBJID", "LBSEQ", "LBTESTCD"), ranges = list(LBSTRESN = c(0, Inf)), dates = "LBDTC"),
  ADSL = list(required = c("STUDYID", "USUBJID", "SITEID", "AGE", "SEX", "TRT01P", "TRT01A", "TRTSDT", "TRTEDT", "SAFFL", "ITTFL"),
              types = c(USUBJID = "character", AGE = "numeric"), key = "USUBJID", subject = "USUBJID",
              nonmissing = c("STUDYID", "USUBJID"), categories = list(SAFFL = c("Y", "N"), ITTFL = c("Y", "N")),
              ranges = list(AGE = c(0, 120)), dates = c("TRTSDT", "TRTEDT")),
  ADAE = list(required = c("STUDYID", "USUBJID", "AESEQ", "AETERM", "AESTDT", "TRTEMFL"),
              types = c(USUBJID = "character", AESEQ = "numeric"), key = c("USUBJID", "AESEQ"), subject = "USUBJID",
              nonmissing = c("STUDYID", "USUBJID", "AESEQ"), categories = list(TRTEMFL = c("Y", "N")), dates = "AESTDT"),
  ADLB = list(required = c("STUDYID", "USUBJID", "PARAMCD", "AVISITN", "AVAL", "BASE", "CHG", "ADT"),
              types = c(USUBJID = "character", AVISITN = "numeric", AVAL = "numeric", BASE = "numeric", CHG = "numeric"),
              key = c("USUBJID", "PARAMCD", "AVISITN"), subject = "USUBJID",
              nonmissing = c("STUDYID", "USUBJID", "PARAMCD", "AVISITN"), dates = "ADT")
)

.record_identifiers <- function(data, rows, subject = "USUBJID") {
  if (!length(rows)) return("")
  if (subject %in% names(data)) {
    ids <- as.character(data[[subject]][rows])
    ids[is.na(ids) | ids == ""] <- paste0("row:", rows[is.na(ids) | ids == ""])
    paste(unique(ids), collapse = ",")
  } else paste(rows, collapse = ",")
}

.validation_row <- function(rule, dataset, variable = "", severity = "ERROR", status = "PASS",
                            affected = 0L, description = "Validation passed.", record_ids = "") {
  data.frame(rule_id = rule, dataset_name = dataset, variable_name = variable, severity = severity,
             status = status, affected_records = as.integer(affected), description = description,
             record_ids = record_ids, stringsAsFactors = FALSE)
}

.expected_type <- function(x, expected) {
  switch(expected,
    character = is.character(x),
    numeric = is.numeric(x),
    integer = is.integer(x),
    logical = is.logical(x),
    Date = inherits(x, "Date"),
    FALSE
  )
}

#' Validate a clinical dataset against configurable structural rules
#'
#' @param data Dataset data frame.
#' @param dataset One of `DM`, `AE`, `LB`, `ADSL`, `ADAE`, or `ADLB`.
#' @param rules Optional named list overriding schema fields such as `required`,
#'   `types`, `key`, `nonmissing`, `categories`, `ranges`, `dates`, `subject`,
#'   `name_pattern`, and severity values (named by rule ID).
#' @param export_path Optional CSV output path for the result rows.
#' @return A list with `results` (one row per validation rule) and `summary`.
#'   Results include rule ID, dataset/variable, severity, status, affected row
#'   count, description, and relevant subject identifiers or row numbers.
#' @examples
#' validate_dataset(data.frame(USUBJID = character()), "DM")
#' @export
validate_dataset <- function(data, dataset, rules = NULL, export_path = NULL) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  dataset <- match.arg(dataset, names(.validation_schemas))
  if (!is.null(rules) && !is.list(rules)) stop("`rules` must be a named list.", call. = FALSE)
  schema <- utils::modifyList(.validation_schemas[[dataset]], rules %||% list())
  severity_for <- function(id) {
    severity <- schema$severity[[id]] %||% "ERROR"
    if (!severity %in% c("ERROR", "WARNING", "INFO")) stop("Invalid severity for ", id, ".", call. = FALSE)
    severity
  }
  results <- list()
  add <- function(id, variable = "", rows = integer(), description = "Validation passed.", forced_fail = FALSE) {
    failed <- forced_fail || length(rows) > 0L
    results[[length(results) + 1L]] <<- .validation_row(id, dataset, variable, severity_for(id),
      if (failed) "FAIL" else "PASS", if (forced_fail && !length(rows)) 1L else length(rows),
      if (failed) description else "Validation passed.", .record_identifiers(data, rows, schema$subject))
  }

  absent <- setdiff(schema$required, names(data))
  add("REQCOL", rows = integer(), description = paste("Missing required column(s):", paste(absent, collapse = ", ")), forced_fail = length(absent) > 0L)
  bad_names <- which(!grepl(schema$name_pattern %||% "^[A-Z][A-Z0-9]*$", names(data)))
  name_text <- if (length(bad_names)) paste("Invalid variable name(s):", paste(names(data)[bad_names], collapse = ", ")) else ""
  results[[length(results) + 1L]] <- .validation_row("VARNAME", dataset, severity = severity_for("VARNAME"),
    status = if (length(bad_names)) "FAIL" else "PASS", affected = length(bad_names),
    description = if (length(bad_names)) name_text else "Validation passed.", record_ids = "")

  for (variable in names(schema$types)) {
    if (variable %in% names(data)) add("DATATYPE", variable, if (.expected_type(data[[variable]], schema$types[[variable]])) integer() else seq_len(nrow(data)),
      paste0("Expected ", schema$types[[variable]], " data.", if (nrow(data)) paste0(" Observed ", paste(class(data[[variable]]), collapse = "/"), ".") else ""),
      forced_fail = nrow(data) == 0L && !.expected_type(data[[variable]], schema$types[[variable]]))
  }
  for (variable in intersect(schema$nonmissing, names(data))) {
    values <- data[[variable]]
    rows <- which(is.na(values) | (is.character(values) & !is.na(values) & trimws(values) == ""))
    add("REQVAL", variable, rows, "Required value is missing or blank.")
  }
  subject <- schema$subject
  if (subject %in% names(data)) {
    ids <- data[[subject]]
    rows <- which(is.na(ids) | (is.character(ids) & !is.na(ids) & trimws(ids) == ""))
    add("SUBJID", subject, rows, "Subject identifier is missing or blank.")
  }
  if (all(schema$key %in% names(data)) && length(schema$key)) {
    rows <- which(duplicated(data[schema$key]) | duplicated(data[schema$key], fromLast = TRUE))
    add("DUPKEY", paste(schema$key, collapse = "+"), rows, "Duplicate key value(s) detected.")
  } else {
    results[[length(results) + 1L]] <- .validation_row("DUPKEY", dataset, paste(schema$key, collapse = "+"),
      severity_for("DUPKEY"), if (all(schema$key %in% names(data))) "PASS" else "FAIL",
      if (all(schema$key %in% names(data))) 0L else 1L,
      if (all(schema$key %in% names(data))) "Validation passed." else "Key column(s) are missing.")
  }
  for (variable in names(schema$categories)) {
    if (variable %in% names(data)) {
      values <- as.character(data[[variable]])
      rows <- which(!is.na(values) & !values %in% schema$categories[[variable]])
      add("CATVAL", variable, rows, paste("Value is outside allowed set:", paste(schema$categories[[variable]], collapse = ", ")))
    }
  }
  for (variable in names(schema$ranges)) {
    if (variable %in% names(data)) {
      bounds <- schema$ranges[[variable]]
      values <- data[[variable]]
      rows <- if (is.numeric(values)) which(!is.na(values) & (values < bounds[[1L]] | values > bounds[[2L]])) else seq_len(nrow(data))
      add("NUMRNG", variable, rows, paste0("Expected numeric values in [", bounds[[1L]], ", ", bounds[[2L]], "]."),
          forced_fail = !is.numeric(values) && nrow(data) == 0L)
    }
  }
  for (variable in intersect(schema$dates, names(data))) {
    values <- data[[variable]]
    bad <- if (inherits(values, "Date") || inherits(values, "POSIXt")) rep(FALSE, length(values)) else if (is.character(values)) {
      vapply(seq_along(values), function(i) if (is.na(values[[i]]) || trimws(values[[i]]) == "") FALSE else
        inherits(try(as_clinical_date(values[[i]], variable = variable), silent = TRUE), "try-error"), logical(1))
    } else rep(TRUE, length(values))
    rows <- which(bad)
    add("DATEFMT", variable, rows, "Date must be a valid ISO, DDMONYYYY, or YYYYMMDD value.")
  }
  result <- if (length(results)) do.call(rbind, results) else data.frame()
  rownames(result) <- NULL
  summary <- list(dataset_name = dataset, total_rules = nrow(result), passed_rules = sum(result$status == "PASS"),
                  failed_rules = sum(result$status == "FAIL"), errors = sum(result$status == "FAIL" & result$severity == "ERROR"),
                  warnings = sum(result$status == "FAIL" & result$severity == "WARNING"),
                  valid = !any(result$status == "FAIL" & result$severity == "ERROR"))
  output <- list(results = result, summary = summary)
  if (!is.null(export_path)) utils::write.csv(result, file = export_path, row.names = FALSE, na = "")
  output
}

#' Validate SDTM Demographics (DM)
#' @param data Dataset data frame.
#' @param rules Optional rule overrides accepted by the common validation engine.
#' @param export_path Optional CSV path for result rows.
#' @return Structured validation results and summary.
#' @examples
#' validate_sdtm_dm(data.frame())
#' @export
validate_sdtm_dm <- function(data, rules = NULL, export_path = NULL) validate_dataset(data, "DM", rules, export_path)

#' Validate SDTM Adverse Events (AE)
#' @param data Dataset data frame.
#' @param rules Optional rule overrides accepted by the common validation engine.
#' @param export_path Optional CSV path for result rows.
#' @return Structured validation results and summary.
#' @examples
#' validate_sdtm_ae(data.frame())
#' @export
validate_sdtm_ae <- function(data, rules = NULL, export_path = NULL) validate_dataset(data, "AE", rules, export_path)

#' Validate SDTM Laboratory (LB)
#' @param data Dataset data frame.
#' @param rules Optional rule overrides accepted by the common validation engine.
#' @param export_path Optional CSV path for result rows.
#' @return Structured validation results and summary.
#' @examples
#' validate_sdtm_lb(data.frame())
#' @export
validate_sdtm_lb <- function(data, rules = NULL, export_path = NULL) validate_dataset(data, "LB", rules, export_path)

#' Validate ADaM Subject-Level Analysis (ADSL)
#' @param data Dataset data frame.
#' @param rules Optional rule overrides accepted by the common validation engine.
#' @param export_path Optional CSV path for result rows.
#' @return Structured validation results and summary.
#' @examples
#' validate_adam_adsl(data.frame())
#' @export
validate_adam_adsl <- function(data, rules = NULL, export_path = NULL) validate_dataset(data, "ADSL", rules, export_path)

#' Validate ADaM Adverse Events (ADAE)
#' @param data Dataset data frame.
#' @param rules Optional rule overrides accepted by the common validation engine.
#' @param export_path Optional CSV path for result rows.
#' @return Structured validation results and summary.
#' @examples
#' validate_adam_adae(data.frame())
#' @export
validate_adam_adae <- function(data, rules = NULL, export_path = NULL) validate_dataset(data, "ADAE", rules, export_path)

#' Validate ADaM Laboratory (ADLB)
#' @param data Dataset data frame.
#' @param rules Optional rule overrides accepted by the common validation engine.
#' @param export_path Optional CSV path for result rows.
#' @return Structured validation results and summary.
#' @examples
#' validate_adam_adlb(data.frame())
#' @export
validate_adam_adlb <- function(data, rules = NULL, export_path = NULL) validate_dataset(data, "ADLB", rules, export_path)