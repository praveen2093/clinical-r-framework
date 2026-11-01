test_that("clinical dates parse supported formats and reject invalid values", {
  expect_identical(as_clinical_date(c("2024-01-01", "20240102")), as.Date(c("2024-01-01", "2024-01-02")))
  expect_true(is.na(as_clinical_date(NA_character_)))
  expect_error(as_clinical_date("2024-02-30"), "Invalid")
  expect_error(as_clinical_date(45200), "must be Date")
})

test_that("age uses completed years and validates boundaries", {
  expect_identical(calculate_age(c("2000-06-15", "2000-06-15"), c("2024-06-14", "2024-06-15")), c(23L, 24L))
  expect_true(is.na(calculate_age(NA_character_, "2024-01-01")))
  expect_error(calculate_age("2020-01-01", "2019-12-31"), "precedes")
  expect_error(calculate_age(c("2000-01-01", "2000-01-01"), c("2020-01-01", "2021-01-01", "2022-01-01")), "equal lengths")
})

test_that("duration and clinical flags cover boundaries and missingness", {
  expect_equal(treatment_duration("2024-01-01", "2024-01-10"), 9)
  expect_equal(treatment_duration("2024-01-01", "2024-01-10", inclusive = TRUE), 10)
  expect_true(is.na(treatment_duration(NA_character_, "2024-01-10")))
  expect_error(treatment_duration("2024-02-01", "2024-01-01"), "precedes")
  expect_identical(derive_baseline_flag(c("2024-01-01", "2024-01-02", NA), "2024-01-01"), c(TRUE, FALSE, NA))
  expect_identical(derive_treatment_emergent_flag(c("2024-01-01", "2024-01-10", "2024-01-11"), "2024-01-01", "2024-01-10"), c(FALSE, TRUE, FALSE))
})

test_that("population flags and generic data checks are reusable", {
  input <- data.frame(USUBJID = c("S1", "S2"), TRTSDT = c("2024-01-01", NA), RANDDT = c("2023-12-01", NA), EOSDT = c("2024-03-01", NA))
  result <- derive_population_flags(input, completion_date = "EOSDT")
  expect_identical(result$SAFFL, c("Y", "N"))
  expect_identical(result$ITTFL, c("Y", "N"))
  expect_identical(result$COMPLFL, c("Y", "N"))
  expect_equal(check_missing_values(data.frame(A = c(1, NA)))$missing_count, 1L)
  expect_equal(nrow(check_missing_values(data.frame())), 0L)
  expect_equal(nrow(identify_duplicates(data.frame(ID = c(1, 1, 2)))), 2L)
  expect_equal(summarize_clinical_dataset(input)$unique_subjects, 2L)
  expect_true(compare_dataset_structure(data.frame(A = 1), data.frame(A = 2))$identical_structure)
  expect_error(derive_population_flags(data.frame(TRTSDT = "x")), "Missing required")
})