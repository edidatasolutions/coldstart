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
sim <- cs_simulate(n_train = 150, n_new = 80, seed = 1)
it <- sim$items; tr <- it$set == "train"
pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
resp <- cs_responses(sim, 60, seed = 2)
chk <- cs_check(cs_calibrate(resp, pred), setNames(it$family[!tr], it$item[!tr]))
final <- cs_calibrate(resp, cs_distrust(pred, chk))
head(final)
#>    item  n   post_mean   post_sd   base_mean   base_sd prior_mean  prior_sd
#> 1 G0151 60  0.86147035 0.2612357  0.79608556 0.3021885  1.0196512 0.7165573
#> 2 G0152 60  0.03322728 0.2894111  0.03371001 0.2914284  0.0000000 3.0000000
#> 3 G0153 60  2.23272563 0.3995844  2.59588786 0.4481454  1.1769885 0.7165573
#> 4 G0154 60  0.78804294 0.3112882  0.56018572 0.2939417  2.2034264 0.6403500
#> 5 G0155 60 -1.22254429 0.3344952 -1.50442856 0.3498851 -0.1285612 0.6403500
#> 6 G0156 60  0.74295270 0.2372211  0.75492144 0.2802843  0.6999606 0.6403500
#>   prior_sd_shared  conflict_z
#> 1       0.4335412 -0.28748103
#> 2       0.0000000  0.01118402
#> 3       0.4335412  1.67886086
#> 4       0.0000000 -2.33218751
#> 5       0.0000000 -1.88551471
#> 6       0.0000000  0.07862723
```
