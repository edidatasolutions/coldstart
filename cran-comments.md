## Submission

This is the first submission of coldstart.

## Test environments

* Local: Windows 11, R 4.6.0
* GitHub Actions: macOS (release), Windows (release), Ubuntu (devel, release, oldrel-1)
* win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.
* Words flagged as possibly misspelled are author names of cited references
  (Hoerl, Kennard, Mislevy, Sheehan, Wingersky), the Rasch model, and the
  technical term "embeddings" (numeric text representations).

## Notes for the reviewer

* Item features can come from any source (e.g. text embeddings computed outside R); the package itself makes no network calls.
* Longer known-truth validation scripts are in `inst/validation/` and are not run during checks.
