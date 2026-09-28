# Predict item difficulty from item features, with honest uncertainty

Ridge regression of calibrated difficulties on standardized features
plus template-family indicators, with the penalty chosen by
cross-validation. Predictive uncertainty is estimated out of sample,
separately for the two situations a new item can be in:

- seen family:

  RMSE of out-of-fold predictions under random K-fold CV.

- unseen family:

  RMSE under leave-one-family-out CV, where the held-out family's effect
  is unknown. This is usually much larger, and it is the honest number
  for a new template.

## Usage

``` r
cs_predictor(
  b,
  features,
  family = NULL,
  lambdas = 10^seq(-2, 3, length.out = 26),
  folds = 10,
  seed = NULL
)
```

## Arguments

- b:

  Calibrated difficulties of legacy items.

- features:

  Numeric matrix of item features (e.g. text embeddings from any model,
  cognitive-attribute codes), one row per legacy item.

- family:

  Optional template family / content code per item.

- lambdas:

  Candidate ridge penalties.

- folds:

  Number of CV folds.

- seed:

  Optional seed for fold assignment.

## Value

A \`cs_predictor\`.

## Examples

``` r
sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
it <- sim$items; tr <- it$set == "train"
pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
pr    # predictive SD for seen vs unseen template families
#> <cs_predictor> ridge, lambda = 6.31 | 200 legacy items | 10 families
#> predictive SD: 0.619 (seen family), 0.684 (unseen family)
#>   shared within family: 0.000 (seen), 0.327 (unseen)
```
