skip_on_cran()  # heavy GAM-fit suite: full on CI, skipped on CRAN for time budget

# Tests for Feature 2 — focus filter (companion to compact tiers).
# Covers: quantile-string thresholds, numeric cutoff, NA -> no-op,
# mask correctness against a synthetic asymmetry distribution.

skip_if_no_mgcv <- function() {
  testthat::skip_if_not_installed("mgcv")
}

# ---------------------------------------------------------------
# Mask resolver, over a list of faces (see .pair_face())
# ---------------------------------------------------------------

test_that("focus_by = NA returns all-TRUE mask", {
  faces <- list(a = list(edf = 1), b = list(edf = 3))
  mask <- janusplot:::.resolve_focus_mask(faces, focus_by = NA)
  expect_true(all(mask))
  expect_length(mask, 2L)
})

test_that("focus_by = 'edf' with q50 keeps the top half", {
  faces <- lapply(c(1, 2, 3, 4), function(e) list(edf = e))
  mask <- janusplot:::.resolve_focus_mask(
    faces, focus_by = "edf", focus_threshold = "q50"
  )
  expect_true(sum(mask) >= 2L)
  # The two highest-edf cells must be in focus.
  expect_true(mask[3L] && mask[4L])
})

test_that("focus_by = 'asymmetry' and 'non_linearity' read their fields", {
  faces <- list(
    list(edf = 1.0, asymmetry_index = 0.1),
    list(edf = 2.5, asymmetry_index = 0.6),
    list(edf = 4.0, asymmetry_index = 0.2)
  )
  expect_equal(unname(janusplot:::.resolve_focus_mask(
    faces, focus_by = "asymmetry", focus_threshold = 0.5
  )), c(FALSE, TRUE, FALSE))
  expect_equal(unname(janusplot:::.resolve_focus_mask(
    faces, focus_by = "non_linearity", focus_threshold = 1
  )), c(FALSE, TRUE, TRUE))
  faces[[2L]]$k_flag <- TRUE
  expect_equal(unname(janusplot:::.resolve_focus_mask(
    faces, focus_by = "k_flag", focus_threshold = 1
  )), c(FALSE, TRUE, FALSE))
})

test_that("focus_by = 'edf' with numeric cutoff filters correctly", {
  faces <- lapply(c(1, 2, 5, 8), function(e) list(edf = e))
  mask <- janusplot:::.resolve_focus_mask(
    faces, focus_by = "edf", focus_threshold = 3
  )
  expect_equal(unname(mask), c(FALSE, FALSE, TRUE, TRUE))
})

test_that("invalid focus_threshold string errors loudly", {
  faces <- lapply(c(1, 2), function(e) list(edf = e))
  expect_error(
    janusplot:::.resolve_focus_mask(
      faces, focus_by = "edf", focus_threshold = "qninety"
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
  fit <- janusplot_fit(dat, vars = c("x1", "x2", "x3"))
  before <- fit$table
  p_default <- plot(fit)
  p_na      <- plot(fit, focus_by = NA)
  expect_s3_class(p_default, "ggplot")
  expect_s3_class(p_na, "ggplot")
  # Cell content metrics are identical because focus is rendering-only.
  cols <- c("edf", "asymmetry_index", "association_p", "cor_spearman")
  expect_identical(summary(fit)[, cols], before[, cols])
})

test_that("invalid focus_dim_alpha errors loudly", {
  expect_error(janusplot_style(focus_dim_alpha = -0.1), "in \\[0, 1\\]")
  expect_error(janusplot_style(focus_dim_alpha = 2), "in \\[0, 1\\]")
})

test_that("invalid focus_by value errors loudly", {
  dat <- make_linear_data(60L, seed = 1L)
  expect_error(
    janusplot(dat, vars = c("x1", "x2"), focus_by = "nonsense"),
    "Unknown"
  )
})
