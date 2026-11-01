test_that("SDTM and ADaM validators return structured result rows", {
  clean_dm <- data.frame(STUDYID = "S", USUBJID = "S-1", SUBJID = "1", SITEID = "10", AGE = 40,
    SEX = "F", RACE = "WHITE", ARM = "A", ACTARM = "A", RFSTDTC = "2024-01-01", RFENDTC = "2024-02-01")
  result <- validate_sdtm_dm(clean_dm)
  expect_true(result$summary$valid)
  expect_true(all(c("rule_id", "dataset_name", "variable_name", "severity", "status", "affected_records", "description", "record_ids") %in% names(result$results)))
  bad <- clean_dm
  bad$USUBJID <- ""
  bad$SEX <- "X"
  bad$RFSTDTC <- "2024-02-30"
  bad$AGE <- 121
  issues <- validate_sdtm_dm(bad)$results
  expect_true(all(c("REQVAL", "SUBJID", "CATVAL", "DATEFMT", "NUMRNG") %in% issues$rule_id[issues$status == "FAIL"]))
  bad_type <- clean_dm
  bad_type$AGE <- "forty"
  expect_true(any(validate_sdtm_dm(bad_type)$results$rule_id == "DATATYPE" & validate_sdtm_dm(bad_type)$results$status == "FAIL"))
  expect_false(validate_sdtm_dm(data.frame())$summary$valid)
  expect_equal(validate_adam_adsl(data.frame())$summary$dataset_name, "ADSL")
  expect_equal(validate_sdtm_ae(data.frame())$summary$dataset_name, "AE")
  expect_equal(validate_sdtm_lb(data.frame())$summary$dataset_name, "LB")
  expect_equal(validate_adam_adae(data.frame())$summary$dataset_name, "ADAE")
  expect_equal(validate_adam_adlb(data.frame())$summary$dataset_name, "ADLB")
})

test_that("validation rules can be configured and exported", {
  data <- data.frame(STUDYID = "S", USUBJID = "S1", SUBJID = "1", SITEID = "1", AGE = 121,
    SEX = "X", RACE = "WHITE", ARM = "A", ACTARM = "A", RFSTDTC = "2024-01-01", RFENDTC = "2024-02-01")
  output <- tempfile(fileext = ".csv")
  result <- validate_sdtm_dm(data, rules = list(ranges = list(AGE = c(0, 130)), severity = list(CATVAL = "WARNING")), export_path = output)
  expect_true(file.exists(output))
  expect_false(any(result$results$rule_id == "NUMRNG" & result$results$status == "FAIL"))
  expect_true(any(result$results$severity[result$results$rule_id == "CATVAL"] == "WARNING"))
  expect_error(validate_dataset(data, "UNKNOWN"), "'arg' should be one of")
  unlink(output)
})