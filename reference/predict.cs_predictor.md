# Predicted difficulty and predictive SD for new items

Predicted difficulty and predictive SD for new items

## Usage

``` r
# S3 method for class 'cs_predictor'
predict(object, features, family = NULL, item = rownames(features), ...)
```

## Arguments

- object:

  A \`cs_predictor\`.

- features:

  Feature matrix for new items (same columns as training).

- family:

  Family per new item (families not seen in training get the larger
  unseen-family SD).

- item:

  Optional item ids (default: rownames of \`features\`).

- ...:

  Unused.

## Value

Data frame: \`item\`, \`family\`, \`mean\`, \`sd\`, \`family_seen\`.

## Examples

``` r
sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
it <- sim$items; tr <- it$set == "train"
pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
head(pred)
#>        item family       mean        sd family_seen
#> G0201 G0201    F01 -0.9760557 0.6186199        TRUE
#> G0202 G0202    F07  0.6804164 0.6186199        TRUE
#> G0203 G0203    F05 -0.5732907 0.6186199        TRUE
#> G0204 G0204    F09 -0.9805451 0.6186199        TRUE
#> G0205 G0205    F03 -0.2853529 0.6186199        TRUE
#> G0206 G0206    F05 -0.6911932 0.6186199        TRUE
```
