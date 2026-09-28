#' Which item families' predictions can be trusted?
#'
#' Compares each item's baseline (data-driven) estimate with its prediction,
#' using `conflict_z` from [cs_calibrate()]. For each family it reports the
#' mean z (bias direction), coverage of the nominal predictive interval, and a
#' chi-square test of prior-data conflict. Families with p below `alpha` are
#' marked untrustworthy: their predictions should not be used as priors until
#' the predictor is retrained on their calibrated items.
#'
#' Prediction errors of items in the same family are correlated: they share
#' the error in the family's estimated effect, which for a family unseen in
#' training is its whole effect. The test statistic is the quadratic form of
#' the family's conflicts under that correlation (`prior_sd_shared`), which
#' is chi-square with one degree of freedom per item. Ignoring the
#' correlation flags new families far above `alpha` merely for being new.
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
  shared <- calibration$prior_sd_shared
  if (is.null(shared)) shared <- rep(0, nrow(calibration))
  d <- data.frame(z = calibration$conflict_z,
                  e = calibration$base_mean - calibration$prior_mean,
                  v = calibration$prior_sd^2 + calibration$base_sd^2,
                  t2 = ifelse(is.na(shared), 0, shared^2))
  res <- lapply(split(d, fam), function(g) {
    k <- nrow(g)
    # Cov(e) = diag(v - t2) + t2 * 11'; quadratic form by Sherman-Morrison.
    t2 <- min(g$t2[1], 0.99 * min(g$v))
    w <- 1 / (g$v - t2)
    q <- sum(w * g$e^2) - t2 * sum(w * g$e)^2 / (1 + t2 * sum(w))
    data.frame(n_items = k, mean_z = mean(g$z), rms_z = sqrt(mean(g$z^2)),
               coverage = mean(abs(g$z) <= zc),
               p_value = stats::pchisq(q, k, lower.tail = FALSE))
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
  if (!is.null(prior$sd_shared)) prior$sd_shared[!prior$trusted] <- 0
  prior
}
