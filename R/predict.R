#' Predict item difficulty from item features, with honest uncertainty
#'
#' Ridge regression of calibrated difficulties on standardized features plus
#' template-family indicators, with the penalty chosen by cross-validation.
#' Predictive uncertainty is estimated out of sample, separately for the two
#' situations a new item can be in:
#' \describe{
#'   \item{seen family}{RMSE of out-of-fold predictions under random K-fold CV.}
#'   \item{unseen family}{RMSE under leave-one-family-out CV, where the held-out
#'     family's effect is unknown. This is usually much larger, and it is the
#'     honest number for a new template.}
#' }
#' @param b Calibrated difficulties of legacy items.
#' @param features Numeric matrix of item features (e.g. text embeddings from
#'   any model, cognitive-attribute codes), one row per legacy item.
#' @param family Optional template family / content code per item.
#' @param lambdas Candidate ridge penalties.
#' @param folds Number of CV folds.
#' @param seed Optional seed for fold assignment.
#' @return A `cs_predictor`.
#' @examples
#' sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
#' it <- sim$items; tr <- it$set == "train"
#' pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
#' pr    # predictive SD for seen vs unseen template families
#' @export
cs_predictor <- function(b, features, family = NULL,
                         lambdas = 10^seq(-2, 3, length.out = 26), folds = 10, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  features <- as.matrix(features)
  if (nrow(features) != length(b)) stop("`features` must have one row per item.")
  if (anyNA(b) || anyNA(features)) stop("Missing values in `b` or `features`.")
  ctr <- colMeans(features)
  scl <- apply(features, 2, stats::sd); scl[scl == 0] <- 1
  fam_levels <- if (is.null(family)) character(0) else sort(unique(as.character(family)))
  Z <- design_matrix(features, family, ctr, scl, fam_levels)

  fold <- sample(rep_len(seq_len(folds), length(b)))
  cv_mse <- vapply(lambdas, function(l) mean(oof_pred(Z, b, fold, l)$err^2), 0)
  lambda <- lambdas[which.min(cv_mse)]
  sigma_seen <- sqrt(min(cv_mse))

  sigma_unseen <- sigma_seen
  shared_seen <- shared_unseen <- 0
  if (length(fam_levels) > 1) {
    shared_seen <- shared_sd(oof_pred(Z, b, fold, lambda)$err, family)
    # Leave-one-family-out: the held-out family's indicator column is all
    # zero in training, so its effect is shrunk to 0, exactly as for a new family.
    err_lofo <- oof_pred(Z, b, match(family, fam_levels), lambda)$err
    sigma_unseen <- sqrt(mean(err_lofo^2))
    shared_unseen <- shared_sd(err_lofo, family)
  }
  fit <- ridge(Z, b, lambda)
  structure(list(coef = fit$coef, intercept = fit$intercept, lambda = lambda,
                 center = ctr, scale = scl, families = fam_levels,
                 sigma_seen = sigma_seen, sigma_unseen = sigma_unseen,
                 shared_seen = min(shared_seen, 0.99 * sigma_seen),
                 shared_unseen = min(shared_unseen, 0.99 * sigma_unseen),
                 cv = data.frame(lambda = lambdas, rmse = sqrt(cv_mse)),
                 n_train = length(b)),
            class = "cs_predictor")
}

design_matrix <- function(features, family, ctr, scl, fam_levels) {
  Z <- sweep(sweep(as.matrix(features), 2, ctr), 2, scl, "/")
  if (length(fam_levels)) {
    D <- outer(as.character(family), fam_levels, "==") * 1
    colnames(D) <- paste0("family", fam_levels)
    Z <- cbind(Z, D)
  }
  Z
}

# SD of the prediction error shared by all items of a family, by method of
# moments on out-of-sample errors: E[family mean^2] = shared^2 + within^2 / n_f.
shared_sd <- function(err, family) {
  family <- as.character(family)
  m <- tapply(err, family, mean); n <- tapply(err, family, length)
  if (length(m) < 2 || length(err) <= length(m)) return(0)
  within2 <- sum((err - m[family])^2) / (length(err) - length(m))
  sqrt(max(0, mean(m^2 - within2 / n)))
}

ridge <- function(Z, y, lambda) {
  zc <- colMeans(Z); yc <- mean(y)
  Zc <- sweep(Z, 2, zc)
  coef <- drop(solve(crossprod(Zc) + diag(lambda, ncol(Z)), crossprod(Zc, y - yc)))
  list(coef = coef, intercept = yc - sum(zc * coef))
}

oof_pred <- function(Z, y, fold, lambda) {
  pred <- numeric(length(y))
  for (k in unique(fold)) {
    te <- fold == k
    f <- ridge(Z[!te, , drop = FALSE], y[!te], lambda)
    pred[te] <- f$intercept + drop(Z[te, , drop = FALSE] %*% f$coef)
  }
  list(pred = pred, err = y - pred)
}

#' Predicted difficulty and predictive SD for new items
#'
#' @param object A `cs_predictor`.
#' @param features Feature matrix for new items (same columns as training).
#' @param family Family per new item (families not seen in training get the
#'   larger unseen-family SD).
#' @param item Optional item ids (default: rownames of `features`).
#' @param ... Unused.
#' @return Data frame: `item`, `family`, `mean`, `sd`, `sd_shared`,
#'   `family_seen`. `sd` is each item's total predictive SD; `sd_shared` is
#'   the part of it shared by all items of the same family (for an unseen
#'   family, mostly its unknown family effect). [cs_check()] uses it so that
#'   a family is not flagged merely for the shared error its SD already allows.
#' @examples
#' sim <- cs_simulate(n_train = 200, n_new = 60, seed = 1)
#' it <- sim$items; tr <- it$set == "train"
#' pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
#' pred <- predict(pr, sim$features[!tr, ], it$family[!tr])
#' head(pred)
#' @export
predict.cs_predictor <- function(object, features, family = NULL, item = rownames(features), ...) {
  if (is.null(item)) item <- as.character(seq_len(nrow(features)))
  Z <- design_matrix(features, family, object$center, object$scale, object$families)
  seen <- if (length(object$families)) as.character(family) %in% object$families else
    rep(TRUE, nrow(Z))
  data.frame(item = item,
             family = if (is.null(family)) NA_character_ else as.character(family),
             mean = object$intercept + drop(Z %*% object$coef),
             sd = ifelse(seen, object$sigma_seen, object$sigma_unseen),
             sd_shared = ifelse(seen, if (is.null(object$shared_seen)) 0 else object$shared_seen,
                                if (is.null(object$shared_unseen)) 0 else object$shared_unseen),
             family_seen = seen, stringsAsFactors = FALSE)
}

#' @export
print.cs_predictor <- function(x, ...) {
  cat("<cs_predictor> ridge, lambda =", signif(x$lambda, 3), "|", x$n_train, "legacy items |",
      length(x$families), "families\n")
  cat(sprintf("predictive SD: %.3f (seen family), %.3f (unseen family)\n",
              x$sigma_seen, x$sigma_unseen))
  if (!is.null(x$shared_seen))
    cat(sprintf("  shared within family: %.3f (seen), %.3f (unseen)\n",
                x$shared_seen, x$shared_unseen))
  invisible(x)
}
