.regression_key <- function(data, keys) {
  columns <- lapply(data[keys], function(x) {
    value <- as.character(x)
    value[is.na(value)] <- "<NA>"
    paste0(nchar(value, type = "bytes"), ":", value)
  })
  do.call(paste, c(columns, sep = "|"))
}

.same_value <- function(reference, actual, tolerance) {
  missing_ref <- is.na(reference)
  missing_act <- is.na(actual)
  same_missing <- missing_ref & missing_act
  comparable <- !missing_ref & !missing_act
  same <- rep(FALSE, length(reference))
  same[same_missing] <- TRUE
  if (is.numeric(reference) && is.numeric(actual)) {
    same[comparable] <- abs(reference[comparable] - actual[comparable]) <= tolerance
  } else {
    same[comparable] <- as.character(reference[comparable]) == as.character(actual[comparable])
  }
  same
}

#' Compare clinical datasets by configurable record keys
#'
#' Comparison is independent of row order. Duplicate or missing key values are
#' rejected. Reference data are never modified or overwritten.
#'
#' @param reference Approved reference data frame; this function is read-only.
#' @param actual Actual data frame.
#' @param key_vars Character vector naming the composite record key.
#' @param tolerance Non-negative scalar absolute tolerance for numeric values.
#' @param dataset_name Optional dataset label included in the report.
#' @return A structured report containing a summary, structure comparison,
#'   added/removed records, modified values, unchanged count, and variable names
#'   with differences.
#' @examples
#' compare_clinical_datasets(data.frame(USUBJID = "S1", AVAL = 1),
#'   data.frame(USUBJID = "S1", AVAL = 1.01), "USUBJID", tolerance = 0.02)
#' @export
compare_clinical_datasets <- function(reference, actual, key_vars, tolerance = 0, dataset_name = "dataset") {
  if (!is.data.frame(reference) || !is.data.frame(actual)) stop("Both inputs must be data frames.", call. = FALSE)
  if (!is.character(key_vars) || !length(key_vars) || anyNA(key_vars)) stop("`key_vars` must be non-empty character names.", call. = FALSE)
  if (!is.numeric(tolerance) || length(tolerance) != 1L || is.na(tolerance) || !is.finite(tolerance) || tolerance < 0) {
    stop("`tolerance` must be one finite non-negative number.", call. = FALSE)
  }
  absent <- setdiff(key_vars, union(names(reference), names(actual)))
  if (length(absent) || !all(key_vars %in% names(reference)) || !all(key_vars %in% names(actual))) {
    stop("All key variables must exist in both datasets.", call. = FALSE)
  }
  if (anyNA(reference[key_vars]) || anyNA(actual[key_vars])) stop("Key values cannot be missing.", call. = FALSE)
  ref_keys <- .regression_key(reference, key_vars)
  act_keys <- .regression_key(actual, key_vars)
  if (anyDuplicated(ref_keys) || anyDuplicated(act_keys)) stop("Duplicate record keys detected.", call. = FALSE)

  added_idx <- which(!act_keys %in% ref_keys)
  removed_idx <- which(!ref_keys %in% act_keys)
  actual_for_ref <- match(ref_keys, act_keys)
  matched_ref <- which(!is.na(actual_for_ref))
  common_vars <- setdiff(intersect(names(reference), names(actual)), key_vars)
  differences <- list()
  missing_differences <- list()
  changed_keys <- character()
  for (variable in common_vars) {
    ref_values <- reference[[variable]][matched_ref]
    act_values <- actual[[variable]][actual_for_ref[matched_ref]]
    same <- .same_value(ref_values, act_values, tolerance)
    changed <- which(!same)
    missing_changed <- which(xor(is.na(ref_values), is.na(act_values)))
    if (length(missing_changed)) {
      missing_differences[[length(missing_differences) + 1L]] <- data.frame(
        record_key = ref_keys[matched_ref[missing_changed]], variable = variable,
        reference_value = as.character(ref_values[missing_changed]),
        actual_value = as.character(act_values[missing_changed]), stringsAsFactors = FALSE)
    }
    if (length(changed)) {
      changed_keys <- union(changed_keys, ref_keys[matched_ref[changed]])
      differences[[length(differences) + 1L]] <- data.frame(
        record_key = ref_keys[matched_ref[changed]], variable = variable,
        reference_value = as.character(ref_values[changed]), actual_value = as.character(act_values[changed]),
        stringsAsFactors = FALSE)
    }
  }
  modified_values <- if (length(differences)) do.call(rbind, differences) else
    data.frame(record_key = character(), variable = character(), reference_value = character(), actual_value = character())
  missing_value_differences <- if (length(missing_differences)) do.call(rbind, missing_differences) else
    data.frame(record_key = character(), variable = character(), reference_value = character(), actual_value = character())
  differing_vars <- unique(modified_values$variable)
  modified_keys <- intersect(ref_keys, changed_keys)
  unchanged_count <- length(matched_ref) - length(modified_keys)
  subject_var <- if ("USUBJID" %in% key_vars) "USUBJID" else key_vars[[1L]]
  subject_counts <- c(reference = length(unique(reference[[subject_var]])), actual = length(unique(actual[[subject_var]])))
  structure <- compare_dataset_structure(reference, actual)
  summary <- list(dataset_name = dataset_name, reference_count = nrow(reference), actual_count = nrow(actual),
    reference_unique_subjects = subject_counts[["reference"]], actual_unique_subjects = subject_counts[["actual"]],
    added_records = length(added_idx), removed_records = length(removed_idx), modified_records = length(modified_keys),
    unchanged_records = unchanged_count, variables_with_differences = differing_vars,
    status = if (!length(added_idx) && !length(removed_idx) && !length(modified_keys) && structure$identical_structure) "PASS" else "DIFFERENT")
  list(summary = summary, structure = structure,
    added = actual[added_idx, , drop = FALSE], removed = reference[removed_idx, , drop = FALSE],
    modified = modified_values, modified_record_keys = modified_keys,
    missing_value_differences = missing_value_differences,
    variables_with_differences = differing_vars)
}