test_that("linear pair recovers EDF close to 1", {
  d <- make_linear_data(n = 200L)
  f <- janusplot:::.fit_pair(
    x_name = "x1", y_name = "x2", data_full = d,
    adjust = NULL, method = "REML", k = -1L, bs = "tp",
    na_action = "pairwise"
  )
  expect_lt(f$edf, 2)
  expect_gt(f$edf, 0.8)
  expect_equal(f$n_used, 200L)
  expect_true(is.finite(f$pvalue))
})

test_that("quadratic pair recovers EDF well above 1", {
  d <- make_nonlinear_data(n = 200L)
  f <- janusplot:::.fit_pair(
    x_name = "x1", y_name = "x2", data_full = d,
    adjust = NULL, method = "REML", k = -1L, bs = "tp",
    na_action = "pairwise"
  )
  expect_gt(f$edf, 2)
})

test_that(".fit_pair respects adjust covariates", {
  d <- make_linear_data(n = 200L)
  d$site <- factor(sample(letters[1:3], 200L, replace = TRUE))
  f <- janusplot:::.fit_pair(
    x_name = "x1", y_name = "x2", data_full = d,
    adjust = ~ s(site, bs = "re"),
    method = "REML", k = -1L, bs = "tp",
    na_action = "pairwise"
  )
  expect_true(is.finite(f$edf))
  expect_s3_class(f$fit, "gam")
  # fit's formula should include the random effect
  expect_true(grepl("site", deparse(stats::formula(f$fit))))
})

test_that(".fit_pair handles pairwise-complete missingness", {
  d <- make_linear_data(n = 200L)
  d$x2[1:20] <- NA
  f <- janusplot:::.fit_pair(
    x_name = "x1", y_name = "x2", data_full = d,
    adjust = NULL, method = "REML", k = -1L, bs = "tp",
    na_action = "pairwise"
  )
  expect_equal(f$n_used, 180L)
})
