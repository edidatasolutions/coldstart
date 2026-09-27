softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

grid_summary <- function(logpost, grid) {
  w <- exp(logpost - max(logpost)); w <- w / sum(w)
  m <- sum(w * grid)
  c(mean = m, sd = sqrt(sum(w * (grid - m)^2)))
}

# Log prior density on the grid. The t prior is scaled so its variance equals
# sd^2, making "sd" mean the same thing for both families.
log_prior <- function(grid, mean, sd, df) {
  if (is.infinite(df)) return(stats::dnorm(grid, mean, sd, log = TRUE))
  s <- sd * sqrt((df - 2) / df)
  stats::dt((grid - mean) / s, df, log = TRUE)
}

#' Bayesian calibration of new items with predicted priors
#'
#' Grid posterior for each item's Rasch difficulty given pretest responses
#' from examinees with known ability (from operational scoring). Each item is
#' calibrated twice: with the predicted prior, and with a vague baseline prior
#' N(0, `baseline_sd`^2), which stands in for conventional calibration.
#'
#' The predicted prior is a Student-t with `prior_df` degrees of freedom by
#' default. When the prediction is badly wrong (e.g. a template changed), the
#' heavy tail lets the data override it instead of being dragged toward it.
#' `prior_df = Inf` gives a normal prior.
#'
#' @param responses Long data frame: `item`, `theta`, `x` (0/1).
#' @param prior Output of `predict()` on a `cs_predictor` (`item`, `mean`, `sd`),
#'   or `NULL` for baseline only.
#' @param prior_df Degrees of freedom of the t prior (> 2, or `Inf`).
#' @param baseline_sd SD of the vague baseline prior.
#' @param grid Difficulty grid.
#' @return A `cs_calibration` data frame: `item`, `n`, `post_mean`, `post_sd`,
#'   `base_mean`, `base_sd`, `prior_mean`, `prior_sd`, and `conflict_z`
#'   (baseline estimate vs prior, standardized by their combined SD: a
#'   prior-data conflict check).
#' @examples
#' sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
#' it <- sim$items; tr <- it$set == "train"
#' pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
#' pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
#' cal <- cs_calibrate(cs_responses(sim, 25, seed = 2), pred)
#' truth <- it$b_true[match(cal$item, it$item)]
#' c(baseline = sqrt(mean((cal$base_mean - truth)^2)),
#'   predicted_prior = sqrt(mean((cal$post_mean - truth)^2)))
#' @export
cs_calibrate <- function(responses, prior = NULL, prior_df = 4, baseline_sd = 3,
                         grid = seq(-7, 7, by = 0.02)) {
  if (!is.infinite(prior_df) && prior_df <= 2) stop("`prior_df` must exceed 2.")
  items <- unique(as.character(responses$item))
  if (!is.null(prior)) {
    miss <- setdiff(items, prior$item)
    if (length(miss)) stop("No prior for items: ", paste(miss[1:min(5, length(miss))], collapse = ", "))
  }
  by_item <- split(responses[c("theta", "x")], as.character(responses$item))
  out <- lapply(items, function(i) {
    d <- by_item[[i]]
    eta <- outer(d$theta, grid, "-")
    ll <- colSums(d$x * eta - softplus(eta))
    base <- grid_summary(ll + stats::dnorm(grid, 0, baseline_sd, log = TRUE), grid)
    row <- data.frame(item = i, n = nrow(d), post_mean = base[["mean"]], post_sd = base[["sd"]],
                      base_mean = base[["mean"]], base_sd = base[["sd"]],
                      prior_mean = NA_real_, prior_sd = NA_real_, conflict_z = NA_real_,
                      stringsAsFactors = FALSE)
    if (!is.null(prior)) {
      p <- prior[match(i, prior$item), ]
      post <- grid_summary(ll + log_prior(grid, p$mean, p$sd, prior_df), grid)
      row$post_mean <- post[["mean"]]; row$post_sd <- post[["sd"]]
      row$prior_mean <- p$mean; row$prior_sd <- p$sd
      row$conflict_z <- (base[["mean"]] - p$mean) / sqrt(p$sd^2 + base[["sd"]]^2)
    }
    row
  })
  structure(do.call(rbind, out), class = c("cs_calibration", "data.frame"),
            prior_df = prior_df)
}
