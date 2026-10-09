# Multi-condition simulation for the coldstart manuscript.
# Factors: strength of the feature signal (signal SD 0.5, 0.8, 1.1 logits) x
# number of legacy items (150, 400) x rogue-template shift (0.6, 1.2 logits).
# Within each data set, pretest samples of 15, 25, 50, 100 and 200 responses
# per item. Progress is appended to condition_progress.log.
# Usage: Rscript inst/validation/condition_study.R [n_reps] [n_workers]
args <- commandArgs(trailingOnly = TRUE)
n_reps <- if (length(args) >= 1) as.integer(args[1]) else 50
n_workers <- if (length(args) >= 2) as.integer(args[2]) else max(1, parallel::detectCores() - 2)
out_dir <- if (dir.exists("inst/validation")) "inst/validation" else "."
log_file <- normalizePath(file.path(out_dir, "condition_progress.log"), mustWork = FALSE)
cat("", file = log_file)

design <- expand.grid(signal_sd = c(0.5, 0.8, 1.1), n_train = c(150, 400), rogue_shift = c(0.6, 1.2))
design$cell <- seq_len(nrow(design))
jobs <- merge(design, data.frame(rep = seq_len(n_reps)))
jobs$seed <- 130000 + jobs$cell * 1000 + jobs$rep

one_job <- function(j, log_file) {
  suppressPackageStartupMessages(library(coldstart))
  t0 <- Sys.time()
  sim <- cs_simulate(n_train = j$n_train, signal_sd = j$signal_sd, rogue_shift = j$rogue_shift, seed = j$seed)
  it <- sim$items; tr <- it$set == "train"; nw <- it[!tr, ]
  pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = j$seed)
  pred <- predict(pr, sim$features[!tr, ], nw$family)
  e <- nw$b_true - pred$mean
  grp <- ifelse(nw$rogue, "rogue", ifelse(nw$unseen_family, "unseen", "seen"))
  s <- grp == "seen"
  rows <- list()
  fam <- stats::setNames(nw$family, nw$item)
  rogue_fam <- unique(nw$family[nw$rogue]); seen_honest <- setdiff(pr$families, rogue_fam)
  pl <- cs_plan(pred, target_sd = 0.3)
  for (n in c(15, 25, 50, 100, 200)) {
    resp <- cs_responses(sim, n, seed = j$seed * 10 + n)
    cal <- cs_calibrate(resp, pred)
    chk <- cs_check(cal, fam)
    cal2 <- cs_calibrate(resp, cs_distrust(pred, chk))
    m <- match(cal$item, nw$item)
    rm <- function(v, g) { k <- grp[m] == g; sqrt(mean((v[k] - nw$b_true[m][k])^2)) }
    rows[[length(rows) + 1]] <- data.frame(j[c("cell", "signal_sd", "n_train", "rogue_shift", "rep", "seed")],
      n = n, stated_sd = mean(pred$sd[s]), pred_rmse = sqrt(mean(e[s]^2)),
      cover90 = mean(abs(e[s]) <= 1.645 * pred$sd[s]),
      seen_base = rm(cal$base_mean, "seen"), seen_prior = rm(cal$post_mean, "seen"),
      rogue_base = rm(cal$base_mean, "rogue"), rogue_prior = rm(cal$post_mean, "rogue"),
      rogue_check = rm(cal2$post_mean, "rogue"),
      rogue_flagged = as.numeric(!chk$trustworthy[chk$family == rogue_fam]),
      seen_fpr = mean(!chk$trustworthy[chk$family %in% seen_honest]),
      unseen_fpr = mean(!chk$trustworthy[!chk$family %in% pr$families]),
      plan_saving = 1 - stats::median(pl$n_with_prior[s]) / stats::median(pl$n_without_prior[s]))
  }
  cat(sprintf("%s cell %d rep %d done in %.0fs\n", format(Sys.time(), "%H:%M:%S"), j$cell, j$rep,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))), file = log_file, append = TRUE)
  do.call(rbind, rows)
}

t0 <- Sys.time()
cl <- parallel::makeCluster(n_workers)
invisible(parallel::clusterCall(cl, function(p) .libPaths(c(p, .libPaths())), .libPaths()[1]))
res <- do.call(rbind, parallel::parLapplyLB(cl, split(jobs, seq_len(nrow(jobs))), one_job, log_file = log_file))
parallel::stopCluster(cl)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
saveRDS(res, file.path(out_dir, "condition_results.rds"))
cat(sprintf("Conditions: %d | replications per condition: %d | %.1f minutes\n", nrow(design), n_reps, elapsed))
