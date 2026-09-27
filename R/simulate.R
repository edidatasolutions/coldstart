#' Simulate an item bank with features and known difficulties
#'
#' Difficulty is `b = X w + family effect + noise`. Legacy (`train`) items
#' have calibrated difficulties from large samples (true value plus
#' `legacy_se` error). New generated items (`new`) come from the same families
#' plus one family never seen in training. Optionally, one seen family is
#' "rogue": its new items are `rogue_shift` harder than its history implies,
#' as when a generation template changes.
#'
#' @param n_train,n_new Numbers of legacy and new items.
#' @param n_families Number of template families seen in training; one more
#'   family appears only among new items.
#' @param n_features Feature (embedding) dimension.
#' @param signal_sd,family_sd,resid_sd SDs of the feature signal, family
#'   effects and item-specific residual.
#' @param legacy_se Calibration error of legacy difficulties.
#' @param rogue_shift Shift for the rogue family's new items (0 for none).
#' @param seed Optional seed.
#' @return A `cs_sim`: `$items` (`item`, `family`, `set`, `b_true`, `b_legacy`,
#'   `rogue`) and `$features` (matrix, rownames = item ids).
#' @examples
#' sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
#' table(sim$items$set, sim$items$rogue)
#' dim(sim$features)
#' @export
cs_simulate <- function(n_train = 400, n_new = 150, n_families = 10, n_features = 32,
                        signal_sd = 0.8, family_sd = 0.4, resid_sd = 0.5,
                        legacy_se = 0.1, rogue_shift = 1.2, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  fams <- sprintf("F%02d", seq_len(n_families + 1))
  unseen <- fams[n_families + 1]
  n <- n_train + n_new
  X <- matrix(stats::rnorm(n * n_features), n, n_features)
  w <- stats::rnorm(n_features)
  w <- w * signal_sd / sqrt(sum(w^2))
  fam_eff <- stats::setNames(stats::rnorm(length(fams), 0, family_sd), fams)
  family <- c(sample(fams[-length(fams)], n_train, replace = TRUE),
              sample(fams, n_new, replace = TRUE))
  set <- rep(c("train", "new"), c(n_train, n_new))
  rogue <- set == "new" & family == fams[1] & rogue_shift != 0
  b <- drop(X %*% w) + fam_eff[family] + stats::rnorm(n, 0, resid_sd) + rogue * rogue_shift
  ids <- sprintf("G%04d", seq_len(n))
  rownames(X) <- ids
  colnames(X) <- sprintf("e%02d", seq_len(n_features))
  items <- data.frame(item = ids, family = family, set = set, b_true = unname(b),
                      b_legacy = ifelse(set == "train", b + stats::rnorm(n, 0, legacy_se), NA),
                      rogue = rogue, unseen_family = family == unseen,
                      stringsAsFactors = FALSE)
  structure(list(items = items, features = X), class = "cs_sim")
}

#' Simulate pretest responses to new items
#'
#' @param sim A `cs_sim`.
#' @param n_per_item Responses per new item (scalar, or vector named by item).
#' @param theta_mean,theta_sd Ability distribution of pretest examinees.
#' @param seed Optional seed.
#' @return Long data frame: `item`, `theta` (examinee ability, treated as known
#'   from operational scoring), `x` (0/1).
#' @examples
#' sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
#' resp <- cs_responses(sim, n_per_item = 30, seed = 2)
#' head(resp)
#' @export
cs_responses <- function(sim, n_per_item = 50, theta_mean = 0, theta_sd = 1, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  it <- sim$items[sim$items$set == "new", ]
  n <- if (length(n_per_item) == 1) rep(n_per_item, nrow(it)) else n_per_item[it$item]
  item <- rep(it$item, n)
  theta <- stats::rnorm(length(item), theta_mean, theta_sd)
  b <- rep(it$b_true, n)
  data.frame(item = item, theta = theta,
             x = stats::rbinom(length(item), 1, stats::plogis(theta - b)),
             stringsAsFactors = FALSE)
}
