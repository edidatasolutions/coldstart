# Known-truth validation for coldstart, averaged over replications.
# 400 legacy items, 150 new generated items in 11 families (one unseen in
# training, one "rogue" whose template drifted +1.2 logits).
library(coldstart)

ns_per_item <- c(15, 25, 50, 100, 200)
reps <- 5
rows <- list(); fam_rows <- list(); cov_rows <- list(); plan_rows <- list()
for (rep in seq_len(reps)) {
  sim <- cs_simulate(seed = 100 + rep)
  it <- sim$items; tr <- it$set == "train"; nw <- it[!tr, ]
  pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = rep)
  pred <- predict(pr, sim$features[!tr, ], nw$family)
  e <- nw$b_true - pred$mean
  grp <- ifelse(nw$rogue, "rogue", ifelse(nw$unseen_family, "unseen", "seen"))
  for (gname in c("seen", "unseen")) {
    s <- grp == gname
    cov_rows[[length(cov_rows) + 1]] <- data.frame(
      group = gname, stated_sd = mean(pred$sd[s]), actual_rmse = sqrt(mean(e[s]^2)),
      cover90 = mean(abs(e[s]) <= 1.645 * pred$sd[s]))
  }
  fam <- stats::setNames(nw$family, nw$item)
  for (n in ns_per_item) {
    resp <- cs_responses(sim, n, seed = 1000 * rep + n)
    cal <- cs_calibrate(resp, pred)
    chk <- cs_check(cal, fam)
    cal2 <- cs_calibrate(resp, cs_distrust(pred, chk))
    m <- match(cal$item, nw$item)
    for (gname in c("seen", "rogue")) {
      s <- grp[m] == gname
      rm <- function(v) sqrt(mean((v[s] - nw$b_true[m][s])^2))
      rows[[length(rows) + 1]] <- data.frame(n = n, group = gname,
        baseline = rm(cal$base_mean), predicted_prior = rm(cal$post_mean),
        prior_then_check = rm(cal2$post_mean))
    }
    rogue_fam <- unique(nw$family[nw$rogue])
    fam_rows[[length(fam_rows) + 1]] <- data.frame(n = n,
      rogue_flagged = !chk$trustworthy[chk$family == rogue_fam],
      other_families_flagged = sum(!chk$trustworthy[chk$family != rogue_fam]))
  }
  pl <- cs_plan(pred, target_sd = 0.3)
  calp <- cs_calibrate(cs_responses(sim, stats::setNames(pmax(pl$n_with_prior, 1), pl$item),
                                    seed = rep), pred, prior_df = Inf)
  s <- grp == "seen"
  plan_rows[[length(plan_rows) + 1]] <- data.frame(
    median_n_with_prior = median(pl$n_with_prior[s]),
    median_n_without = median(pl$n_without_prior[s]),
    achieved_post_sd = mean(calp$post_sd[s]),
    achieved_rmse = sqrt(mean((calp$post_mean[s] - nw$b_true[s])^2)))
}
avg <- function(df, by) {
  out <- stats::aggregate(df[setdiff(names(df), by)], df[by], mean)
  out[order(out[[by[1]]]), ]
}
cat("Predictive uncertainty is honest (stated SD vs actual error):\n")
print(avg(do.call(rbind, cov_rows), "group"), digits = 3, row.names = FALSE)
cat("\nRMSE of difficulty by pretest n per item:\n")
print(avg(do.call(rbind, rows), c("group", "n")), digits = 3, row.names = FALSE)
cat("\nFamily check (share of replications / mean count):\n")
print(avg(do.call(rbind, fam_rows), "n"), digits = 3, row.names = FALSE)
cat("\nPlanner, target posterior SD 0.30 (seen families):\n")
print(colMeans(do.call(rbind, plan_rows)), digits = 3)
