skip_on_cran()  # heavy GAM-fit suite: full on CI, skipped on CRAN for time budget

# Tests for Feature 4 — fitting-engine dispatch (bam vs gam).
# Covers: both engines produce ggplot + with_data; both agree on
# linear DGP within EDF tolerance; engine + method columns surface
# in with_data; public API validation; arg_match guard.

skip_if_no_mgcv <- function() {
  testthat::skip_if_not_installed("mgcv")
}

# ---------------------------------------------------------------
# Both engines: end-to-end smoke
# ---------------------------------------------------------------

test_that("engine = 'bam' (default) produces ggplot + with_data", {
  skip_if_no_mgcv()
  dat <- make_linear_data(150L, seed = 1L)
  out <- janusplot(dat, vars = c("x1", "x2", "x3"), with_data = TRUE)
  expect_s3_class(out$plot, "ggplot")
  expect_true(all(out$data$engine == "bam"))
  expect_true(all(out$data$method == "fREML"))
})

test_that("engine = 'gam' produces ggplot + with_data with REML method", {
  skip_if_no_mgcv()
  dat <- make_linear_data(150L, seed = 1L)
  out <- janusplot(dat, vars = c("x1", "x2", "x3"),
                   engine = "gam", with_data = TRUE)
  expect_s3_class(out$plot, "ggplot")
  expect_true(all(out$data$engine == "gam"))
  expect_true(all(out$data$method == "REML"))
})

# ---------------------------------------------------------------
# Engines AGREE on a linear DGP: EDF should be ~1 for both.
# fREML and REML differ by ~1-3% in EDF on the same data; on a
# linear DGP this is well below the 0.5 tolerance.
# ---------------------------------------------------------------

test_that("both engines agree closely (<10% relative shift) on linear DGP", {
  skip_if_no_mgcv()
  dat <- make_linear_data(200L, seed = 1L)
  bam_data <- janusplot(dat, vars = c("x1", "x2"),
                        engine = "bam", with_data = TRUE)$data
  gam_data <- janusplot(dat, vars = c("x1", "x2"),
                        engine = "gam", with_data = TRUE)$data
  # fREML (bam) vs REML (gam) differ by a few percent on identical
  # data — this is the documented v0.1.0 -> v0.1.1 numerical shift.
  # Sanity check: relative shift <10%.
  rel_diff <- abs(bam_data$edf - gam_data$edf) /
    pmax(0.5, gam_data$edf)
  expect_true(all(rel_diff < 0.10),
              info = sprintf("max rel diff = %.3f", max(rel_diff)))
})

# ---------------------------------------------------------------
# Engines AGREE on a non-linear DGP: both detect non-linearity.
# Numerical EDF values may differ by 1-3%; sign of the test
# (EDF > 1) must agree.
# ---------------------------------------------------------------

test_that("both engines detect non-linearity on a quadratic DGP (forward direction)", {
  skip_if_no_mgcv()
  dat <- make_nonlinear_data(200L, seed = 2L)
  bam_d <- janusplot(dat, vars = c("x1", "x2"),
                     engine = "bam", with_data = TRUE)$data
  gam_d <- janusplot(dat, vars = c("x1", "x2"),
                     engine = "gam", with_data = TRUE)$data
  # Forward direction: x2 ~ s(x1) on x2 = x1^2 + noise. Both
  # engines should easily land EDF > 1.5 in this direction.
  forward_bam <- bam_d[bam_d$var_x == "x1" & bam_d$var_y == "x2", ]
  forward_gam <- gam_d[gam_d$var_x == "x1" & gam_d$var_y == "x2", ]
  expect_true(forward_bam$edf > 1.5)
  expect_true(forward_gam$edf > 1.5)
  # The EDF values from the two engines should agree closely
  # (documented ~1-3% shift; we accept <10% to be robust).
  rel_diff <- abs(forward_bam$edf - forward_gam$edf) / forward_gam$edf
  expect_lt(rel_diff, 0.10)
})

# ---------------------------------------------------------------
# discrete / nthreads only apply to bam.
# ---------------------------------------------------------------

test_that("discrete = TRUE on engine = bam still renders", {
  skip_if_no_mgcv()
  dat <- make_linear_data(200L, seed = 1L)
  p <- janusplot(dat, vars = c("x1", "x2", "x3"),
                 engine = "bam", discrete = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("discrete = TRUE on engine = gam is silently ignored (gam doesn't use it)", {
  skip_if_no_mgcv()
  dat <- make_linear_data(150L, seed = 1L)
  expect_silent(
    janusplot(dat, vars = c("x1", "x2", "x3"),
              engine = "gam", discrete = TRUE)
  )
})

# ---------------------------------------------------------------
# Backward-compat escape: engine = "gam" + method = "REML" must
# match v0.1.0 fitting backend exactly. We can't snapshot v0.1.0
# output from this session, but we CAN assert engine + method
# columns reflect the v0.1.0 defaults.
# ---------------------------------------------------------------

test_that("engine = 'gam' + default method = REML matches v0.1.0 stack", {
  skip_if_no_mgcv()
  dat <- make_linear_data(60L, seed = 1L)
  d <- janusplot(dat, vars = c("x1", "x2"),
                 engine = "gam", with_data = TRUE)$data
  expect_true(all(d$engine == "gam"))
  expect_true(all(d$method == "REML"))
})

# ---------------------------------------------------------------
# Public API validation
# ---------------------------------------------------------------

test_that("invalid engine errors via arg_match", {
  skip_if_no_mgcv()
  dat <- make_linear_data(50L, seed = 1L)
  expect_error(
    janusplot(dat, vars = c("x1", "x2"), engine = "torch"),
    "must be one of"
  )
})

test_that("invalid discrete / nthreads error loudly", {
  skip_if_no_mgcv()
  dat <- make_linear_data(50L, seed = 1L)
  expect_error(
    janusplot(dat, vars = c("x1", "x2"), discrete = NA),
    "TRUE or FALSE"
  )
  expect_error(
    janusplot(dat, vars = c("x1", "x2"), nthreads = 0),
    "positive integer"
  )
})

# ---------------------------------------------------------------
# User-supplied method override beats per-engine default.
# ---------------------------------------------------------------

test_that("explicit method overrides per-engine default", {
  skip_if_no_mgcv()
  dat <- make_linear_data(80L, seed = 1L)
  d <- janusplot(dat, vars = c("x1", "x2"),
                 engine = "gam", method = "GCV.Cp",
                 with_data = TRUE)$data
  expect_true(all(d$method == "GCV.Cp"))
})

# ---------------------------------------------------------------
# janusplot_data() carries engine + method on every pair.
# ---------------------------------------------------------------

test_that("janusplot_data carries engine + method per pair", {
  skip_if_no_mgcv()
  dat <- make_linear_data(80L, seed = 1L)
  res <- janusplot_data(dat, vars = c("x1", "x2", "x3"),
                        engine = "gam")
  for (p in res$pairs) {
    expect_identical(p$engine, "gam")
    expect_identical(p$method, "REML")
  }
})
