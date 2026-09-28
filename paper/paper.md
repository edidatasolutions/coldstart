---
title: 'coldstart: Calibrating generated test items with predicted priors'
tags:
  - R
  - psychometrics
  - automatic item generation
  - Bayesian calibration
  - item response theory
authors:
  - name: Daniel Edi
    orcid: 0000-0001-5475-819X
    affiliation: 1
affiliations:
  - name: Independent Researcher
    index: 1
date: 27 September 2026
bibliography: paper.bib
---

<!-- DRAFT. Verify every reference and number before submission. Check the
journal's policy on disclosing AI-assisted software and writing. -->

# Summary

Automatic item generation [@gierl2013] and language-model-assisted item
writing produce items faster than programs can pretest them. `coldstart`
predicts each new item's Rasch difficulty from its features, using ridge
regression [@hoerl1970] on any numeric features such as text embeddings,
cognitive-attribute codes or template family. Its predictive uncertainty is
estimated out of sample, separately for template families seen in training
and for new families. The prediction becomes a robust Student-t prior for
grid-Bayes calibration from small pretest samples, extending the idea of
using collateral information in calibration [@mislevy1993]. The package also
plans the number of responses each item needs for a target precision, and
flags template families whose predictions fail so their priors can be
withdrawn.

# Statement of need

Pretest seats are scarce, especially for small certification programs, and
generated items arrive in large batches. General IRT software calibrates
items from response data alone, while research on predicting item parameters
seldom delivers calibrated uncertainty or a workflow that fails safely.
`coldstart` provides that workflow: honest prediction intervals, robust
priors, sample-size planning and family-level diagnostics.

# Validation

Across five known-truth replications, stated predictive standard deviations
matched realized error (0.54 vs 0.53 for seen families), and 90% intervals
covered 90.8%. With predicted priors, 25 responses per item gave the accuracy
of 50 responses without them (RMSE 0.35 vs 0.36). A template family whose
items drifted +1.2 logits was flagged in 80% of replications at 25 responses
per item and in all replications at 50 or more. Withdrawing its priors
restored baseline accuracy. The planner hit a target posterior SD of 0.30
(achieved 0.302) with 30% fewer responses.

# Acknowledgements

Software development and drafting were assisted by Claude (Anthropic). The author designed the methods, reviewed and validated all code and results, and takes full responsibility for the content.

# References
