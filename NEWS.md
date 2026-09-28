# coldstart (development version)

* `cs_check()` now accounts for prediction error shared by all items of a
  family (the unseen family's unknown effect, or the estimation error of a seen
  family's effect). `predict()` returns this as `sd_shared`, estimated from the
  cross-validation and leave-one-family-out residuals, and `cs_calibrate()`
  carries it as `prior_sd_shared`. Previously a family unseen in training was
  falsely flagged 3.5-6% of the time at alpha = 0.01; it is now flagged at
  about the nominal rate. Seen families, detection of drifted families and
  calibration accuracy are unchanged. Calibrations without the new column
  behave exactly as before.

# coldstart 0.1.0

* Initial release.
* Difficulty prediction from item features with honest seen/unseen-family uncertainty (`cs_predictor()`).
* Grid-Bayes calibration with robust Student-t predicted priors (`cs_calibrate()`).
* Pretest sample-size planning (`cs_plan()`).
* Family-level trust diagnostics and prior withdrawal (`cs_check()`, `cs_distrust()`).
