for (f in list.files("C:/Users/User/Documents/coldstart/R", full.names = TRUE)) source(f)
sim <- cs_simulate(seed = 3)
it <- sim$items; tr <- it$set == "train"; nw <- it[!tr, ]
pr <- cs_predictor(it$b_legacy[tr], sim$features[tr, ], it$family[tr], seed = 1)
print(pr)
pred <- predict(pr, sim$features[!tr, ], nw$family)
ok <- !nw$rogue & !nw$unseen_family
e <- nw$b_true - pred$mean
cat("pred RMSE seen non-rogue:", sqrt(mean(e[ok]^2)), " unseen:", sqrt(mean(e[nw$unseen_family]^2)),
    " rogue:", sqrt(mean(e[nw$rogue]^2)), "\n")
cat("90% coverage seen:", mean(abs(e[ok]) <= 1.645 * pred$sd[ok]),
    " unseen:", mean(abs(e[nw$unseen_family]) <= 1.645 * pred$sd[nw$unseen_family]), "\n")
for (n in c(25, 50, 100, 200)) {
  resp <- cs_responses(sim, n, seed = n)
  ct <- cs_calibrate(resp, pred)
  cn <- cs_calibrate(resp, pred, prior_df = Inf)
  bt <- nw$b_true[match(ct$item, nw$item)]
  rg <- nw$rogue[match(ct$item, nw$item)]
  rm <- function(v, s = TRUE) sqrt(mean((v[s] - bt[s])^2))
  cat(sprintf("n=%3d RMSE base %.3f | t-prior %.3f | normal-prior %.3f || rogue: base %.3f t %.3f normal %.3f | cover90(t) %.3f\n",
              n, rm(ct$base_mean), rm(ct$post_mean), rm(cn$post_mean),
              rm(ct$base_mean, rg), rm(ct$post_mean, rg), rm(cn$post_mean, rg),
              mean(abs(ct$post_mean - bt) <= 1.645 * ct$post_sd)))
  if (n == 100) print(cs_check(ct, stats::setNames(nw$family, nw$item)))
}
pl <- cs_plan(pred, target_sd = 0.25)
cat("plan: median n with prior", median(pl$n_with_prior), " without", median(pl$n_without_prior), "\n")
