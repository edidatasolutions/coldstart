# coldstart

**Calibrate AI-generated items before you have the pretest seats to do it the
old way.**

Automatic item generation and LLM-assisted writing produce items faster than
pretesting can calibrate them. coldstart predicts each new item's difficulty
from its features, uses the prediction as a robust prior, finds the families
where prediction fails, and tells you how many responses each item needs.

```r
library(coldstart)

sim  <- cs_simulate(seed = 1)                     # legacy + new items with features
it   <- sim$items; tr <- it$set == "train"

pr   <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr])
pred <- predict(pr, sim$features[!tr, ], it$family[!tr])   # mean + honest SD

cs_plan(pred, target_sd = 0.3)                    # responses needed per item

resp <- cs_responses(sim, n_per_item = 25)        # or your pretest data
cal  <- cs_calibrate(resp, pred)                  # t-prior Bayes vs baseline
chk  <- cs_check(cal, setNames(it$family[!tr], it$item[!tr]))
cal  <- cs_calibrate(resp, cs_distrust(pred, chk))  # drop priors that failed
```

## Installation

From CRAN (once released):

```r
install.packages("coldstart")
```

Development version from GitHub:

```r
install.packages("pak")
pak::pak("edidatasolutions/coldstart")
```

Features can be anything numeric: embeddings from any text model, cognitive
attribute codes, content metadata. The package does not call a model itself.

## Design choices

- **Honest predictive SD, two kinds.** Out-of-fold RMSE for families seen in
  training, and leave-one-family-out RMSE for new templates.
- **Robust prior.** The default Student-t (df = 4) lets the data override a bad
  prediction instead of being dragged toward it.
- **Family-level trust check.** A chi-square test of prior-data conflict per
  family; `cs_distrust()` withdraws priors from failing families.

## Validation (known truth, 100 replications)

Predictive SDs are honest: stated 0.54 vs actual RMSE 0.53 (seen families),
0.68 vs 0.64 (unseen family); 90% intervals cover 90.8% and 90.2%.

RMSE of difficulty, seen families:

| responses per item | baseline | predicted prior |
|---|---|---|
| 15 | 0.69 | 0.41 |
| 25 | 0.52 | 0.36 |
| 50 | 0.35 | 0.29 |
| 100 | 0.24 | 0.22 |
| 200 | 0.17 | 0.16 |

With the prior, 25 responses do about what 50 do without it.

**Drifted ("rogue") template family** (+1.2 logits vs its history): the prior
alone hurts (0.63 vs 0.60 at n = 25). `cs_check` flags the family in 80% of
replications at n = 15, 94% at n = 25 and 98–100% at n ≥ 50, with 0.1–0.2
false family flags per replication. After `cs_distrust()`, RMSE is back at or
slightly below baseline (0.58 at n = 25).

**Planner:** a target posterior SD of 0.30 needs a median of 40 responses per
item with the prior vs 57 without; achieved SD 0.303, RMSE 0.301.

## Status

Done: `cs_simulate`, `cs_responses`, `cs_predictor` (+`predict`),
`cs_calibrate`, `cs_plan`, `cs_check`, `cs_distrust`. Next: 2PL
(discrimination priors), sequential updating as responses arrive, ability
uncertainty for pretest examinees (currently treated as known from
operational scoring), and non-linear predictors.

## Getting help and contributing

Questions and bug reports: https://github.com/edidatasolutions/coldstart/issues. See
[CONTRIBUTING.md](.github/CONTRIBUTING.md) for how to report problems, get
help, or contribute code.
