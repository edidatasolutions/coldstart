# Calibrating generated items with predicted priors

Automatic item generation produces items faster than pretesting can
calibrate them. coldstart predicts each new item’s difficulty from its
features, uses the prediction as a robust prior, and finds template
families where the prediction cannot be trusted.

## A bank with features

Legacy items have calibrated difficulties; new generated items have only
features (any numeric representation works, such as embeddings from any
text model or cognitive-attribute codes) and a template family. In the
simulation, one family’s template drifted, making its new items harder
than its history suggests.

``` r

library(coldstart)
sim <- cs_simulate(n_train = 400, n_new = 150, seed = 3)
it <- sim$items
tr <- it$set == "train"
table(it$set)
#> 
#>   new train 
#>   150   400
```

## Predict difficulty, with honest uncertainty

``` r

pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
pr
#> <cs_predictor> ridge, lambda = 1 | 400 legacy items | 10 families
#> predictive SD: 0.548 (seen family), 0.788 (unseen family)
#>   shared within family: 0.000 (seen), 0.559 (unseen)
pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
head(pred)
#>        item family       mean        sd sd_shared family_seen
#> G0401 G0401    F07  1.3051977 0.5480338 0.0000000        TRUE
#> G0402 G0402    F08 -1.8811880 0.5480338 0.0000000        TRUE
#> G0403 G0403    F11 -0.4888554 0.7876555 0.5589692       FALSE
#> G0404 G0404    F09 -0.5278875 0.5480338 0.0000000        TRUE
#> G0405 G0405    F06 -0.1683571 0.5480338 0.0000000        TRUE
#> G0406 G0406    F02 -0.4489074 0.5480338 0.0000000        TRUE
```

The predictive SD is estimated out of sample. It is larger for a family
never seen in training, because the family’s own effect is then unknown.

## How many pretest responses do we need?

``` r

plan <- cs_plan(pred, target_sd = 0.3)
summary(plan[c("n_with_prior", "n_without_prior")])
#>   n_with_prior   n_without_prior 
#>  Min.   :38.00   Min.   : 54.00  
#>  1st Qu.:39.00   1st Qu.: 55.00  
#>  Median :41.00   Median : 58.00  
#>  Mean   :46.24   Mean   : 64.15  
#>  3rd Qu.:48.75   3rd Qu.: 64.75  
#>  Max.   :94.00   Max.   :134.00
```

## Calibrate from a small pretest

``` r

resp <- cs_responses(sim, n_per_item = 25, seed = 4)
cal <- cs_calibrate(resp, pred)
truth <- it$b_true[match(cal$item, it$item)]
c(baseline = sqrt(mean((cal$base_mean - truth)^2)),
  with_prior = sqrt(mean((cal$post_mean - truth)^2)))
#>   baseline with_prior 
#>  0.5752105  0.3839569
```

## Which families can we trust?

A prediction is only as good as the family template it comes from. If a
template has drifted (the items are now harder or easier than the
features say), every item of that family is mispredicted in the same
direction.
[`cs_check()`](https://edidatasolutions.github.io/coldstart/reference/cs_check.md)
compares the pretest estimates with the predictions, family by family,
and flags families whose items conflict with their priors:

``` r

fam <- setNames(it$family[!tr], it$item[!tr])
chk <- cs_check(cs_calibrate(cs_responses(sim, 100, seed = 5), pred), fam)
chk
#>    family n_items      mean_z     rms_z  coverage      p_value trustworthy
#> 1     F01      13  1.91170195 2.2174671 0.3076923 1.033704e-08       FALSE
#> 9     F09      18  0.26358231 1.1677767 0.7777778 1.379219e-01        TRUE
#> 7     F07      10 -0.08620829 1.2031628 0.9000000 1.523653e-01        TRUE
#> 6     F06      19 -0.03607136 1.0696458 0.8947368 2.974532e-01        TRUE
#> 4     F04       7  0.23966538 1.0288285 0.8571429 3.875306e-01        TRUE
#> 3     F03      12  0.19518559 1.0150236 0.8333333 4.169631e-01        TRUE
#> 8     F08      13  0.23874499 1.0076796 0.8461538 4.324513e-01        TRUE
#> 11    F11      19 -0.31884214 0.7773376 1.0000000 5.212788e-01        TRUE
#> 2     F02       9 -0.10144038 0.8624153 0.8888889 6.689603e-01        TRUE
#> 5     F05      15  0.32898050 0.8516693 0.9333333 7.610460e-01        TRUE
#> 10    F10      15 -0.08314448 0.7429080 1.0000000 9.121243e-01        TRUE
unique(it$family[it$rogue])
#> [1] "F01"
```

The drifted family is flagged. The family that never appeared in
training is not, even though its predictions are the least certain.

Priors for families that fail the check are withdrawn before the final
calibration:

``` r

resp100 <- cs_responses(sim, 100, seed = 5)
final <- cs_calibrate(resp100, cs_distrust(pred, chk))
head(final[c("item", "n", "post_mean", "post_sd")])
#>    item   n  post_mean   post_sd
#> 1 G0401 100  0.7082320 0.2175301
#> 2 G0402 100 -1.3150924 0.2362350
#> 3 G0403 100 -1.1280780 0.2314078
#> 4 G0404 100  0.6417285 0.2345004
#> 5 G0405 100 -0.7933419 0.2231148
#> 6 G0406 100 -0.6901677 0.2011189
```

### Items of a family share prediction error

Items of the same family do not err independently: they share the error
in the family’s estimated effect. For a family unseen in training, the
whole family effect is unknown, so all of its items are off by the same
unknown amount. [`predict()`](https://rdrr.io/r/stats/predict.html)
reports this shared part as `sd_shared`, alongside each item’s total
predictive SD:

``` r

unique(pred[c("family_seen", "sd", "sd_shared")])
#>       family_seen        sd sd_shared
#> G0401        TRUE 0.5480338 0.0000000
#> G0403       FALSE 0.7876555 0.5589692
```

Since version 0.2.0,
[`cs_check()`](https://edidatasolutions.github.io/coldstart/reference/cs_check.md)
tests each family’s conflicts under this correlation. Version 0.1.0
treated the items as independent, so a new family whose effect happened
to sit away from the average could fail the check merely for being new,
even when its predictions were as honest as they claimed. The difference
is easy to see on a bank where that happens. Setting `prior_sd_shared`
to zero reproduces the old, independent test:

``` r

sim2 <- cs_simulate(n_train = 400, n_new = 150, seed = 110)
it2 <- sim2$items; tr2 <- it2$set == "train"
pr2 <- cs_predictor(it2$b_legacy[tr2], sim2$features[tr2, ], it2$family[tr2], seed = 10)
pred2 <- predict(pr2, sim2$features[!tr2, ], it2$family[!tr2])
cal2 <- cs_calibrate(cs_responses(sim2, 100, seed = 10), pred2)
fam2 <- setNames(it2$family[!tr2], it2$item[!tr2])
c(unseen = unique(it2$family[it2$unseen_family]), drifted = unique(it2$family[it2$rogue]))
#>  unseen drifted 
#>   "F11"   "F01"

correlated <- cs_check(cal2, fam2)
independent <- cs_check(transform(cal2, prior_sd_shared = 0), fam2)
correlated[!correlated$trustworthy, c("family", "n_items", "mean_z", "p_value")]
#>   family n_items   mean_z      p_value
#> 1    F01      18 1.550548 2.661835e-07
independent[!independent$trustworthy, c("family", "n_items", "mean_z", "p_value")]
#>    family n_items    mean_z      p_value
#> 1     F01      18  1.550548 2.661835e-07
#> 11    F11      18 -1.309219 3.501922e-03
```

Both tests flag the drifted family. Only the independent test also flags
the new family, whose items sit on average 1.3 SD below their
predictions: the kind of common shift that `sd_shared` says to expect
for a new family. In the package’s simulations, this correction lowered
the rate at which the unseen family was falsely flagged from 3.5–7% to
about 1% (at `alpha = 0.01`), while the drifted family was still
detected. See
[`?cs_check`](https://edidatasolutions.github.io/coldstart/reference/cs_check.md)
for the test.
