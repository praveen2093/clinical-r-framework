library(clinicalUtils)

# Fictional subject and laboratory examples.
adsl <- load_synthetic_dataset("ADSL")
adlb <- load_synthetic_dataset("ADLB")

adsl_validation <- validate_adam_adsl(adsl)
print(adsl_validation$summary)
print(adsl_validation$results[adsl_validation$results$status == "FAIL", ])

# Compare a candidate output with a separate reference object. The package does
# not write to or replace the reference.
reference_adlb <- adlb
candidate_adlb <- adlb
candidate_adlb$AVAL[1] <- candidate_adlb$AVAL[1] + 0.01
comparison <- compare_clinical_datasets(
  reference_adlb,
  candidate_adlb,
  key_vars = c("USUBJID", "PARAMCD", "AVISITN"),
  tolerance = 0.001,
  dataset_name = "ADLB"
)
print(comparison$summary)
print(comparison$modified)