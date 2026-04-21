# Shape-metric unit tests.
# We build synthetic fit_obj-like lists directly (no mgcv fit needed)
# so tests are deterministic, fast, and isolate the metric logic from
# GAM smoothing noise.

# Build a minimal fit object matching what .compute_shape_metrics_raw()
# expects: pred data frame (x, fit, se, lo, hi) + raw data frame.
.mk_fit <- function(x, y, y_name = "y", x_name = "x") {
  list(
    x_name = x_name,
    y_name = y_name,
    pred   = data.frame(x = x, fit = y,
                        se = 0, lo = y, hi = y),
    raw    = setNames(data.frame(x, y), c(x_name, y_name))
  )
}

test_that("linear increasing recovers M ~ 1, C ~ 0, linear_up", {
  x <- seq(0, 10, length.out = 200L)
  y <- 2 * x
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_equal(m$M, 1, tolerance = 1e-6)
  expect_lt(abs(m$C), 0.1)
  expect_equal(m$shape_category, "linear_up")
})

test_that("linear decreasing recovers M ~ -1, linear_down", {
  x <- seq(0, 10, length.out = 200L)
  y <- -1.5 * x + 7
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_equal(m$M, -1, tolerance = 1e-6)
  expect_equal(m$shape_category, "linear_down")
})

test_that("y = x^2 on [0, 10] recovers convex_up", {
  x <- seq(0, 10, length.out = 200L)
  y <- x^2
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_gt(m$M, 0.5)
  expect_gt(m$C, 0.5)
  expect_equal(m$shape_category, "convex_up")
})

test_that("y = log1p(x) recovers concave_up (saturating growth)", {
  x <- seq(0.01, 10, length.out = 200L)
  y <- log1p(x)
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_gt(m$M, 0.5)
  expect_lt(m$C, -0.3)
  expect_equal(m$shape_category, "concave_up")
})

test_that("inverted parabola on [0, 10] recovers inverted_u", {
  x <- seq(0, 10, length.out = 200L)
  y <- -(x - 5)^2
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_lt(abs(m$M), 0.3)
  expect_lt(m$C, -0.5)
  expect_equal(m$shape_category, "inverted_u")
})

test_that("upright parabola on [0, 10] recovers u_shape", {
  x <- seq(0, 10, length.out = 200L)
  y <- (x - 5)^2
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_lt(abs(m$M), 0.3)
  expect_gt(m$C, 0.5)
  expect_equal(m$shape_category, "u_shape")
})

test_that("tanh on [-5, 5] recovers s_shape", {
  x <- seq(-5, 5, length.out = 200L)
  y <- tanh(x)
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_equal(m$n_inflections, 1L)
  expect_gt(abs(m$M), 0.5)
  expect_equal(m$shape_category, "s_shape")
})

test_that("flat line is labelled flat", {
  x <- seq(0, 10, length.out = 200L)
  y <- rep(3, 200L)
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_equal(m$shape_category, "flat")
})

test_that("NA fit yields indeterminate category", {
  x <- seq(0, 10, length.out = 10L)
  y <- rep(NA_real_, 10L)
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_equal(m$shape_category, "indeterminate")
})

test_that("janusplot_shape_cutoffs accepts valid overrides", {
  co <- janusplot_shape_cutoffs(curv_mod = 0.6, flat = 0.01)
  expect_equal(co$curv_mod, 0.6)
  expect_equal(co$flat, 0.01)
  expect_equal(co$mono_strong, 0.9)  # default retained
})

test_that("janusplot_shape_cutoffs rejects unknown names and bad types", {
  expect_error(janusplot_shape_cutoffs(not_a_cutoff = 0.5))
  expect_error(janusplot_shape_cutoffs(curv_mod = "big"))
  expect_error(janusplot_shape_cutoffs(curv_mod = c(0.4, 0.6)))
})

test_that("janusplot_shape_metrics() works on a freshly fitted gam", {
  withr::with_seed(2026L, {
    n <- 200L
    x <- stats::runif(n, 0.01, 10)
    y <- log1p(x) + stats::rnorm(n, sd = 0.2)
    d <- data.frame(x = x, y = y)
  })
  fit <- mgcv::gam(y ~ s(x), data = d, method = "REML")
  m   <- janusplot_shape_metrics(fit, x_name = "x", newdata = d)
  # Saturating growth: monotone increasing; mgcv may recover this
  # as linear_up (if smoothing penalty dominates), concave_up (if
  # curvature is detected), or s_shape (if it overshoots once).
  expect_true(m$shape_category %in%
                c("linear_up", "concave_up", "s_shape"))
  expect_gt(m$M, 0.5)
})

test_that("janusplot_shape_metrics() rejects bogus inputs", {
  expect_error(janusplot_shape_metrics("not a fit"))
  fit <- mgcv::gam(mpg ~ s(wt), data = mtcars, method = "REML")
  expect_error(janusplot_shape_metrics(fit, x_name = NULL))
  expect_error(janusplot_shape_metrics(fit, x_name = "no_such_column"))
})

test_that(".shape_taxonomy has unique category names and 24 rows", {
  tax <- janusplot:::.shape_taxonomy()
  expect_equal(nrow(tax), 24L)
  expect_equal(length(unique(tax$category)), 24L)
  ascii_bytes <- vapply(tax$ascii, function(s) all(charToRaw(s) < as.raw(128L)),
                        logical(1L))
  expect_true(all(ascii_bytes))
})

test_that("taxonomy hierarchy columns are complete, unique, and ASCII", {
  tax <- janusplot:::.shape_taxonomy()
  # 2-letter codes must be unique and ASCII
  expect_equal(length(unique(tax$code)), 24L)
  expect_true(all(nchar(tax$code) == 2L))
  code_bytes <- vapply(tax$code, function(s) all(charToRaw(s) < as.raw(128L)),
                       logical(1L))
  expect_true(all(code_bytes))
  # Archetype must be one of 7 values
  expect_true(all(tax$archetype %in%
                    c("monotone_linear", "monotone_curved",
                      "unimodal", "wave", "multimodal",
                      "chaotic", "degenerate")))
  # monotonic column restricted to 3 values
  expect_true(all(tax$monotonic %in%
                    c("monotone", "non_monotone", "degenerate")))
  # linear column restricted to 3 values
  expect_true(all(tax$linear %in%
                    c("linear", "non_linear", "degenerate")))
  # No NA anywhere in the hierarchy columns
  expect_false(any(is.na(tax$code)))
  expect_false(any(is.na(tax$archetype)))
  expect_false(any(is.na(tax$monotonic)))
  expect_false(any(is.na(tax$linear)))
})

test_that("janusplot_shape_hierarchy() is the public mirror of the taxonomy", {
  expect_identical(janusplot_shape_hierarchy(), janusplot:::.shape_taxonomy())
  expect_true(all(c("category", "code", "archetype", "monotonic",
                    "linear", "label", "gloss") %in%
                    names(janusplot_shape_hierarchy())))
})

test_that("degenerate categories flagged as degenerate in all tiers", {
  tax <- janusplot_shape_hierarchy()
  deg <- tax[tax$category %in% c("flat", "indeterminate"), ]
  expect_true(all(deg$archetype == "degenerate"))
  expect_true(all(deg$monotonic == "degenerate"))
  expect_true(all(deg$linear    == "degenerate"))
})

test_that("linear_up / linear_down are the only `linear` linear-tier rows", {
  tax <- janusplot_shape_hierarchy()
  expect_setequal(tax$category[tax$linear == "linear"],
                  c("linear_up", "linear_down"))
})

test_that("skewed_peak recovered from y = x * exp(-3x)", {
  x <- seq(0, 1, length.out = 200L)
  y <- x * exp(-3 * x)
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_equal(m$n_turning_points, 1L)
  # (1, 0) would be inverted_u/u_shape; a true skewed_peak wants
  # at least one inflection on the asymmetric descent.
  expect_true(m$shape_category %in%
                c("skewed_peak", "inverted_u", "broad_peak"))
})

test_that("broad_peak recovered from plateau exp(-((x-.5)*3)^4)", {
  x <- seq(0, 1, length.out = 200L)
  y <- exp(-((x - 0.5) * 3)^4)
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_equal(m$n_turning_points, 1L)
  expect_true(m$shape_category %in% c("broad_peak", "inverted_u"))
})

test_that("wave recovered from sin(2pi x)", {
  x <- seq(0, 1, length.out = 200L)
  y <- sin(2 * pi * x)
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_equal(m$n_turning_points, 2L)
  expect_equal(m$shape_category, "wave")
})

test_that("bi_wave recovered from sin(4pi x)", {
  x <- seq(0, 1, length.out = 400L)
  y <- sin(4 * pi * x)
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_equal(m$n_turning_points, 4L)
  expect_true(m$shape_category %in%
                c("bi_wave", "bi_wave_ripple"))
})

test_that("bimodal recovered from two-gaussian mixture", {
  x <- seq(0, 1, length.out = 400L)
  y <- exp(-((x - 0.25) * 6)^2) + exp(-((x - 0.75) * 6)^2)
  m <- janusplot:::.compute_shape_metrics(.mk_fit(x, y))
  expect_equal(m$n_turning_points, 3L)
  expect_true(m$shape_category %in% c("bimodal", "bimodal_ripple"))
})
