library(coldstart)
ns <- asNamespace("coldstart")

# 1. Building blocks -----------------------------------------------------------
g <- seq(-7, 7, by = 0.01)
for (df in c(4, 10, Inf)) {                       # prior sd means the same for t and normal
  w <- exp(ns$log_prior(g, 0.5, 0.8, df)); w <- w / sum(w)
  stopifnot(abs(sum(w * g) - 0.5) < 1e-3, abs(sqrt(sum(w * (g - 0.5)^2)) - 0.8) < 0.03)
}
stopifnot(abs(ns$mean_info(0, 0, 1e-6) - 0.25) < 1e-6)   # p = .5 gives 1/4

# Ridge matches lm when lambda -> 0
Z <- matrix(rnorm(200), 50); y <- drop(Z %*% c(1, -1, 0.5, 0)) + rnorm(50)
r <- ns$ridge(Z, y, 1e-10)
stopifnot(max(abs(r$coef - coef(lm(y ~ Z))[-1])) < 1e-6)

# 2. Predictor: honest uncertainty ------------------------------------------------
sim <- cs_simulate(n_train = 400, n_new = 200, seed = 5)
it <- sim$items; tr <- it$set == "train"; nw <- it[!tr, ]
pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
pred <- predict(pr, sim$features[!tr, ], nw$family)
ok <- !nw$rogue & !nw$unseen_family
e <- nw$b_true - pred$mean
stopifnot(pr$sigma_unseen > pr$sigma_seen,
          all(pred$sd[nw$unseen_family] == pr$sigma_unseen),
          abs(sqrt(mean(e[ok]^2)) - pr$sigma_seen) < 0.1,          # stated SD is honest
          abs(mean(abs(e[ok]) <= 1.645 * pred$sd[ok]) - 0.9) < 0.07)

# 3. Calibration: prior helps at small n; baseline agrees with truth at large n ---
resp <- cs_responses(sim, 30, seed = 2)
cal <- cs_calibrate(resp, pred)
bt <- nw$b_true[match(cal$item, nw$item)]
good <- !nw$rogue[match(cal$item, nw$item)]
rmse <- function(v, s) sqrt(mean((v[s] - bt[s])^2))
stopifnot(rmse(cal$post_mean, good) < 0.8 * rmse(cal$base_mean, good),
          # A t prior in conflict with the data can widen the posterior; that
          # is intended robustness, so only require narrowing without conflict.
          all(cal$post_sd[abs(cal$conflict_z) < 2] < cal$base_sd[abs(cal$conflict_z) < 2]))
big <- cs_calibrate(cs_responses(sim, 400, seed = 3))
stopifnot(rmse(big$base_mean, rep(TRUE, nrow(big))) < 0.15)

# 4. Family check flags the drifted template only ----------------------------------
fam <- stats::setNames(nw$family, nw$item)
cal100 <- cs_calibrate(cs_responses(sim, 100, seed = 4), pred)
chk <- cs_check(cal100, fam)
rogue_fam <- unique(nw$family[nw$rogue])
stopifnot(!chk$trustworthy[chk$family == rogue_fam],
          sum(!chk$trustworthy) == 1)
# ... and withdrawing its priors restores baseline accuracy for it
resp100 <- cs_responses(sim, 100, seed = 4)
cal_d <- cs_calibrate(resp100, cs_distrust(pred, chk))
rg <- nw$rogue[match(cal_d$item, nw$item)]
bt <- nw$b_true[match(cal_d$item, nw$item)]
stopifnot(rmse(cal_d$post_mean, rg) < 1.1 * rmse(cal_d$base_mean, rg))

# 5. Planner delivers the target precision -------------------------------------------
pl <- cs_plan(pred, target_sd = 0.3)
n_plan <- stats::setNames(pmax(pl$n_with_prior, 1), pl$item)
calp <- cs_calibrate(cs_responses(sim, n_plan, seed = 6), pred, prior_df = Inf)
sel <- pred$family_seen & !nw$rogue
stopifnot(abs(mean(calp$post_sd[sel]) - 0.3) < 0.03,
          all(pl$n_with_prior <= pl$n_without_prior))
cat("All coldstart tests passed.\n")
