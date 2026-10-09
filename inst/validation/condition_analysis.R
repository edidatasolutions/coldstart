# Analysis of condition_study.R: condition means, eta-squared and figures.
# Usage: Rscript inst/validation/condition_analysis.R
dir <- if (dir.exists("inst/validation")) "inst/validation" else "."
res <- readRDS(file.path(dir, "condition_results.rds"))
fig_dir <- if (dir.exists("paper")) "paper/figures" else "figures"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
keys <- c("signal_sd", "n_train", "rogue_shift")
res$gain <- 1 - res$seen_prior / res$seen_base
res$rogue_rescue <- res$rogue_base - res$rogue_check
res$rogue_harm <- res$rogue_prior - res$rogue_base
cat(sprintf("Data sets: %d | replications per condition: %d\n\n", length(unique(res$seed)),
            length(unique(res$seed)) / nrow(unique(res[keys]))))
one <- res[res$n == 15, ]
cat("Predictive uncertainty (per data set, independent of n)\n")
print(format(stats::aggregate(one[c("stated_sd", "pred_rmse", "cover90", "plan_saving")], one[c("signal_sd", "n_train")], mean),
             digits = 3), row.names = FALSE)
cat("\nSeen-family RMSE reduction from priors, 1 - prior/baseline, by n\n")
print(round(stats::xtabs(gain ~ signal_sd + n_train + n, stats::aggregate(gain ~ signal_sd + n_train + n, res, mean)), 3))
cat("\nRogue family flagged, by shift and n (mean over other factors)\n")
print(round(stats::xtabs(rogue_flagged ~ rogue_shift + n, stats::aggregate(rogue_flagged ~ rogue_shift + n, res, mean)), 3))
cat("\nRogue RMSE: baseline / prior / after check, by shift and n\n")
print(format(stats::aggregate(res[c("rogue_base", "rogue_prior", "rogue_check")], res[c("rogue_shift", "n")], mean), digits = 3),
      row.names = FALSE)
cat("\nFalse-flag rate per honest family (nominal 0.01): seen / unseen, by n and signal\n")
print(format(stats::aggregate(res[c("seen_fpr", "unseen_fpr")], res[c("n", "signal_sd")], mean), digits = 3), row.names = FALSE)
cat("Pooled: seen", sprintf("%.4f", mean(res$seen_fpr)), "| unseen", sprintf("%.4f", mean(res$unseen_fpr)), "\n")

eta2 <- function(d, v, f) {
  d[f] <- lapply(d[f], factor)
  a <- stats::anova(stats::lm(stats::as.formula(paste(v, "~ (", paste(f, collapse = " + "), ")^2")), d))
  round(a[["Sum Sq"]] / sum(a[["Sum Sq"]]), 3) |> stats::setNames(rownames(a))
}
cat("\nEta-squared\n")
print(rbind(gain_n25 = eta2(res[res$n == 25, ], "gain", keys),
            rogue_flag_n25 = eta2(res[res$n == 25, ], "rogue_flagged", keys),
            cover90 = eta2(one, "cover90", keys), plan_saving = eta2(one, "plan_saving", keys)))

agg <- stats::aggregate(res[c("gain", "rogue_flagged", "seen_fpr", "unseen_fpr")], res[c(keys, "n")], mean)
ns <- c(15, 25, 50, 100, 200)
grDevices::png(file.path(fig_dir, "figure1_conditions.png"), width = 7, height = 3.4, units = "in", res = 300)
op <- graphics::par(mfrow = c(1, 2), mar = c(4, 4.4, 2, 0.5), cex = 0.85, cex.main = 0.95)
graphics::plot(NA, xlim = range(log(ns)), ylim = c(0, max(agg$gain) * 1.1), xaxt = "n", las = 1,
               xlab = "Responses per item", ylab = "RMSE reduction from priors", main = "(a) Benefit of predicted priors")
graphics::axis(1, at = log(ns), labels = ns)
i <- 0
for (sg in c(0.5, 0.8, 1.1)) for (nt in c(150, 400)) {
  i <- i + 1; s <- agg$signal_sd == sg & agg$n_train == nt
  g <- stats::aggregate(gain ~ n, agg[s, ], mean)
  graphics::lines(log(g$n), g$gain, type = "b", lwd = 1.4, lty = c(2, 1)[match(nt, c(150, 400))],
                  col = c("gray65", "gray40", "black")[match(sg, c(0.5, 0.8, 1.1))], pch = c(1, 16)[match(nt, c(150, 400))])
}
graphics::legend("topright", bty = "n", cex = 0.75, lwd = 1.4,
                 legend = c("signal SD 1.1", "signal SD 0.8", "signal SD 0.5", "400 legacy items", "150 legacy items"),
                 col = c("black", "gray40", "gray65", "black", "black"), lty = c(1, 1, 1, 1, 2), pch = c(NA, NA, NA, 16, 1))
graphics::plot(NA, xlim = range(log(ns)), ylim = c(0, 1), xaxt = "n", las = 1, xlab = "Responses per item",
               ylab = "Proportion of replications", main = "(b) Family check")
graphics::axis(1, at = log(ns), labels = ns)
for (sh in c(0.6, 1.2)) {
  g <- stats::aggregate(rogue_flagged ~ n, agg[agg$rogue_shift == sh, ], mean)
  graphics::lines(log(g$n), g$rogue_flagged, type = "b", lwd = 1.4, pch = c(1, 16)[match(sh, c(0.6, 1.2))])
}
g <- stats::aggregate(cbind(seen_fpr, unseen_fpr) ~ n, agg, mean)
graphics::lines(log(g$n), g$seen_fpr, type = "b", col = "gray50", pch = 2, lwd = 1.2)
graphics::lines(log(g$n), g$unseen_fpr, type = "b", col = "gray50", pch = 17, lty = 2, lwd = 1.2)
graphics::abline(h = 0.01, lty = 3, col = "gray60")
graphics::legend("right", bty = "n", cex = 0.75, legend = c("shift 1.2 detected", "shift 0.6 detected",
                 "false flag, seen", "false flag, unseen"), pch = c(16, 1, 2, 17), lty = c(1, 1, 1, 2),
                 col = c("black", "black", "gray50", "gray50"))
graphics::par(op); grDevices::dev.off()
cat("\nFigure written to", fig_dir, "\n")
