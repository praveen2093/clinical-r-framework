#' Load a fictional clinical example dataset
#'
#' The CSV fixtures contain invented records only. Some intentionally include
#' data-quality defects for demonstrations and should not be treated as clean
#' reference data.
#'
#' @param name One of `DM`, `AE`, `LB`, `EX`, `ADSL`, `ADAE`, or `ADLB`.
#' @return A data frame read from the package's synthetic CSV resource.
#' @examples
#' load_synthetic_dataset("ADSL")
#' @export
load_synthetic_dataset <- function(name) {
  name <- match.arg(name, c("DM", "AE", "LB", "EX", "ADSL", "ADAE", "ADLB"))
  path <- system.file("extdata", paste0(name, ".csv"), package = "clinicalUtils")
  if (!nzchar(path)) {
    path <- file.path("inst", "extdata", paste0(name, ".csv"))
    if (!file.exists(path)) stop("Synthetic dataset resource not found: ", name, call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA"), check.names = FALSE)
}