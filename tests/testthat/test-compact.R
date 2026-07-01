skip_on_cran()  # heavy GAM-fit suite: full on CI, skipped on CRAN for time budget

# Tests for Feature 2 — scale-aware compact rendering.
# Covers: tier resolver behaviour at thresholds; compact = "always" /
# "never" overrides; backward-compat at k < 12; compact_levels
# overrides; public API validation.

# ---------------------------------------------------------------
# Tier resolver
# ---------------------------------------------------------------

test_that(".compact_tier returns 0 below default threshold", {
  expect_equal(janusplot:::.compact_tier(5L), 0L)
  expect_equal(janusplot:::.compact_tier(11L), 0L)
})

test_that(".compact_tier returns 1 at default tier-1 threshold", {
  expect_equal(janusplot:::.compact_tier(12L), 1L)
  expect_equal(janusplot:::.compact_tier(17L), 1L)
})

test_that(".compact_tier returns 2 at default tier-2 threshold", {
  expect_equal(janusplot:::.compact_tier(18L), 2L)
  expect_equal(janusplot:::.compact_tier(24L), 2L)
})

test_that(".compact_tier returns 3 at default tier-3 threshold", {
  expect_equal(janusplot:::.compact_tier(25L), 3L)
  expect_equal(janusplot:::.compact_tier(40L), 3L)
})

test_that("compact = 'never' forces tier 0 regardless of n_var", {
  expect_equal(janusplot:::.compact_tier(50L, compact = "never"), 0L)
})

test_that("compact = 'always' forces tier >= 1", {
  expect_equal(janusplot:::.compact_tier(3L, compact = "always"), 1L)
  expect_equal(janusplot:::.compact_tier(20L, compact = "always"), 2L)
  expect_equal(janusplot:::.compact_tier(30L, compact = "always"), 3L)
})

test_that("compact_threshold shifts the entire ladder", {
  expect_equal(
    janusplot:::.compact_tier(10L, compact_threshold = 15L),
    0L
  )
  expect_equal(
    janusplot:::.compact_tier(15L, compact_threshold = 15L),
    1L
  )
  expect_equal(
    janusplot:::.compact_tier(21L, compact_threshold = 15L),
    2L
  )
})

test_that("compact_levels override is honoured", {
  custom <- list(t1 = 8L, t2 = 16L, t3 = 24L)
  expect_equal(janusplot:::.compact_tier(7L,  compact_levels = custom), 0L)
  expect_equal(janusplot:::.compact_tier(8L,  compact_levels = custom), 1L)
  expect_equal(janusplot:::.compact_tier(16L, compact_levels = custom), 2L)
  expect_equal(janusplot:::.compact_tier(24L, compact_levels = custom), 3L)
})

test_that("invalid compact_levels errors loudly", {
  expect_error(
    janusplot:::.compact_tier(20L,
      compact_levels = list(t1 = 10L, t2 = 8L, t3 = 20L)),
    "t1 < t2 < t3"
  )
  expect_error(
    janusplot:::.compact_tier(20L,
      compact_levels = list(t1 = 1L, t2 = 5L, t3 = 10L)),
    "single integer >= 2"
  )
  expect_error(
    janusplot:::.compact_tier(20L,
      compact_levels = list(t1 = 5L, t2 = 10L)),
    "missing entries"
  )
})

# ---------------------------------------------------------------
# End-to-end: each tier renders without error
# ---------------------------------------------------------------

skip_if_no_mgcv <- function() {
  testthat::skip_if_not_installed("mgcv")
}

make_wide_data <- function(k_var, n = 80L, seed = 42L) {
  withr::with_seed(seed, {
    as.data.frame(matrix(stats::rnorm(n * k_var), ncol = k_var,
                         dimnames = list(NULL, sprintf("v%02d", seq_len(k_var)))))
  })
}

test_that("tier 0 (k = 5) renders a ggplot", {
  skip_if_no_mgcv()
  p <- janusplot(make_wide_data(5L))
  expect_s3_class(p, "ggplot")
})

test_that("tier 1 (k = 14) renders a ggplot", {
  skip_if_no_mgcv()
  p <- janusplot(make_wide_data(14L))
  expect_s3_class(p, "ggplot")
})

test_that("tier 2 (k = 19) renders a ggplot", {
  skip_if_no_mgcv()
  p <- janusplot(make_wide_data(19L))
  expect_s3_class(p, "ggplot")
})

test_that("tier 3 (k = 26) renders a ggplot", {
  skip_if_no_mgcv()
  p <- janusplot(make_wide_data(26L))
  expect_s3_class(p, "ggplot")
})

# ---------------------------------------------------------------
# Backward compatibility: at k < 12, output must be unchanged
# whether compact is "auto", "always" (forces tier 1) is OFF, or
# "never". Use the data summary as a proxy — fits + metrics
# computed are identical across compact settings.
# ---------------------------------------------------------------

test_that("compact setting does not affect fits / metrics (rendering-only knob)", {
  skip_if_no_mgcv()
  dat <- make_linear_data(n = 150L, seed = 1L)
  d_auto  <- janusplot(dat, vars = c("x1", "x2", "x3"),
                       compact = "auto", with_data = TRUE)$data
  d_always <- janusplot(dat, vars = c("x1", "x2", "x3"),
                        compact = "always", with_data = TRUE)$data
  d_never  <- janusplot(dat, vars = c("x1", "x2", "x3"),
                        compact = "never", with_data = TRUE)$data
  # Strip rendering-only columns; compare the fit-side metrics.
  cols <- c("edf", "asymmetry_index", "pvalue", "k_prime", "k_index",
            "cor_spearman", "shape_category", "monotonicity_index",
            "convexity_index")
  expect_identical(d_auto[, cols], d_always[, cols])
  expect_identical(d_auto[, cols], d_never[, cols])
})

# ---------------------------------------------------------------
# Public API validation
# ---------------------------------------------------------------

test_that("invalid compact value errors via arg_match", {
  expect_error(
    janusplot(make_linear_data(60L), compact = "sometimes"),
    "must be one of"
  )
})

test_that("invalid compact_threshold errors loudly", {
  expect_error(
    janusplot(make_linear_data(60L), compact_threshold = 0L),
    "integer >= 2"
  )
  expect_error(
    janusplot(make_linear_data(60L), compact_threshold = "twelve"),
    "integer >= 2"
  )
})
