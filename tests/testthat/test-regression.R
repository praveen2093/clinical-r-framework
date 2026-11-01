test_that("regression comparison is key based, ordered, and tolerance aware", {
  reference <- data.frame(USUBJID = c("S1", "S2"), PARAMCD = "ALT", AVISITN = c(0, 1), AVAL = c(10, 12))
  reordered <- reference[2:1, ]
  expect_identical(compare_clinical_datasets(reference, reordered, c("USUBJID", "PARAMCD", "AVISITN"))$summary$status, "PASS")
  altered <- data.frame(USUBJID = c("S1", "S3"), PARAMCD = "ALT", AVISITN = c(0, 1), AVAL = c(10.01, 13))
  report <- compare_clinical_datasets(reference, altered, c("USUBJID", "PARAMCD", "AVISITN"), tolerance = 0.02)
  expect_equal(report$summary$added_records, 1L)
  expect_equal(report$summary$removed_records, 1L)
  expect_equal(report$summary$modified_records, 0L)
  altered$USUBJID[1] <- "S1"
  altered$AVISITN[1] <- 0
  altered$AVAL[1] <- 11
  changed <- compare_clinical_datasets(reference, altered, c("USUBJID", "PARAMCD", "AVISITN"))
  expect_true("AVAL" %in% changed$variables_with_differences)
  expect_equal(changed$summary$modified_records, 1L)
  expect_equal(nrow(changed$modified), 1L)
  missing_reference <- data.frame(USUBJID = "S1", AVAL = NA_real_)
  missing_actual <- data.frame(USUBJID = "S1", AVAL = 1)
  missing_report <- compare_clinical_datasets(missing_reference, missing_actual, "USUBJID")
  expect_equal(nrow(missing_report$missing_value_differences), 1L)
  literal_na <- data.frame(USUBJID = "S1", AVAL = "NA")
  literal_report <- compare_clinical_datasets(data.frame(USUBJID = "S1", AVAL = "1"), literal_na, "USUBJID")
  expect_equal(nrow(literal_report$missing_value_differences), 0L)
})

test_that("regression comparison rejects ambiguous keys and invalid tolerances", {
  duplicate <- data.frame(USUBJID = c("S1", "S1"), VALUE = c(1, 2))
  expect_error(compare_clinical_datasets(duplicate, duplicate, "USUBJID"), "Duplicate")
  expect_error(compare_clinical_datasets(data.frame(ID = 1), data.frame(ID = 1), "ID", tolerance = -1), "non-negative")
  expect_error(compare_clinical_datasets(data.frame(ID = NA), data.frame(ID = NA), "ID"), "cannot be missing")
})

test_that("synthetic resources load and remain fictional", {
  for (name in c("DM", "AE", "LB", "EX", "ADSL", "ADAE", "ADLB")) {
    expect_true(is.data.frame(load_synthetic_dataset(name)))
  }
})