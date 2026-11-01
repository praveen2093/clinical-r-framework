# clinicalUtils Testing Guide

This guide is for reviewers testing `clinicalUtils` from a source checkout. It
covers environment setup, automated package tests, manual checks for each
exported function, validation of the included examples, regression comparisons,
and checks with reviewer-provided data.

All bundled records are fictional. Some example datasets deliberately contain
bad dates, duplicate keys, missing values, or unexpected categories. Those
findings are expected when testing validation; they are not package test
failures. Never put real patient information in issue reports or test fixtures.

## 1. What To Give Reviewers

Share the complete repository/source folder, not only the `R/` directory. It
must include `DESCRIPTION`, `NAMESPACE`, `R/`, `man/`, `tests/`, `inst/`, and
the README. Include this guide and `IMPLEMENTATION_REPORT.md` as review context.

Reviewers need:

- R 4.1 or later; R 4.3 or later is recommended.
- Internet access for the first installation of test/development packages.
- `devtools`, `roxygen2`, and `testthat` for the developer workflow.
- RStudio is optional. The commands below work in its Console or a terminal.

The package functions accept R data frames. They do not read SAS datasets or
transport files directly. Import data through the team's approved process, or
export fictional/test data to CSV first. Preserve column names and check that
numeric columns import as numeric. Do not send PHI to package maintainers.

## 2. Open the Package Root

Open the folder containing `DESCRIPTION` in RStudio, or change the R working
directory to that folder. Confirm that you are in the package root:

```r
getwd()
file.exists("DESCRIPTION")
list.files()
```

`file.exists("DESCRIPTION")` must return `TRUE`. In RStudio, run the following
commands in the Console. In a terminal, equivalent `Rscript -e` commands can be
used from the same directory.

## 3. Install Development Tools

Do this once per R library. These packages are for development and testing; the
package's runtime functions do not require `dplyr` or `data.table`.

```r
install.packages(c("devtools", "roxygen2", "testthat"))
```

Check the environment and package version:

```r
R.version.string
packageVersion("devtools")
packageVersion("testthat")
```

## 4. Run Automated Package Tests

From the package root, run:

```r
devtools::document()
devtools::test()
```

`devtools::document()` regenerates `NAMESPACE` and the help pages from roxygen
comments. Review any generated changes before accepting them. `devtools::test()`
runs all files in `tests/testthat/` and should finish with zero failures and zero
warnings.

To run a focused area while diagnosing an issue:

```r
devtools::test(filter = "derivations")
devtools::test(filter = "validation")
devtools::test(filter = "regression")
```

Run the full package check before sign-off:

```r
devtools::check()
```

The check builds and installs the package in a temporary library and checks
syntax, dependencies, documentation, examples, and tests. The desired ending is
`Status: OK`. Save the complete check output with the review notes.

## 5. Install and Load the Package

Install the checkout into the reviewer's R library and confirm it loads:

```r
devtools::install()
library(clinicalUtils)
packageVersion("clinicalUtils")
```

Alternatively, use development loading without installing:

```r
devtools::load_all()
```

Use one approach consistently during a review. `devtools::load_all()` loads the
current source; `devtools::install()` tests the installed package experience.

## 6. Manually Exercise Each Functionality

The following script uses short, known-answer examples. Run it in the R
Console after loading `clinicalUtils`; inspect the results and confirm the
`stopifnot()` checks complete without error.

### Dates, age, duration, and flags

```r
as_clinical_date(c("2024-01-01", "02JAN2024", "20240103"))
try(as_clinical_date("2024-02-30")) # Expected error: invalid date

stopifnot(identical(
  calculate_age(c("2000-06-15", "2000-06-15"),
                c("2024-06-14", "2024-06-15")),
  c(23L, 24L)
))

stopifnot(treatment_duration("2024-01-01", "2024-01-10") == 9)
stopifnot(treatment_duration("2024-01-01", "2024-01-10", inclusive = TRUE) == 10)

stopifnot(identical(
  derive_baseline_flag(c("2024-01-01", "2024-01-02", NA), "2024-01-01"),
  c(TRUE, FALSE, NA)
))
stopifnot(identical(
  derive_treatment_emergent_flag(
    c("2024-01-01", "2024-01-10", "2024-01-11"),
    "2024-01-01", "2024-01-10"
  ),
  c(FALSE, TRUE, FALSE)
))
```

The treatment-emergent convention implemented here is event start strictly
after first treatment and on or before treatment end. Confirm that convention
matches the study-specific derivation before using it.

### Subject population flags

```r
subjects <- data.frame(
  USUBJID = c("TEST-001", "TEST-002"),
  TRTSDT = c("2024-01-01", NA),
  RANDDT = c("2023-12-20", NA),
  EOSDT = c("2024-03-01", NA)
)
flagged <- derive_population_flags(subjects, completion_date = "EOSDT")
flagged[c("USUBJID", "SAFFL", "RANDFL", "ITTFL", "COMPLFL")]
stopifnot(identical(flagged$SAFFL, c("Y", "N")))
```

### General data checks

```r
toy <- data.frame(USUBJID = c("TEST-001", "TEST-001", "TEST-002"),
                  VALUE = c(10, NA, 12))
check_missing_values(toy)
identify_duplicates(toy, keys = "USUBJID")
summarize_clinical_dataset(toy)
compare_dataset_structure(toy, toy)
```

Confirm that the missing-value result identifies one missing `VALUE`, the
duplicate result returns both `TEST-001` rows, the summary reports three rows
and two subjects, and comparing `toy` with itself reports identical structure.

## 7. Test All Included Dataset Validators

Load the bundled fictional CSV files and run each supported validator:

```r
dm <- load_synthetic_dataset("DM")
ae <- load_synthetic_dataset("AE")
lb <- load_synthetic_dataset("LB")
adsl <- load_synthetic_dataset("ADSL")
adae <- load_synthetic_dataset("ADAE")
adlb <- load_synthetic_dataset("ADLB")

validation <- list(
  DM = validate_sdtm_dm(dm),
  AE = validate_sdtm_ae(ae),
  LB = validate_sdtm_lb(lb),
  ADSL = validate_adam_adsl(adsl),
  ADAE = validate_adam_adae(adae),
  ADLB = validate_adam_adlb(adlb)
)

lapply(validation, `[[`, "summary")
lapply(validation, function(x) x$results[x$results$status == "FAIL", ])
```

Review both `summary` and the failed rows. DM contains a malformed date; AE
contains a duplicate key, malformed date, and unexpected severity; LB and ADLB
contain a malformed date. Those findings demonstrate detection and are
intentional. The ADSL fixture is expected to pass its configured rules.

Inspect the result columns and export a result table:

```r
names(validation$DM$results)
write.csv(validation$DM$results, "dm-validation-review.csv", row.names = FALSE)
```

The result includes rule ID, dataset and variable, severity, status, affected
record count, description, and record identifiers. Delete or retain the output
according to the review team's file-handling process.

Try a configurable rule override on a copy or fixture:

```r
validate_sdtm_dm(
  dm,
  rules = list(
    ranges = list(AGE = c(0, 125)),
    severity = list(CATVAL = "WARNING")
  )
)
```

Confirm that the configured age range and severity are reflected in the result.
Only use rule changes approved for the study's specification.

## 8. Test Regression Comparisons

Start with the included ADaM datasets as both reference and actual. These are
demonstration fixtures, not approved study references:

```r
adsl_ref <- load_synthetic_dataset("ADSL")
adsl_reordered <- adsl_ref[nrow(adsl_ref):1, ]
compare_clinical_datasets(adsl_ref, adsl_reordered, key_vars = "USUBJID")$summary

adae_ref <- load_synthetic_dataset("ADAE")
compare_clinical_datasets(
  adae_ref, adae_ref, key_vars = c("USUBJID", "AESEQ")
)$summary

adlb_ref <- load_synthetic_dataset("ADLB")
compare_clinical_datasets(
  adlb_ref, adlb_ref,
  key_vars = c("USUBJID", "PARAMCD", "AVISITN")
)$summary
```

The self-comparisons and row-reordered ADSL comparison should report `PASS`.
Now test tolerance and a changed value:

```r
adlb_actual <- adlb_ref
adlb_actual$AVAL[1] <- adlb_actual$AVAL[1] + 0.01

within_tolerance <- compare_clinical_datasets(
  adlb_ref, adlb_actual, c("USUBJID", "PARAMCD", "AVISITN"), tolerance = 0.02
)
outside_tolerance <- compare_clinical_datasets(
  adlb_ref, adlb_actual, c("USUBJID", "PARAMCD", "AVISITN"), tolerance = 0.001
)
within_tolerance$summary
outside_tolerance$modified
```

The first comparison should have zero modified records; the second should
identify `AVAL` as changed. Also try `adlb_actual <- adlb_ref[-1, ]` to verify
one removed record. To test an added record, copy a row, assign a new
`USUBJID` such as `TEST-999`, append it with `rbind()`, and verify one added
record. Missing or duplicate keys should produce an explicit error. The
comparison function never modifies the reference object.

## 9. Try Reviewer-Provided Data

Use only approved, non-sensitive test data. These validators expect the listed
dataset-specific columns and key conventions:

| Dataset | Validator | Key used by default | Example comparison key |
| --- | --- | --- | --- |
| SDTM DM | `validate_sdtm_dm()` | `USUBJID` | `USUBJID` |
| SDTM AE | `validate_sdtm_ae()` | `USUBJID + AESEQ` | `USUBJID + AESEQ` |
| SDTM LB | `validate_sdtm_lb()` | `USUBJID + LBSEQ` | `USUBJID + LBSEQ` |
| ADaM ADSL | `validate_adam_adsl()` | `USUBJID` | `USUBJID` |
| ADaM ADAE | `validate_adam_adae()` | `USUBJID + AESEQ` | `USUBJID + AESEQ` |
| ADaM ADLB | `validate_adam_adlb()` | `USUBJID + PARAMCD + AVISITN` | `USUBJID + PARAMCD + AVISITN` |

For a CSV test file:

```r
review_data <- read.csv(
  "path/to/non-sensitive-test-data.csv",
  stringsAsFactors = FALSE,
  na.strings = c("", "NA"),
  check.names = FALSE
)
```

First confirm `str(review_data)` and `names(review_data)`. A numeric field
imported as character will intentionally trigger a type finding; fix the test
input or use an approved rule/schema adjustment rather than silently coercing
production data. Compare a separate candidate data frame against a separately
retained reference. Never use a comparison run to overwrite an approved
reference.

The validators are intentionally limited configurable checks. A passing result
means only that the configured checks passed; it is not evidence of full CDISC
conformance or regulatory approval.

## 10. Reviewer Sign-Off Checklist

- Record R version, operating system, and package version.
- Confirm `devtools::document()` and the full `devtools::test()` pass.
- Confirm `devtools::check()` ends with `Status: OK`.
- Run the manual derivation examples and confirm their expected values.
- Run all six validators and inspect the expected intentional fixture findings.
- Run ADSL, ADAE, and ADLB regression comparisons and confirm row-order handling.
- Record any differences between expected and observed behavior, including the
  smallest fictional input that reproduces the issue.
- Keep reference-data approval and study-specific rule approval outside this
  package's automated comparison process.