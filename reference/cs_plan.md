# Plan pretest sample sizes for a target precision

Uses the normal approximation \`posterior precision = 1 / prior_sd^2 + n
\* I(b)\`, where \`I(b)\` is the average information of one response
about the item's difficulty in the pretest population, evaluated at the
predicted difficulty. Compares the responses needed with the predicted
prior against the conventional (no-prior) requirement \`1 / (target_sd^2
\* I(b))\`.

## Usage

``` r
cs_plan(prior, target_sd = 0.2, theta_mean = 0, theta_sd = 1)
```

## Arguments

- prior:

  Output of \`predict()\` on a \`cs_predictor\`.

- target_sd:

  Desired posterior SD of each difficulty.

- theta_mean, theta_sd:

  Pretest population.

## Value

Data frame: \`item\`, \`prior_sd\`, \`info\`, \`n_with_prior\`,
\`n_without_prior\`, \`saved\`.

## Examples

``` r
sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
it <- sim$items; tr <- it$set == "train"
pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
plan <- cs_plan(pred, target_sd = 0.3)
summary(plan[c("n_with_prior", "n_without_prior")])
#>   n_with_prior   n_without_prior
#>  Min.   :42.00   Min.   :54.00  
#>  1st Qu.:42.00   1st Qu.:55.00  
#>  Median :43.00   Median :56.00  
#>  Mean   :45.55   Mean   :59.03  
#>  3rd Qu.:45.50   3rd Qu.:58.25  
#>  Max.   :70.00   Max.   :86.00  
```
