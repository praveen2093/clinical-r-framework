# clinicalUtils

`clinicalUtils` is an internal R package for reusable clinical programming
derivations, configurable structural/data-quality checks, and key-based
regression comparison. All bundled clinical records are fictional and are
intended for software examples only.

The package provides useful checks for development workflows. It does **not**
claim complete CDISC conformance or regulatory compliance, and it does not
replace Pinnacle 21 or other approved validation tools.

## Objectives

- Keep common date, population, and analysis derivations consistent.
- Return validation findings as structured data suitable for review or export.
- Detect changes between approved reference datasets and actual outputs.
- Support testing with fictional, linked SDTM/ADaM-like examples.

## Features

- Age, treatment duration, baseline, treatment-emergent, and population flags.
- Date parsing, missing-value checks, duplicate identification, summaries, and
	structural comparison.
- Configurable validators for SDTM DM, AE, LB and ADaM ADSL, ADAE, ADLB.
- Key-based regression reports with numerical tolerance and added/removed/
	modified record details.
- Synthetic DM, AE, LB, EX, ADSL, ADAE, and ADLB CSV resources.

## Installation

From a local checkout, with R installed:

```r
install.packages(c("devtools", "roxygen2", "testthat"))
devtools::document()
devtools::install()
```

The package itself has no runtime dependencies outside base R and recommended
packages. In this Codespaces setup, the isolated environment is available as
`conda run -n clinical-r R`.

## Package architecture

- `R/derivations.R`: dates, age, duration, and subject population flags.
- `R/data-checks.R`: missing values, duplicates, summaries, and structure.
- `R/validation.R`: common configurable engine and six dataset validators.
- `R/regression.R`: row-order-independent comparisons using supplied keys.
- `inst/extdata/`: fictional CSV datasets with selected intentional defects.
- `tests/testthat/`: derivation, validation, regression, and fixture tests.
- `man/`: generated help pages; edit roxygen comments in `R/` instead.

## Function reference

- Dates and derivations: `as_clinical_date()`, `calculate_age()`,
	`treatment_duration()`, `derive_baseline_flag()`,
	`derive_treatment_emergent_flag()`, `derive_population_flags()`.
- General checks: `check_missing_values()`, `identify_duplicates()`,
	`summarize_clinical_dataset()`, `compare_dataset_structure()`.
- Validation: `validate_dataset()`, `validate_sdtm_dm()`,
	`validate_sdtm_ae()`, `validate_sdtm_lb()`, `validate_adam_adsl()`,
	`validate_adam_adae()`, `validate_adam_adlb()`.
- Regression and examples: `compare_clinical_datasets()`,
	`load_synthetic_dataset()`.

See `?clinicalUtils` and the generated function help for arguments, return
structures, input behavior, and executable examples.

## Usage examples

```r
library(clinicalUtils)

calculate_age("2000-06-15", "2024-06-15")
treatment_duration("2024-01-01", "2024-01-10", inclusive = TRUE)

adsl <- load_synthetic_dataset("ADSL")
validate_adam_adsl(adsl)$summary

adlb <- load_synthetic_dataset("ADLB")
compare_clinical_datasets(adlb, adlb, c("USUBJID", "PARAMCD", "AVISITN"))$summary
```

For detailed worked code, see [`inst/examples/clinical-workflow.R`](inst/examples/clinical-workflow.R).

## Synthetic clinical datasets

`load_synthetic_dataset()` loads any supported fixture by name. Subject IDs are
consistent across related files. Fixtures include selected missing values,
duplicate keys, malformed dates, unexpected categories, and boundary values so
the validation behavior can be demonstrated. These are intentionally imperfect
test inputs, not reference deliverables or real patient records.

## Unit testing

Run the full test suite from the package root:

```r
devtools::test()
```

The suite covers ordinary inputs, missing and invalid values, boundary dates,
empty structures, duplicate keys, type expectations, configurable rules, CSV
export, floating-point tolerance, and row reordering.

For a complete reviewer walkthrough, including manual checks for each exported
function and the bundled datasets, see [TESTING_GUIDE.md](TESTING_GUIDE.md).

## Input validation

Each validator returns a list with `results` and `summary`. Result rows include
`rule_id`, dataset and variable names, severity (`ERROR`, `WARNING`, `INFO`),
status, affected record count, description, and record identifiers. Override
schema fields or rule severity using the `rules` list. Example:

```r
result <- validate_sdtm_dm(dm,
	rules = list(ranges = list(AGE = c(0, 125)),
							 severity = list(CATVAL = "WARNING")),
	export_path = "dm-validation.csv")
result$summary
```

These are configurable structural/data-quality checks, not a complete
implementation of any CDISC standard.

## Regression testing

Supply a stable composite key for the dataset: `USUBJID` for ADSL,
`USUBJID + AESEQ` for ADAE, or `USUBJID + PARAMCD + AVISITN` for ADLB.
`compare_clinical_datasets()` reports structure/type differences, record counts,
unique subject counts, added and removed rows, changed values, missing-value
differences, and unchanged records. Numeric fields use an absolute tolerance.
The function is read-only and never updates reference data. Any approved
reference update remains an explicit external review process.

## Development

1. Edit implementation and roxygen comments under `R/`.
2. Regenerate help and exports with `devtools::document()`.
3. Run `devtools::test()` and `devtools::check()`.
4. Review reference dataset changes separately; do not overwrite approved
	 references as part of a comparison run.

The GitHub Actions workflow runs R CMD check on pushes and pull requests.
