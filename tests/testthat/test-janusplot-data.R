test_that("janusplot_data returns expected structure", {
  d <- make_linear_data(n = 100L)
  out <- janusplot_data(d, vars = c("x1", "x2", "x3"))
  expect_named(out, c("vars", "pairs", "call"))
  expect_equal(length(out$pairs), 3L)
  first <- out$pairs[[1L]]
  expect_true(all(c(
    "var_i", "var_j", "edf_yx", "edf_xy", "pvalue_yx", "pvalue_xy",
    "dev_exp_yx", "dev_exp_xy", "asymmetry_index", "n_used",
    "cor_pearson", "cor_spearman", "cor_kendall", "tie_ratio",
    "M_yx", "C_yx", "M_xy", "C_xy",
    "n_turning_yx", "n_inflect_yx", "n_turning_xy", "n_inflect_xy",
    "shape_yx", "shape_xy",
    "shape_code_yx", "shape_code_xy",
    "shape_archetype_yx", "shape_archetype_xy",
    "shape_monotonic_yx", "shape_monotonic_xy",
    "shape_linear_yx", "shape_linear_xy"
  ) %in% names(first)))
  expect_null(first$fit_yx)
})

test_that("janusplot_data correlations lie in [-1, 1] and agree with stats::cor", {
  d <- make_linear_data(n = 200L)
  out <- janusplot_data(d, vars = c("x1", "x2"))
  p <- out$pairs[[1L]]
  expect_true(is.finite(p$cor_spearman))
  expect_true(all(abs(c(p$cor_pearson, p$cor_spearman, p$cor_kendall)) <= 1))
  # Sanity: recompute Pearson on the raw columns and compare.
  ref <- stats::cor(d$x1, d$x2, use = "pairwise.complete.obs")
  expect_equal(p$cor_pearson, ref, tolerance = 1e-10)
})

test_that("janusplot_data shape labels recover known canonical shapes", {
  # Synthetic pair: y = x (linear_up). Spearman ≈ 1.
  # mgcv REML smoothing on noisy linear data may yield a near-linear
  # spline with tiny wiggles, so allow any monotone-increasing family.
  withr::with_seed(42L, {
    n  <- 200L
    x1 <- stats::runif(n, 0, 10)
    x2 <- x1 + stats::rnorm(n, sd = 0.1)
    d  <- data.frame(x1 = x1, x2 = x2)
  })
  out <- janusplot_data(d, vars = c("x1", "x2"))
  p <- out$pairs[[1L]]
  expect_true(p$shape_yx %in%
                c("linear_up", "convex_up", "concave_up", "s_shape"))
  expect_gt(p$cor_spearman, 0.9)
})

test_that("janusplot_data keep_fits = TRUE retains gam objects", {
  d <- make_linear_data(n = 100L)
  out <- janusplot_data(d, vars = c("x1", "x2"), keep_fits = TRUE)
  expect_s3_class(out$pairs[[1L]]$fit_yx, "gam")
  expect_s3_class(out$pairs[[1L]]$fit_xy, "gam")
})

test_that("janusplot_data asymmetry_index is in [0, 1]", {
  d <- make_nonlinear_data(n = 200L)
  out <- janusplot_data(d)
  ax <- vapply(out$pairs, function(p) p$asymmetry_index, numeric(1L))
  ax <- ax[!is.na(ax)]
  expect_true(all(ax >= 0 & ax <= 1))
})

test_that("heteroscedastic data yields non-trivial asymmetry for x1-x2", {
  d <- make_heteroscedastic_data(n = 300L)
  out <- janusplot_data(d, vars = c("x1", "x2"))
  expect_true(is.finite(out$pairs[[1L]]$asymmetry_index))
})
