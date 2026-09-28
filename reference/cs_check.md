# Which item families' predictions can be trusted?

Compares each item's baseline (data-driven) estimate with its
prediction, using \`conflict_z\` from \[cs_calibrate()\]. For each
family it reports the mean z (bias direction), coverage of the nominal
predictive interval, and a chi-square test of \`sum(z^2)\`. Families
with p below \`alpha\` are marked untrustworthy: their predictions
should not be used as priors until the predictor is retrained on their
calibrated items.

## Usage

``` r
cs_check(calibration, family, level = 0.9, alpha = 0.01)
```

## Arguments

- calibration:

  A \`cs_calibration\` computed with a prior.

- family:

  Family per item, named by item id (or a data frame with \`item\` and
  \`family\`).

- level:

  Nominal coverage level for the interval check.

- alpha:

  Significance level for flagging a family.

## Value

Data frame, one row per family: \`family\`, \`n_items\`, \`mean_z\`,
\`rms_z\`, \`coverage\`, \`p_value\`, \`trustworthy\`.

## Examples

``` r
sim <- cs_simulate(n_train = 150, n_new = 80, seed = 1)
it <- sim$items; tr <- it$set == "train"
pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
cal <- cs_calibrate(cs_responses(sim, 60, seed = 2), pred)
cs_check(cal, setNames(it$family[!tr], it$item[!tr]))
#>    family n_items      mean_z     rms_z  coverage      p_value trustworthy
#> 1     F01       9  1.77227828 1.9395947 0.4444444 9.457866e-05       FALSE
#> 3     F03       9 -0.79967649 1.4127883 0.5555556 3.559659e-02        TRUE
#> 11    F11       8 -0.18373104 1.3415233 0.6250000 7.197571e-02        TRUE
#> 7     F07       6 -0.44326387 1.1564061 0.8333333 2.363757e-01        TRUE
#> 8     F08       7 -0.02635903 1.0221057 0.8571429 3.970438e-01        TRUE
#> 6     F06       5 -0.09557271 0.9554180 1.0000000 4.713508e-01        TRUE
#> 5     F05       9  0.01575662 0.9512823 0.8888889 5.196581e-01        TRUE
#> 9     F09       6  0.21189431 0.8391296 1.0000000 6.462800e-01        TRUE
#> 4     F04       4 -0.39017450 0.4434799 1.0000000 9.402225e-01        TRUE
#> 10    F10       9 -0.16899443 0.5804733 1.0000000 9.629907e-01        TRUE
#> 2     F02       8 -0.21161508 0.5190458 1.0000000 9.758779e-01        TRUE
unique(it$family[it$rogue])   # the family whose template drifted
#> [1] "F01"
```
