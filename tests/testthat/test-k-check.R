# Tests for Feature 1 — per-cell k-checking + opt-in auto-refit.
# Covers: diagnostic always-on; unreliable detection; flag plumbing;
# refit loop respects k_max_iter + per-cell unique-x cap; public API
# validation; annotations vocabulary accepts "k_warn".

skip_if_no_mgcv <- function() {
  testthat::skip_if_not_installed("mgcv")
}

# ---------------------------------------------------------------
# Diagnostic always-on — no opt-in needed
# ---------------------------------------------------------------

test_that("k-check diagnostics populate every cell on a normal dataset", {
  skip_if_no_mgcv()
  dat <- make_linear_data(n = 200L, seed = 1L)
  res <- janusplot_data(dat, vars = c("x1", "x2", "x3"))
  expect_true(length(res$pairs) > 0L)
  for (p in res$pairs) {
    expect_named(p$k_check_yx,
                 c("k_prime", "k_index", "k_p", "k_flag",
                   "k_check_status", "k_initial", "k_final",
                   "k_iterations", "k_at_cap"))
    expect_true(p$k_check_yx$k_check_status %in% c("ok", "flagged"))
    expect_equal(p$k_check_yx$k_iterations, 0L)
    expect_false(p$k_check_yx$k_at_cap)
  }
})

test_that("with_data table carries the 9 k-check columns", {
  skip_if_no_mgcv()
  dat <- make_linear_data(n = 200L, seed = 1L)
  out <- janusplot(dat, vars = c("x1", "x2", "x3"), with_data = TRUE)
  expected <- c("k_prime", "k_index", "k_p", "k_flag",
                "k_check_status", "k_initial", "k_final",
                "k_iterations", "k_at_cap")
  expect_true(all(expected %in% names(out$data)))
  expect_type(out$data$k_flag, "logical")
  expect_type(out$data$k_iterations, "integer")
})

# ---------------------------------------------------------------
# Unreliable status on cells with very few unique x values
# ---------------------------------------------------------------

test_that("k-check marks discrete-x cells with < 10 unique values as unreliable", {
  skip_if_no_mgcv()
  # 8 unique x values: mgcv fits (k = 8 allowed) but n_unique < 10
  # means k.check's simulation p-value is meaningless. Use k = 6 so
  # the fit definitely succeeds.
  withr::with_seed(7L, {
    n <- 80L
    df <- data.frame(
      g  = sample(seq_len(8L), n, replace = TRUE),
      y1 = stats::rnorm(n),
      y2 = stats::rnorm(n)
    )
  })
  res <- janusplot_data(df, vars = c("g", "y1", "y2"), k = 6L)
  # Cells where g is the predictor (i.e. s(g)) should be unreliable.
  statuses <- character()
  for (p in res$pairs) {
    if (p$var_i == "g") {
      statuses <- c(statuses, p$k_check_yx$k_check_status %||% NA_character_)
    }
    if (p$var_j == "g") {
      statuses <- c(statuses, p$k_check_xy$k_check_status %||% NA_character_)
    }
  }
  expect_true(any(statuses == "unreliable", na.rm = TRUE))
})

# ---------------------------------------------------------------
# Auto-refit loop
# ---------------------------------------------------------------

test_that("auto_refit_k = FALSE does not refit even on flagged cells", {
  skip_if_no_mgcv()
  # A noisy oscillation that will flag k underfit at the default k = 10.
  withr::with_seed(11L, {
    n <- 400L
    x <- stats::runif(n, 0, 10)
    df <- data.frame(
      x  = x,
      y  = sin(3 * x) + stats::rnorm(n, sd = 0.2),
      z  = stats::rnorm(n)
    )
  })
  res <- janusplot_data(df, vars = c("x", "y", "z"))
  for (p in res$pairs) {
    expect_equal(p$k_check_yx$k_iterations, 0L)
    expect_equal(p$k_check_xy$k_iterations, 0L)
    expect_false(p$k_check_yx$k_at_cap)
    expect_false(p$k_check_xy$k_at_cap)
  }
})

test_that("auto_refit_k = TRUE doubles k on flagged cells, respects k_max_iter", {
  skip_if_no_mgcv()
  withr::with_seed(13L, {
    n <- 400L
    x <- stats::runif(n, 0, 10)
    df <- data.frame(
      x = x,
      y = sin(3 * x) + stats::rnorm(n, sd = 0.2)
    )
  })
  res_no  <- janusplot_data(df, vars = c("x", "y"),
                            auto_refit_k = FALSE)
  res_yes <- janusplot_data(df, vars = c("x", "y"),
                            auto_refit_k = TRUE, k_max_iter = 2L)
  was_flagged <- FALSE
  for (p in res_no$pairs) {
    if (isTRUE(p$k_check_yx$k_flag) || isTRUE(p$k_check_xy$k_flag)) {
      was_flagged <- TRUE
    }
  }
  if (was_flagged) {
    iters <- c()
    for (p in res_yes$pairs) {
      iters <- c(iters, p$k_check_yx$k_iterations, p$k_check_xy$k_iterations)
    }
    expect_true(any(iters > 0L))
    expect_true(all(iters <= 2L))
  } else {
    succeed("no cells flagged on this DGP — refit loop has nothing to do")
  }
})

test_that("k_max_iter = 0 disables refit even with auto_refit_k = TRUE", {
  skip_if_no_mgcv()
  withr::with_seed(17L, {
    n <- 400L
    x <- stats::runif(n, 0, 10)
    df <- data.frame(
      x = x,
      y = sin(3 * x) + stats::rnorm(n, sd = 0.2)
    )
  })
  res <- janusplot_data(df, vars = c("x", "y"),
                        auto_refit_k = TRUE, k_max_iter = 0L)
  for (p in res$pairs) {
    expect_equal(p$k_check_yx$k_iterations, 0L)
    expect_equal(p$k_check_xy$k_iterations, 0L)
  }
})

# ---------------------------------------------------------------
# Public API validation
# ---------------------------------------------------------------

test_that("k_check_thresholds defaults match Wood (2017) and gam.check()", {
  expect_identical(
    janusplot:::.default_k_thresholds(),
    list(edf_ratio = 0.9, k_index = 1.0, p = 0.05)
  )
})

test_that("invalid k_check_thresholds errors loudly", {
  dat <- make_linear_data(n = 60L, seed = 1L)
  expect_error(
    janusplot_data(dat, vars = c("x1", "x2"),
                   k_check_thresholds = list(edf_ratio = 0.9)),
    "missing entries"
  )
  expect_error(
    janusplot_data(dat, vars = c("x1", "x2"),
                   k_check_thresholds = list(edf_ratio = -1, k_index = 1, p = 0.05)),
    "positive finite"
  )
  expect_error(
    janusplot_data(dat, vars = c("x1", "x2"),
                   k_check_thresholds = "edf_ratio = 0.9"),
    "named list"
  )
})

test_that("invalid auto_refit_k / k_max_iter error loudly", {
  dat <- make_linear_data(n = 60L, seed = 1L)
  expect_error(
    janusplot_data(dat, vars = c("x1", "x2"), auto_refit_k = NA),
    "TRUE or FALSE"
  )
  expect_error(
    janusplot_data(dat, vars = c("x1", "x2"), k_max_iter = -1),
    "non-negative integer"
  )
})

# ---------------------------------------------------------------
# Annotations vocabulary accepts "k_warn"
# ---------------------------------------------------------------

test_that("annotations = c('k_warn') is accepted and produces a ggplot", {
  skip_if_no_mgcv()
  dat <- make_linear_data(n = 60L, seed = 1L)
  p <- janusplot(dat, vars = c("x1", "x2"),
                 annotations = c("edf", "A", "k_warn"))
  expect_s3_class(p, "ggplot")
})

test_that("invalid annotation entry surfaces full vocabulary in error", {
  dat <- make_linear_data(n = 60L, seed = 1L)
  expect_error(
    janusplot(dat, vars = c("x1", "x2"), annotations = c("edf", "nonsense")),
    "k_warn"
  )
})
