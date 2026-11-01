#' Check required values
#'
#' @param data Data frame to inspect.
#' @param variables Column names to check; defaults to all columns.
#' @return A data frame with variable names, missing counts, and row indices.
#' @examples
#' check_missing_values(data.frame(A = c(1, NA)))
#' @export
check_missing_values <- function(data, variables = names(data)) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  absent <- setdiff(variables, names(data))
  if (length(absent)) stop("Unknown variable(s): ", paste(absent, collapse = ", "), call. = FALSE)
  if (!length(variables)) return(data.frame(variable = character(), missing_count = integer(), row_indices = I(list())))
  do.call(rbind, lapply(variables, function(variable) {
    rows <- which(is.na(data[[variable]]) | (is.character(data[[variable]]) & !is.na(data[[variable]]) & trimws(data[[variable]]) == ""))
    data.frame(variable = variable, missing_count = length(rows), row_indices = I(list(rows)), stringsAsFactors = FALSE)
  }))
}

#' Identify duplicate records
#'
#' @param data Data frame to inspect.
#' @param keys Key columns; defaults to all columns.
#' @return A data frame containing duplicate rows and their one-based row indices.
#' @examples
#' identify_duplicates(data.frame(ID = c(1, 1)))
#' @export
identify_duplicates <- function(data, keys = names(data)) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  if (!length(keys) || any(!keys %in% names(data))) stop("`keys` must name existing columns.", call. = FALSE)
  duplicated_rows <- duplicated(data[keys]) | duplicated(data[keys], fromLast = TRUE)
  out <- data[duplicated_rows, , drop = FALSE]
  out$.row_index <- which(duplicated_rows)
  out
}

#' Summarize a clinical dataset
#'
#' @param data Data frame to summarize.
#' @param dataset_name Optional label for the dataset.
#' @param subject_variable Optional subject identifier column.
#' @return A list with dataset name, dimensions, variable classes, missing counts,
#'   and optional unique subject count.
#' @examples
#' summarize_clinical_dataset(data.frame(USUBJID = c("S1", "S1"), AGE = c(30, NA)))
#' @export
summarize_clinical_dataset <- function(data, dataset_name = "dataset", subject_variable = "USUBJID") {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  missing <- vapply(data, function(x) sum(is.na(x)), integer(1))
  subjects <- if (subject_variable %in% names(data)) length(unique(stats::na.omit(data[[subject_variable]]))) else NA_integer_
  list(dataset_name = dataset_name, rows = nrow(data), columns = ncol(data),
       variable_classes = vapply(data, function(x) paste(class(x), collapse = "/"), character(1)),
       missing_counts = missing, unique_subjects = subjects)
}

#' Compare two datasets structurally
#'
#' @param reference Reference data frame.
#' @param actual Actual data frame.
#' @return A list with structure, variable, and record-count differences.
#' @examples
#' compare_dataset_structure(data.frame(A = 1), data.frame(A = 2))
#' @export
compare_dataset_structure <- function(reference, actual) {
  if (!is.data.frame(reference) || !is.data.frame(actual)) stop("Both inputs must be data frames.", call. = FALSE)
  ref_names <- names(reference)
  act_names <- names(actual)
  common <- intersect(ref_names, act_names)
  type_mismatches <- common[!vapply(common, function(x) identical(typeof(reference[[x]]), typeof(actual[[x]])), logical(1))]
  list(reference_rows = nrow(reference), actual_rows = nrow(actual),
       added_variables = setdiff(act_names, ref_names), removed_variables = setdiff(ref_names, act_names),
       type_mismatches = type_mismatches,
       identical_structure = identical(ref_names, act_names) && !length(type_mismatches))
}