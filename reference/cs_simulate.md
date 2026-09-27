# Simulate an item bank with features and known difficulties

Difficulty is \`b = X w + family effect + noise\`. Legacy (\`train\`)
items have calibrated difficulties from large samples (true value plus
\`legacy_se\` error). New generated items (\`new\`) come from the same
families plus one family never seen in training. Optionally, one seen
family is "rogue": its new items are \`rogue_shift\` harder than its
history implies, as when a generation template changes.

## Usage

``` r
cs_simulate(
  n_train = 400,
  n_new = 150,
  n_families = 10,
  n_features = 32,
  signal_sd = 0.8,
  family_sd = 0.4,
  resid_sd = 0.5,
  legacy_se = 0.1,
  rogue_shift = 1.2,
  seed = NULL
)
```

## Arguments

- n_train, n_new:

  Numbers of legacy and new items.

- n_families:

  Number of template families seen in training; one more family appears
  only among new items.

- n_features:

  Feature (embedding) dimension.

- signal_sd, family_sd, resid_sd:

  SDs of the feature signal, family effects and item-specific residual.

- legacy_se:

  Calibration error of legacy difficulties.

- rogue_shift:

  Shift for the rogue family's new items (0 for none).

- seed:

  Optional seed.

## Value

A \`cs_sim\`: \`\$items\` (\`item\`, \`family\`, \`set\`, \`b_true\`,
\`b_legacy\`, \`rogue\`) and \`\$features\` (matrix, rownames = item
ids).

## Examples

``` r
sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
table(sim$items$set, sim$items$rogue)
#>        
#>         FALSE TRUE
#>   new      51    9
#>   train   200    0
dim(sim$features)
#> [1] 260  32
```
