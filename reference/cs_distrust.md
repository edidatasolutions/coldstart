# Withdraw priors for untrustworthy families

Replaces the predicted prior of every item in a family that failed
\[cs_check()\] with a vague prior (mean 0, SD \`vague_sd\`), so the
final calibration of those items rests on their responses alone.
Recalibrate with \[cs_calibrate()\] afterwards.

## Usage

``` r
cs_distrust(prior, check, vague_sd = 3)
```

## Arguments

- prior:

  Prior data frame from \`predict()\` on a \`cs_predictor\`.

- check:

  Output of \[cs_check()\].

- vague_sd:

  SD of the replacement prior.

## Value

\`prior\` with modified \`mean\`/\`sd\` for untrusted families and a
\`trusted\` column.

## Details

Note that the check and the final calibration use the same responses.
This is an empirical-Bayes style decision; in simulation it restores
baseline-level accuracy for a drifted family while keeping the prior's
benefit elsewhere.

## Examples

``` r
sim <- cs_simulate(n_train = 200, n_new = 150, seed = 1)
it <- sim$items; tr <- it$set == "train"
pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
resp <- cs_responses(sim, 100, seed = 2)
chk <- cs_check(cs_calibrate(resp, pred), setNames(it$family[!tr], it$item[!tr]))
final <- cs_calibrate(resp, cs_distrust(pred, chk))
head(final)
#>    item   n  post_mean   post_sd  base_mean   base_sd prior_mean  prior_sd
#> 1 G0201 100 -1.0633588 0.2176494 -0.9454320 0.2376415 -1.4339282 0.5905433
#> 2 G0202 100  0.4436820 0.1993020  0.3750020 0.2226421  0.6726528 0.5905433
#> 3 G0203 100  0.2709171 0.1943451  0.2814189 0.2216530  0.2325054 0.5905433
#> 4 G0204 100  0.4820017 0.1954671  0.4123021 0.2171822  0.7260537 0.5905433
#> 5 G0205 100  0.1508391 0.2206569  0.1520704 0.2215577  0.0000000 3.0000000
#> 6 G0206 100 -1.6181713 0.2428300 -1.4817934 0.2734298 -1.9260782 0.5905433
#>    conflict_z
#> 1  0.76739416
#> 2 -0.47162403
#> 3  0.07754556
#> 4 -0.49864089
#> 5  0.05055246
#> 6  0.68270346
```
