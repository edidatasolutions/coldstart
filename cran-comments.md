## Submission

This is an update of coldstart (0.1.0 -> 0.2.0).

It corrects the family-level trust check `cs_check()`. Prediction errors of
items in the same template family are correlated (they share the error of the
family's estimated effect), and version 0.1.0 treated them as independent. As
a result, an honest template family not seen in training was flagged at
3-7% instead of the nominal 1%. The check now uses the correlated quadratic
form; `predict()` returns the shared error SD as a new column `sd_shared`, and
`cs_calibrate()` carries it as `prior_sd_shared`. Existing calibrations without
the new column behave exactly as before. Details are in NEWS.md.

## Test environments

* Local: Windows 11, R 4.6.0
* win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes

* Timing of this update: this update corrects a statistical issue in
  `cs_check()` (an inflated false-flag rate for template families not seen in
  training), so I would prefer users not keep the 0.1.0 behavior longer than
  necessary.
* Words flagged as possibly misspelled, if any, are author names of cited
  references (Hoerl, Kennard, Mislevy, Sheehan, Wingersky), the Rasch model,
  and the technical term "embeddings" (numeric text representations).

## Reverse dependencies

There are no reverse dependencies.
