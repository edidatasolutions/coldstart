# Replication study for the coldstart manuscript: the design of known_truth.R
# over independent seeds (means with Monte Carlo SEs).
# Usage: Rscript inst/validation/replication_study.R [n_reps] [n_workers]
args <- commandArgs(trailingOnly = TRUE)
n_reps <- if (length(args) >= 1) as.integer(args[1]) else 100
n_workers <- if (length(args) >= 2) as.integer(args[2]) else max(1, parallel::detectCores() - 2)

one_rep <- function(seed) {
  suppressPackageStartupMessages(library(coldstart))
  sim <- cs_simulate(seed = seed)
  it <- sim$items; tr <- it$set == "train"; nw <- it[!tr, ]
  pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = seed)
  pred <- predict(pr, sim$features[!tr, ], nw$family)
  e <- nw$b_true - pred$mean
  grp <- ifelse(nw$rogue, "rogue", ifelse(nw$unseen_family, "unseen", "seen"))
  out <- list(seed = seed)
  for (g in c("seen", "unseen")) {
    s <- grp == g
    out[[paste0(g, "_stated_sd")]] <- mean(pred$sd[s])
    out[[paste0(g, "_rmse")]] <- sqrt(mean(e[s]^2))
    out[[paste0(g, "_cover90")]] <- mean(abs(e[s]) <= 1.645 * pred$sd[s])
  }
  fam <- stats::setNames(nw$family, nw$item)
  rogue_fam <- unique(nw$family[nw$rogue])
  for (n in c(15, 25, 50, 100, 200)) {
    resp <- cs_responses(sim, n, seed = seed * 10 + n)
    cal <- cs_calibrate(resp, pred)
    chk <- cs_check(cal, fam)
    cal2 <- cs_calibrate(resp, cs_distrust(pred, chk))
    m <- match(cal$item, nw$item)
    for (g in c("seen", "rogue")) {
      s <- grp[m] == g
      rm <- function(v) sqrt(mean((v[s] - nw$b_true[m][s])^2))
      out[[sprintf("n%d_%s_base", n, g)]] <- rm(cal$base_mean)
      out[[sprintf("n%d_%s_prior", n, g)]] <- rm(cal$post_mean)
      out[[sprintf("n%d_%s_check", n, g)]] <- rm(cal2$post_mean)
    }
    out[[sprintf("n%d_rogue_flagged", n)]] <- as.numeric(!chk$trustworthy[chk$family == rogue_fam])
    out[[sprintf("n%d_other_flags", n)]] <- sum(!chk$trustworthy[chk$family != rogue_fam])
    seen_honest <- setdiff(pr$families, rogue_fam)
    out[[sprintf("n%d_seen_fpr", n)]] <- mean(!chk$trustworthy[chk$family %in% seen_honest])
    out[[sprintf("n%d_unseen_fpr", n)]] <- mean(!chk$trustworthy[!chk$family %in% pr$families])
  }
  pl <- cs_plan(pred, target_sd = 0.3)
  calp <- cs_calibrate(cs_responses(sim, stats::setNames(pmax(pl$n_with_prior, 1), pl$item), seed = seed),
                       pred, prior_df = Inf)
  s <- grp == "seen"
  out$plan_n_prior <- stats::median(pl$n_with_prior[s])
  out$plan_n_flat <- stats::median(pl$n_without_prior[s])
  out$plan_post_sd <- mean(calp$post_sd[s])
  out$plan_rmse <- sqrt(mean((calp$post_mean[s] - nw$b_true[s])^2))
  as.data.frame(out)
}

t0 <- Sys.time()
cl <- parallel::makeCluster(n_workers)
invisible(parallel::clusterCall(cl, function(p) .libPaths(c(p, .libPaths())), .libPaths()[1]))
res <- do.call(rbind, parallel::parLapply(cl, 30000 + seq_len(n_reps), one_rep))
parallel::stopCluster(cl)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
out_dir <- if (dir.exists("inst/validation")) "inst/validation" else "."
saveRDS(res, file.path(out_dir, "replication_results.rds"))

mse <- function(v) { v <- v[!is.na(v)]; c(mean(v), stats::sd(v) / sqrt(length(v))) }
fmt <- function(v, d = 3) { m <- mse(v); sprintf(paste0("%.", d, "f (%.", d, "f)"), m[1], m[2]) }
cat(sprintf("Replications: %d | workers: %d | %.1f minutes\nValues: mean (Monte Carlo SE)\n\n", nrow(res), n_workers, elapsed))
for (g in c("seen", "unseen"))
  cat(sprintf("%-6s stated SD %s | actual RMSE %s | 90%% coverage %s\n", g,
              fmt(res[[paste0(g, "_stated_sd")]]), fmt(res[[paste0(g, "_rmse")]]), fmt(res[[paste0(g, "_cover90")]])))
cat("\nTable 1. RMSE of difficulty estimates\n")
t1 <- do.call(rbind, lapply(c(15, 25, 50, 100, 200), function(n) data.frame(
  n = n,
  seen_base = fmt(res[[sprintf("n%d_seen_base", n)]]), seen_prior = fmt(res[[sprintf("n%d_seen_prior", n)]]),
  rogue_base = fmt(res[[sprintf("n%d_rogue_base", n)]]), rogue_prior = fmt(res[[sprintf("n%d_rogue_prior", n)]]),
  rogue_check = fmt(res[[sprintf("n%d_rogue_check", n)]]),
  rogue_flagged = fmt(res[[sprintf("n%d_rogue_flagged", n)]], 2),
  other_flags = fmt(res[[sprintf("n%d_other_flags", n)]], 2))))
print(t1, row.names = FALSE, right = FALSE)
cat("\nFalse-flag rate per honest family (nominal 0.01): seen | unseen\n")
for (n in c(15, 25, 50, 100, 200))
  cat(sprintf("  n=%3d  %s | %s\n", n, fmt(res[[sprintf("n%d_seen_fpr", n)]], 4),
              fmt(res[[sprintf("n%d_unseen_fpr", n)]], 4)))
cat("\nPlanner (target SD 0.30): median n with prior", fmt(res$plan_n_prior, 1), "| without", fmt(res$plan_n_flat, 1),
    "| achieved SD", fmt(res$plan_post_sd), "| RMSE", fmt(res$plan_rmse), "\n")
