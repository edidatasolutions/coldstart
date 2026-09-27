# Average Fisher information of one Rasch response about b, over a normal
# examinee population.
mean_info <- function(b, theta_mean, theta_sd, n_nodes = 201) {
  z <- stats::qnorm(stats::ppoints(n_nodes))
  th <- theta_mean + theta_sd * z
  vapply(b, function(bi) { p <- stats::plogis(th - bi); mean(p * (1 - p)) }, 0)
}

#' Plan pretest sample sizes for a target precision
#'
#' Uses the normal approximation `posterior precision = 1 / prior_sd^2 + n * I(b)`,
#' where `I(b)` is the average information of one response about the item's
#' difficulty in the pretest population, evaluated at the predicted
#' difficulty. Compares the responses needed with the predicted prior against
#' the conventional (no-prior) requirement `1 / (target_sd^2 * I(b))`.
#'
#' @param prior Output of `predict()` on a `cs_predictor`.
#' @param target_sd Desired posterior SD of each difficulty.
#' @param theta_mean,theta_sd Pretest population.
#' @return Data frame: `item`, `prior_sd`, `info`, `n_with_prior`,
#'   `n_without_prior`, `saved`.
#' @examples
#' sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
#' it <- sim$items; tr <- it$set == "train"
#' pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
#' pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
#' plan <- cs_plan(pred, target_sd = 0.3)
#' summary(plan[c("n_with_prior", "n_without_prior")])
#' @export
cs_plan <- function(prior, target_sd = 0.2, theta_mean = 0, theta_sd = 1) {
  info <- mean_info(prior$mean, theta_mean, theta_sd)
  n_prior <- ceiling(pmax(0, (1 / target_sd^2 - 1 / prior$sd^2) / info))
  n_flat <- ceiling(1 / (target_sd^2 * info))
  data.frame(item = prior$item, prior_sd = prior$sd, info = info,
             n_with_prior = n_prior, n_without_prior = n_flat,
             saved = n_flat - n_prior, stringsAsFactors = FALSE)
}
