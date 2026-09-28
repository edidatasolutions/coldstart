#' Which item families' predictions can be trusted?
#'
#' Compares each item's baseline (data-driven) estimate with its prediction,
#' using `conflict_z` from [cs_calibrate()]. For each family it reports the
#' mean z (bias direction), coverage of the nominal predictive interval, and a
#' chi-square test of `sum(z^2)`. Families with p below `alpha` are marked
#' untrustworthy: their predictions should not be used as priors until the
#' predictor is retrained on their calibrated items.
#'
#' @param calibration A `cs_calibration` computed with a prior.
#' @param family Family per item, named by item id (or a data frame with
#'   `item` and `family`).
#' @param level Nominal coverage level for the interval check.
#' @param alpha Significance level for flagging a family.
#' @return Data frame, one row per family: `family`, `n_items`, `mean_z`,
#'   `rms_z`, `coverage`, `p_value`, `trustworthy`.
#' @examples
#' sim <- cs_simulate(n_train = 150, n_new = 80, seed = 1)
#' it <- sim$items; tr <- it$set == "train"
#' pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
#' pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
#' cal <- cs_calibrate(cs_responses(sim, 60, seed = 2), pred)
#' cs_check(cal, setNames(it$family[!tr], it$item[!tr]))
#' unique(it$family[it$rogue])   # the family whose template drifted
#' @export
cs_check <- function(calibration, family, level = 0.9, alpha = 0.01) {
  if (all(is.na(calibration$conflict_z))) stop("Calibrate with a prior first.")
  if (is.data.frame(family)) family <- stats::setNames(family$family, family$item)
  fam <- family[calibration$item]
  if (anyNA(fam)) stop("Some calibrated items have no family.")
  zc <- stats::qnorm(1 - (1 - level) / 2)
  res <- lapply(split(calibration$conflict_z, fam), function(z) {
    k <- length(z)
    data.frame(n_items = k, mean_z = mean(z), rms_z = sqrt(mean(z^2)),
               coverage = mean(abs(z) <= zc),
               p_value = stats::pchisq(sum(z^2), k, lower.tail = FALSE))
  })
  out <- cbind(family = names(res), do.call(rbind, res), stringsAsFactors = FALSE)
  out$trustworthy <- out$p_value >= alpha
  rownames(out) <- NULL
  out[order(out$p_value), ]
}

#' Withdraw priors for untrustworthy families
#'
#' Replaces the predicted prior of every item in a family that failed
#' [cs_check()] with a vague prior (mean 0, SD `vague_sd`), so the final
#' calibration of those items rests on their responses alone. Recalibrate
#' with [cs_calibrate()] afterwards.
#'
#' Note that the check and the final calibration use the same responses. This
#' is an empirical-Bayes style decision; in simulation it restores
#' baseline-level accuracy for a drifted family while keeping the prior's
#' benefit elsewhere.
#'
#' @param prior Prior data frame from `predict()` on a `cs_predictor`.
#' @param check Output of [cs_check()].
#' @param vague_sd SD of the replacement prior.
#' @return `prior` with modified `mean`/`sd` for untrusted families and a
#'   `trusted` column.
#' @examples
#' sim <- cs_simulate(n_train = 150, n_new = 80, seed = 1)
#' it <- sim$items; tr <- it$set == "train"
#' pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
#' pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
#' resp <- cs_responses(sim, 60, seed = 2)
#' chk <- cs_check(cs_calibrate(resp, pred), setNames(it$family[!tr], it$item[!tr]))
#' final <- cs_calibrate(resp, cs_distrust(pred, chk))
#' head(final)
#' @export
cs_distrust <- function(prior, check, vague_sd = 3) {
  bad <- check$family[!check$trustworthy]
  prior$trusted <- !(prior$family %in% bad)
  prior$mean[!prior$trusted] <- 0
  prior$sd[!prior$trusted] <- vague_sd
  prior
}
