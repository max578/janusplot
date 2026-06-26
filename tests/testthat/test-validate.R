test_that("non-data-frame input is rejected", {
  expect_error(janusplot(1:10), class = "rlang_error")
})

test_that("too few rows is rejected", {
  expect_error(janusplot(data.frame(a = 1:3, b = 4:6)), class = "rlang_error")
})

test_that("vars must exist in data", {
  d <- make_linear_data(n = 50L)
  expect_error(janusplot(d, vars = c("x1", "missing")),
               class = "rlang_error")
})

test_that("vars must be numeric", {
  d <- data.frame(a = 1:30, g = factor(rep(c("a", "b"), 15L)))
  expect_error(janusplot(d, vars = c("a", "g")), class = "rlang_error")
})

test_that("adjust must be a one-sided formula", {
  d <- make_linear_data(n = 50L)
  expect_error(janusplot(d, adjust = "not a formula"),
               class = "rlang_error")
  expect_error(janusplot(d, adjust = y ~ x), class = "rlang_error")
})

test_that(".resolve_vars picks numeric columns by default", {
  d <- data.frame(a = 1:30, b = 1:30 + 0.5,
                  g = factor(rep(c("a", "b"), 15L)))
  out <- janusplot:::.resolve_vars(d, NULL)
  expect_equal(out, c("a", "b"))
})

# --- Shared scalar-argument validation --------------------------------------
# Characterisation tests pinning the message + that each check fires (before
# any model is fit). These guard the .validate_shared_scalars() delegation
# shared by janusplot() and janusplot_data().

test_that("discrete must be a single non-NA logical", {
  d <- make_linear_data(n = 50L)
  expect_error(janusplot_data(d, discrete = "yes"), "discrete")
  expect_error(janusplot_data(d, discrete = c(TRUE, FALSE)), "discrete")
  expect_error(janusplot_data(d, discrete = NA), "discrete")
})

test_that("nthreads must be a single positive integer", {
  d <- make_linear_data(n = 50L)
  expect_error(janusplot_data(d, nthreads = 0), "nthreads")
  expect_error(janusplot_data(d, nthreads = -1L), "nthreads")
  expect_error(janusplot_data(d, nthreads = c(1L, 2L)), "nthreads")
})

test_that("auto_refit_k must be a single non-NA logical", {
  d <- make_linear_data(n = 50L)
  expect_error(janusplot_data(d, auto_refit_k = "x"), "auto_refit_k")
  expect_error(janusplot_data(d, auto_refit_k = NA), "auto_refit_k")
})

test_that("k_max_iter must be a single non-negative integer", {
  d <- make_linear_data(n = 50L)
  expect_error(janusplot_data(d, k_max_iter = -1L), "k_max_iter")
  expect_error(janusplot_data(d, k_max_iter = c(1L, 2L)), "k_max_iter")
})

test_that("derivative_ci_nsim must be a single integer >= 100", {
  d <- make_linear_data(n = 50L)
  expect_error(janusplot_data(d, derivative_ci_nsim = 50), "derivative_ci_nsim")
  expect_error(
    janusplot_data(d, derivative_ci_nsim = c(100L, 200L)),
    "derivative_ci_nsim"
  )
})

test_that("shared scalar checks also fire from janusplot()", {
  d <- make_linear_data(n = 50L)
  expect_error(janusplot(d, discrete = "yes"), "discrete")
  expect_error(janusplot(d, nthreads = 0), "nthreads")
})
