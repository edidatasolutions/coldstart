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
sim <- cs_simulate(n_train = 200, n_new = 150, seed = 1)
it <- sim$items; tr <- it$set == "train"
pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
cal <- cs_calibrate(cs_responses(sim, 100, seed = 2), pred)
cs_check(cal, setNames(it$family[!tr], it$item[!tr]))
#>    family n_items       mean_z     rms_z  coverage      p_value trustworthy
#> 1     F01      11  1.965523955 2.1168579 0.3636364 8.387679e-07       FALSE
#> 6     F06      12  0.020919387 1.0127154 0.8333333 4.213412e-01        TRUE
#> 11    F11      21  0.201837572 0.9980973 0.9047619 4.638292e-01        TRUE
#> 7     F07      11  0.443387739 0.9667220 0.8181818 5.053849e-01        TRUE
#> 5     F05      17  0.002682395 0.9618727 1.0000000 5.431651e-01        TRUE
#> 3     F03      11 -0.149409274 0.9016813 0.8181818 6.271242e-01        TRUE
#> 9     F09      11 -0.192998465 0.8983771 1.0000000 6.331622e-01        TRUE
#> 8     F08      14 -0.019104431 0.9068066 1.0000000 6.454148e-01        TRUE
#> 2     F02      14 -0.339023802 0.9053541 0.8571429 6.483581e-01        TRUE
#> 10    F10      12  0.102655070 0.8839226 0.9166667 6.705383e-01        TRUE
#> 4     F04      16 -0.328533477 0.6908030 1.0000000 9.589885e-01        TRUE
unique(it$family[it$rogue])   # the family whose template drifted
#> [1] "F01"
```
