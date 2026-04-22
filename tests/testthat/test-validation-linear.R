# CI-safe numeric-validation canary.
# Full 500-rep validation study lives under the parent
# bidirplot_dev/simulation/ workspace (out of package scope).
# This in-CI canary asserts: on a pure-linear DGP, both the
# asymmetry index and the recovered EDFs stay close to their
# theoretical floor.

test_that("asymmetry index near zero on pure-linear DGP", {
  set.seed(2026L)
  n  <- 200L
  x1 <- stats::rnorm(n)
  x2 <- 0.8 * x1 + stats::rnorm(n, sd = 0.5)
  x3 <- 0.5 * x1 + stats::rnorm(n, sd = 0.5)
  d  <- data.frame(x1 = x1, x2 = x2, x3 = x3)

  out <- janusplot_data(d)
  a   <- vapply(out$pairs, function(p) p$asymmetry_index, numeric(1L))

  # Cap deliberately generous — this is a canary, not a
  # methodological claim. REML smoothing-parameter bounce pushes
  # individual A values up to ~0.4 on finite samples even when the
  # DGP is exactly linear. The test asserts neither pair exceeds
  # 0.6 AND the mean sits below 0.4, which together catch a
  # genuine regression without false-alarming on REML noise.
  expect_true(
    all(a < 0.6) && mean(a) < 0.4,
    info = paste("asymmetry indices:", paste(round(a, 3), collapse = ", "))
  )
})

test_that("EDF recovers near 1 on linear DGP within REML bounce", {
  set.seed(2026L)
  n  <- 300L
  x1 <- stats::rnorm(n)
  x2 <- 1.5 * x1 + stats::rnorm(n, sd = 0.4)
  d  <- data.frame(x1 = x1, x2 = x2)

  out  <- janusplot_data(d)
  edfs <- c(out$pairs[[1L]]$edf_yx, out$pairs[[1L]]$edf_xy)

  expect_true(
    all(edfs < 1.5),
    info = paste("EDFs:", paste(round(edfs, 3), collapse = ", "))
  )
})
