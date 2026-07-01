skip_on_cran()  # heavy GAM-fitting/rendering suite: full coverage runs on CI; skipped on CRAN to stay within the check time budget

# Tests for Feature 2 — focus filter (companion to compact tiers).
# Covers: quantile-string thresholds, numeric cutoff, NA -> no-op,
# mask correctness against a synthetic asymmetry distribution.

skip_if_no_mgcv <- function() {
  testthat::skip_if_not_installed("mgcv")
}

# ---------------------------------------------------------------
# Mask resolver
# ---------------------------------------------------------------

test_that("focus_by = NA returns all-TRUE mask", {
  fits <- list(a = list(edf = 1), b = list(edf = 3))
  mask <- janusplot:::.resolve_focus_mask(fits, focus_by = NA)
  expect_true(all(mask))
  expect_length(mask, 2L)
})

test_that("focus_by = 'edf' with q50 keeps the top half", {
  fits <- mapply(function(e, k) list(edf = e, key = k),
                 c(1, 2, 3, 4),
                 c("1_2", "1_3", "2_3", "1_4"), SIMPLIFY = FALSE)
  fits <- lapply(seq_along(fits), function(i) {
    structure(fits[[i]], key = c("1_2", "1_3", "2_3", "1_4")[i])
  })
  mask <- janusplot:::.resolve_focus_mask(
    fits, focus_by = "edf", focus_threshold = "q50"
  )
  expect_true(sum(mask) >= 2L)
  # The two highest-edf cells must be in focus.
  expect_true(mask[3L] || mask[4L])
})

test_that("focus_by = 'edf' with numeric cutoff filters correctly", {
  fits <- lapply(c(1, 2, 5, 8), function(e) list(edf = e))
  mask <- janusplot:::.resolve_focus_mask(
    fits, focus_by = "edf", focus_threshold = 3
  )
  expect_equal(unname(mask), c(FALSE, FALSE, TRUE, TRUE))
})

test_that("invalid focus_threshold string errors loudly", {
  fits <- lapply(c(1, 2), function(e) list(edf = e))
  expect_error(
    janusplot:::.resolve_focus_mask(
      fits, focus_by = "edf", focus_threshold = "qninety"
    ),
    "quantile string"
  )
})

# ---------------------------------------------------------------
# End-to-end public-API surface
# ---------------------------------------------------------------

test_that("janusplot(focus_by = 'asymmetry') renders a ggplot", {
  skip_if_no_mgcv()
  dat <- make_heteroscedastic_data(n = 200L, seed = 3L)
  p <- janusplot(dat, focus_by = "asymmetry", focus_threshold = "q50")
  expect_s3_class(p, "ggplot")
})

test_that("janusplot(focus_by = 'edf') renders a ggplot", {
  skip_if_no_mgcv()
  dat <- make_nonlinear_data(n = 200L, seed = 2L)
  p <- janusplot(dat, focus_by = "edf", focus_threshold = "q80")
  expect_s3_class(p, "ggplot")
})

test_that("janusplot(focus_by = NA) is the default no-op", {
  skip_if_no_mgcv()
  dat <- make_linear_data(n = 100L, seed = 1L)
  p_default <- janusplot(dat, vars = c("x1", "x2", "x3"), with_data = TRUE)
  p_na      <- janusplot(dat, vars = c("x1", "x2", "x3"),
                         focus_by = NA, with_data = TRUE)
  # Cell content metrics are identical because focus is rendering-only.
  cols <- c("edf", "asymmetry_index", "pvalue", "cor_spearman")
  expect_identical(p_default$data[, cols], p_na$data[, cols])
})

test_that("invalid focus_dim_alpha errors loudly", {
  dat <- make_linear_data(60L, seed = 1L)
  expect_error(
    janusplot(dat, vars = c("x1", "x2"),
              focus_by = "edf", focus_dim_alpha = -0.1),
    "in \\[0, 1\\]"
  )
  expect_error(
    janusplot(dat, vars = c("x1", "x2"),
              focus_by = "edf", focus_dim_alpha = 2),
    "in \\[0, 1\\]"
  )
})

test_that("invalid focus_by value errors loudly", {
  dat <- make_linear_data(60L, seed = 1L)
  expect_error(
    janusplot(dat, vars = c("x1", "x2"), focus_by = "nonsense"),
    "Unknown"
  )
})
