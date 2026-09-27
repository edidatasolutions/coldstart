# Simulate pretest responses to new items

Simulate pretest responses to new items

## Usage

``` r
cs_responses(sim, n_per_item = 50, theta_mean = 0, theta_sd = 1, seed = NULL)
```

## Arguments

- sim:

  A \`cs_sim\`.

- n_per_item:

  Responses per new item (scalar, or vector named by item).

- theta_mean, theta_sd:

  Ability distribution of pretest examinees.

- seed:

  Optional seed.

## Value

Long data frame: \`item\`, \`theta\` (examinee ability, treated as known
from operational scoring), \`x\` (0/1).

## Examples

``` r
sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
resp <- cs_responses(sim, n_per_item = 30, seed = 2)
head(resp)
#>    item       theta x
#> 1 G0201 -0.89691455 1
#> 2 G0201  0.18484918 0
#> 3 G0201  1.58784533 1
#> 4 G0201 -1.13037567 0
#> 5 G0201 -0.08025176 1
#> 6 G0201  0.13242028 0
```
