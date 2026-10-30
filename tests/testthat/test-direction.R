# Known-truth oracle tests for janusplot_direction(), and the deprecated
# janusplot_direction_test() alias on a data frame.
#
# Every generator below is simulated from a data-generating process whose
# true direction (or provable absence of one) is fixed by construction,
# so the assertions are on the verdict itself, not on the function
# merely returning without error.
#
#   anm_identifiable  -- x -> y, non-linear f, non-Gaussian noise.
#                        ANM identifiable: the only direction admitting
#                        an additive noise model is x -> y.
#   linear_gaussian   -- x -> y linear, x and noise Gaussian. Provably
#                        NOT identifiable: a linear Gaussian model
#                        reproduces the joint distribution in either
#                        direction.
#   independent_pair  -- x and y drawn independently. No direction
#                        exists to be found.
#
# HSIC permutation p-values are seeded, so every verdict below is a
# fixed, reproducible property of the shipped generator.

skip_if_no_kernR <- function() {
  testthat::skip_if_not_installed("kernR")
}

# The fit the direction test reads: engine = "gam" so the direction fits
# use the fit's own method; derivatives are not needed here.
fit_of <- function(d, ...) {
  janusplot_fit(d, engine = "gam", derivatives = integer(), ...)
}

make_anm_identifiable <- function(n = 300L, seed = 11L) {
  withr::with_seed(seed, {
    x <- stats::runif(n, -3, 3)
    y <- x^3 / 5 + stats::runif(n, -1, 1)
    data.frame(x = x, y = y)
  })
}

make_linear_gaussian <- function(n = 300L, seed = 12L) {
  withr::with_seed(seed, {
    x <- stats::rnorm(n)
    y <- 0.8 * x + stats::rnorm(n, sd = 0.6)
    data.frame(x = x, y = y)
  })
}

make_independent_pair <- function(n = 300L, seed = 13L) {
  withr::with_seed(seed, {
    data.frame(x = stats::runif(n, -2, 2), y = stats::runif(n, -2, 2))
  })
}

# ---------------------------------------------------------------
# Oracle 1 -- identifiable ANM, true direction x -> y
# ---------------------------------------------------------------

test_that("an identifiable additive-noise pair returns the true forward direction", {
  skip_if_no_kernR()
  d   <- make_anm_identifiable()
  res <- janusplot_direction(fit_of(d), "x", "y",
                             n_permutations = 299L, seed = 7L)

  expect_identical(res$verdict, "forward")
  expect_identical(res$reason_code, "forward_only")
  # The licensing condition, stated directly: independent one way,
  # dependent the other.
  expect_true(res$independent_forward)
  expect_false(res$independent_reverse)
  expect_gt(res$p_forward, res$alpha)
  expect_lte(res$p_reverse, res$alpha)
  expect_identical(res$forward, "x -> y")
  expect_identical(res$n, 300L)
})

# ---------------------------------------------------------------
# Oracle 2 -- the same data with the roles swapped must reverse
# ---------------------------------------------------------------

test_that("swapping the roles of the same pair reverses the verdict", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  # Same data, opposite hypothesis: y named as the putative cause.
  res <- janusplot_direction(fit_of(d), "y", "x",
                             n_permutations = 299L, seed = 7L)

  expect_identical(res$verdict, "reverse")
  expect_identical(res$reason_code, "reverse_only")
  expect_false(res$independent_forward)
  expect_true(res$independent_reverse)
  # "reverse" here names the same physical direction the forward call
  # found: x is the cause under both readings.
  expect_identical(res$reverse, "x -> y")
})

# ---------------------------------------------------------------
# Oracle 3 -- linear-Gaussian is provably non-identifiable
# ---------------------------------------------------------------

test_that("a linear-Gaussian pair abstains and names non-identifiability", {
  skip_if_no_kernR()
  d   <- make_linear_gaussian()
  res <- janusplot_direction(fit_of(d), "x", "y",
                             n_permutations = 299L, seed = 7L)

  expect_identical(res$verdict, "undecided")
  expect_identical(res$reason_code, "linear_gaussian")
  expect_true(res$linear_gaussian)
  expect_match(res$reason, "not identifiable in the linear-Gaussian case",
               fixed = TRUE)
  # The two detector legs the verdict rests on.
  expect_lt(res$curvature_forward, res$linear_tol)
  expect_lt(res$curvature_reverse, res$linear_tol)
  expect_true(all(res$normality_p > res$gaussian_alpha))
})

test_that("the linear-Gaussian abstention survives a swap of roles", {
  skip_if_no_kernR()
  d   <- make_linear_gaussian()
  res <- janusplot_direction(fit_of(d), "y", "x",
                             n_permutations = 299L, seed = 7L)

  expect_identical(res$verdict, "undecided")
  expect_identical(res$reason_code, "linear_gaussian")
})

# ---------------------------------------------------------------
# Oracle 4 -- no association at all
# ---------------------------------------------------------------

test_that("an independent pair abstains rather than naming a direction", {
  skip_if_no_kernR()
  d   <- make_independent_pair()
  res <- janusplot_direction(fit_of(d), "x", "y",
                             n_permutations = 299L, seed = 7L)

  expect_identical(res$verdict, "undecided")
  expect_identical(res$reason_code, "both_independent")
  expect_true(res$independent_forward)
  expect_true(res$independent_reverse)
  # Uniform marginals, so the linear-Gaussian branch is not what
  # produced this abstention.
  expect_false(res$linear_gaussian)
})

# ---------------------------------------------------------------
# The abstention rule itself -- never read the smaller p-value
# ---------------------------------------------------------------

test_that("the smaller p-value is never promoted to a direction", {
  skip_if_no_kernR()
  for (d in list(make_linear_gaussian(), make_independent_pair())) {
    res <- janusplot_direction(fit_of(d), "x", "y",
                               n_permutations = 299L, seed = 7L)
    # One of the two p-values is necessarily the smaller, and on both of
    # these pairs the two independence tests agree, so the smaller one
    # carries no directional information. It must not have been read as
    # though it did.
    expect_identical(res$independent_forward, res$independent_reverse)
    expect_identical(res$verdict, "undecided")
  }
})

test_that("a verdict is always one of the three declared values", {
  skip_if_no_kernR()
  generators <- list(
    make_anm_identifiable(), make_linear_gaussian(), make_independent_pair()
  )
  for (d in generators) {
    res <- janusplot_direction(fit_of(d), "x", "y",
                               n_permutations = 199L, seed = 3L)
    expect_true(res$verdict %in% c("forward", "reverse", "undecided"))
    expect_true(res$reason_code %in% c(
      "forward_only", "reverse_only", "both_independent",
      "neither_independent", "linear_gaussian"
    ))
    expect_true(is.character(res$reason) && nzchar(res$reason))
  }
})

# ---------------------------------------------------------------
# Reported quantities
# ---------------------------------------------------------------

test_that("both p-values, both statistics, and the settings are reported", {
  skip_if_no_kernR()
  d   <- make_anm_identifiable()
  res <- janusplot_direction(fit_of(d), "x", "y",
                             n_permutations = 199L, alpha = 0.05,
                             seed = 5L)

  for (nm in c("p_forward", "p_reverse",
               "statistic_forward", "statistic_reverse",
               "edf_forward", "edf_reverse")) {
    expect_true(is.numeric(res[[nm]]) && length(res[[nm]]) == 1L)
    expect_true(is.finite(res[[nm]]))
  }
  expect_gte(res$p_forward, 0)
  expect_lte(res$p_forward, 1)
  expect_gte(res$p_reverse, 0)
  expect_lte(res$p_reverse, 1)
  expect_gt(res$statistic_forward, 0)
  expect_gt(res$statistic_reverse, 0)
  expect_identical(res$n_permutations, 199L)
  expect_identical(res$alpha, 0.05)
  expect_identical(
    names(res$normality_p),
    c("x", "y", "residuals_forward", "residuals_reverse")
  )
})

test_that("a seeded call is reproducible", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  fit <- fit_of(d)
  a <- janusplot_direction(fit, "x", "y", n_permutations = 199L, seed = 9L)
  b <- janusplot_direction(fit, "x", "y", n_permutations = 199L, seed = 9L)
  expect_identical(a$p_forward, b$p_forward)
  expect_identical(a$p_reverse, b$p_reverse)
  expect_identical(a$verdict, b$verdict)
})

# ---------------------------------------------------------------
# Optional dependency
# ---------------------------------------------------------------

test_that("a missing kernR is reported, not worked around", {
  local_mocked_bindings(.kernR_available = function() FALSE)
  d <- make_anm_identifiable(n = 60L)
  expect_error(
    janusplot_direction(fit_of(d), "x", "y"),
    "kernR"
  )
})

test_that("kernR is declared in Suggests, not Imports", {
  desc <- read.dcf(system.file("DESCRIPTION", package = "janusplot"))
  expect_false(grepl("kernR", desc[1L, "Imports"], fixed = TRUE))
  expect_true(grepl("kernR", desc[1L, "Suggests"], fixed = TRUE))
})

# ---------------------------------------------------------------
# Validation
# ---------------------------------------------------------------

test_that("malformed arguments are refused with a named cause", {
  d <- make_anm_identifiable(n = 40L)
  fit <- fit_of(d)
  expect_error(janusplot_direction(d, "x", "y"), "janusplot_fit")
  expect_error(janusplot_direction(fit, "x", "nope"),
               "not a fitted variable")
  expect_error(janusplot_direction(fit, "x", "x"), "different variables")
  expect_error(janusplot_direction(fit, "x", c("y", "y")),
               "single variable name")
  expect_error(janusplot_direction(fit, "x", "y", alpha = 0),
               "strictly between 0 and 1")
  expect_error(janusplot_direction(fit, "x", "y", gaussian_alpha = 1),
               "strictly between 0 and 1")
  expect_error(janusplot_direction(fit, "x", "y", linear_tol = -0.1),
               "strictly between 0 and 1")
  expect_error(janusplot_direction(fit, "x", "y", n_permutations = 10L),
               "at least 99")
  expect_error(janusplot_direction(fit, "x", "y", seed = "one"),
               "single number")
})

test_that("the alias refuses malformed arguments with a named cause", {
  d <- make_anm_identifiable(n = 40L)
  alias_error <- function(..., regexp) {
    lifecycle::expect_deprecated(
      expect_error(janusplot_direction_test(...), regexp)
    )
  }
  alias_error(list(a = 1), "x", "y", regexp = "data frame")
  alias_error(d, "x", "nope", regexp = "not found")
  alias_error(d, "x", "x", regexp = "different columns")
  alias_error(d, "x", c("y", "y"), regexp = "single column name")
  alias_error(d, "x", "y", alpha = 0, regexp = "strictly between 0 and 1")
  alias_error(d, "x", "y", gaussian_alpha = 1,
              regexp = "strictly between 0 and 1")
  alias_error(d, "x", "y", linear_tol = -0.1,
              regexp = "strictly between 0 and 1")
  alias_error(d, "x", "y", n_permutations = 10L, regexp = "at least 99")
  alias_error(d, "x", "y", seed = "one", regexp = "single number")
  alias_error(d, "x", "y", k = "ten", regexp = "single number")
  alias_error(d, "x", "y", bs = 1, regexp = "single basis name")
})

test_that("the alias refuses a non-numeric column", {
  d <- make_anm_identifiable(n = 40L)
  d$g <- rep(letters[1:4], length.out = nrow(d))
  lifecycle::expect_deprecated(
    expect_error(janusplot_direction_test(d, "x", "g"), "not numeric")
  )
})

test_that("a factor column is not a fitted variable of the fit", {
  d <- make_anm_identifiable(n = 40L)
  d$g <- factor(rep(letters[1:4], length.out = nrow(d)))
  expect_error(janusplot_direction(fit_of(d), "x", "g"),
               "not a fitted variable")
})

test_that("too few complete cases declines as an orchestra refusal", {
  d <- make_anm_identifiable(n = 40L)[seq_len(12L), , drop = FALSE]
  expect_error(
    janusplot_direction(fit_of(d), "x", "y"),
    class = "orchestra_refusal"
  )
  lifecycle::expect_deprecated(expect_error(
    janusplot_direction_test(d, "x", "y"),
    class = "orchestra_refusal"
  ))
})

test_that("incomplete rows are dropped pairwise before fitting", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  d$y[seq_len(10L)] <- NA_real_
  res <- janusplot_direction(fit_of(d), "x", "y",
                             n_permutations = 199L, seed = 7L)
  expect_identical(res$n, 290L)
})

# ---------------------------------------------------------------
# Guards on n
# ---------------------------------------------------------------

test_that("a sample below n_min abstains with the reason stated", {
  d <- make_anm_identifiable(n = 25L)
  res <- janusplot_direction(fit_of(d), "x", "y", n_permutations = 199L,
                             seed = 1L)
  expect_identical(res$verdict, "undecided")
  expect_identical(res$reason_code, "n_below_min")
  expect_identical(res$reason, "n below n_min")
  expect_identical(res$n, 25L)
  expect_identical(res$n_used, 25L)
  expect_true(is.na(res$p_forward))
  expect_true(is.na(res$p_reverse))
  expect_identical(res$n_min, 30L)
})

test_that("a sample above n_max is subsampled reproducibly", {
  skip_if_no_kernR()
  d <- make_anm_identifiable(n = 300L)
  a <- janusplot_direction(fit_of(d), "x", "y", n_permutations = 199L,
                           n_max = 120L, seed = 3L)
  b <- janusplot_direction(fit_of(d), "x", "y", n_permutations = 199L,
                           n_max = 120L, seed = 3L)
  expect_identical(a$n, 300L)
  expect_identical(a$n_used, 120L)
  expect_identical(a$n_max, 120L)
  expect_identical(a$edf_forward, b$edf_forward)
  expect_identical(a$p_forward, b$p_forward)
})

test_that("the subsample without a seed is fixed and leaves the RNG alone", {
  skip_if_no_kernR()
  d <- make_anm_identifiable(n = 300L)
  withr::local_seed(42L)
  before <- .Random.seed
  a <- .direction_subsample(d, n_max = 120L, seed = NULL)
  expect_identical(.Random.seed, before)
  b <- .direction_subsample(d, n_max = 120L, seed = NULL)
  expect_identical(a, b)
  expect_identical(nrow(a), 120L)
})

test_that("n_used equals the complete cases when no guard applies", {
  skip_if_no_kernR()
  d <- make_anm_identifiable(n = 60L)
  res <- janusplot_direction(fit_of(d), "x", "y", n_permutations = 199L,
                             seed = 2L)
  expect_identical(res$n_used, 60L)
  expect_identical(res$n_max, 2000L)
})

test_that("malformed n guards are refused", {
  d <- make_anm_identifiable(n = 40L)
  expect_error(janusplot_direction(fit_of(d), "x", "y", n_min = 0L),
               "n_min")
  expect_error(janusplot_direction(fit_of(d), "x", "y", n_max = 10L),
               "n_max")
  expect_error(janusplot_direction(fit_of(d), "x", "y", n_min = 50L,
                                        n_max = 40L),
               "n_max")
})

# ---------------------------------------------------------------
# Non-syntactic column names
# ---------------------------------------------------------------

test_that("column names with spaces and symbols are handled", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  ref <- janusplot_direction(fit_of(d), "x", "y", n_permutations = 199L,
                             seed = 1L)
  names(d) <- c("grain yield (t/ha)", "protein %")
  res <- janusplot_direction(fit_of(d), "grain yield (t/ha)", "protein %",
                             n_permutations = 199L, seed = 1L)
  expect_identical(res$verdict, ref$verdict)
  expect_identical(res$p_forward, ref$p_forward)
  expect_identical(res$x, "grain yield (t/ha)")
  expect_identical(res$y, "protein %")
  expect_identical(res$forward, "grain yield (t/ha) -> protein %")
  expect_match(res$reason, "grain yield (t/ha)", fixed = TRUE)
  expect_false(grepl("janus_", res$reason, fixed = TRUE))
})

# ---------------------------------------------------------------
# Internals the verdict rests on
# ---------------------------------------------------------------

test_that("the curvature measure separates a line from a curve", {
  xs <- seq(-3, 3, length.out = 200L)
  expect_equal(.smooth_curvature(2 * xs + 1, xs, xs), 0, tolerance = 1e-10)
  expect_equal(.smooth_curvature(rep(4, 200L), xs, xs), 0)
  expect_gt(.smooth_curvature(xs^2, xs, xs), 0.9)
})

test_that("the normality probe reports a constant vector as non-Gaussian", {
  expect_identical(.normality_pvalue(rep(1, 50L)), 0)
  expect_identical(.normality_pvalue(c(1, NA_real_)), NA_real_)
  expect_gt(.normality_pvalue(withr::with_seed(1L, stats::rnorm(200L))), 0.01)
  expect_lt(.normality_pvalue(withr::with_seed(1L, stats::runif(200L))), 0.01)
})

# ---------------------------------------------------------------
# janusplot_direction() on the fit against the alias on the data
# ---------------------------------------------------------------

test_that("the fit entry point and the alias give identical results", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  via_fit <- janusplot_direction(fit_of(d), "x", "y", seed = 2026L)
  lifecycle::expect_deprecated(
    via_alias <- janusplot_direction_test(d, "x", "y", seed = 2026L)
  )
  expect_s3_class(via_fit, "janusplot_direction")
  expect_s3_class(via_alias, "janusplot_direction")
  expect_identical(via_fit$verdict, via_alias$verdict)
  expect_identical(via_fit$reason_code, via_alias$reason_code)
  expect_identical(via_fit$p_forward, via_alias$p_forward)
  expect_identical(via_fit$p_reverse, via_alias$p_reverse)
  expect_identical(via_fit$edf_forward, via_alias$edf_forward)
  expect_identical(via_fit$edf_reverse, via_alias$edf_reverse)
  expect_identical(via_fit, via_alias)
})

test_that("swapping x and y swaps the forward and reverse quantities", {
  skip_if_no_kernR()
  fit <- fit_of(make_anm_identifiable())
  xy <- janusplot_direction(fit, "x", "y", n_permutations = 199L, seed = 4L)
  yx <- janusplot_direction(fit, "y", "x", n_permutations = 199L, seed = 4L)
  expect_identical(xy$forward, yx$reverse)
  expect_identical(xy$reverse, yx$forward)
  expect_identical(xy$edf_forward, yx$edf_reverse)
  expect_identical(xy$edf_reverse, yx$edf_forward)
  expect_identical(xy$statistic_forward, yx$statistic_reverse)
  expect_identical(xy$curvature_forward, yx$curvature_reverse)
  expect_identical(xy$verdict, "forward")
  expect_identical(yx$verdict, "reverse")
})

test_that("the basis dimension of each direction comes from the fit", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  fit <- fit_of(d, k = 5L)
  res <- janusplot_direction(fit, "x", "y", n_permutations = 199L,
                             seed = 4L)
  lifecycle::expect_deprecated(
    ref <- janusplot_direction_test(d, "x", "y", k = 5L,
                                    n_permutations = 199L, seed = 4L)
  )
  expect_identical(res$edf_forward, ref$edf_forward)
  expect_lt(res$edf_forward, 4)
})

test_that("kept fits are reused and equal the refit", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  refit <- janusplot_direction(fit_of(d), "x", "y", n_permutations = 199L,
                               seed = 6L)
  kept_fit <- fit_of(d, keep_fits = TRUE)
  local_mocked_bindings(
    .direction_fit = function(...) stop("refit on the kept-fits path")
  )
  kept <- janusplot_direction(kept_fit, "x", "y", n_permutations = 199L,
                              seed = 6L)
  expect_identical(kept, refit)
})

test_that("kept fits are not reused when the rows are subsampled", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  kept_fit <- fit_of(d, keep_fits = TRUE)
  res <- janusplot_direction(kept_fit, "x", "y", n_permutations = 199L,
                             n_max = 120L, seed = 3L)
  expect_identical(res$n_used, 120L)
})

test_that("an adjusted fit says the adjust terms are left out", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  d$site <- factor(rep(c("a", "b", "c"), length.out = nrow(d)))
  fit <- fit_of(d, vars = c("x", "y"), adjust = ~ s(site, bs = "re"))
  expect_message(
    res <- janusplot_direction(fit, "x", "y", n_permutations = 199L,
                               seed = 7L),
    "bivariate"
  )
  expect_identical(res$n, fit$pairs[[1L]]$n_used)
})

test_that("a bam fit runs and records the gam method", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  fit <- janusplot_fit(d, derivatives = integer())
  expect_identical(fit$settings$method, "fREML")
  res <- janusplot_direction(fit, "x", "y", n_permutations = 199L,
                             seed = 7L)
  expect_identical(res$method, "REML")
  expect_identical(res$verdict, "forward")
})

test_that("a gam fit passes its own method", {
  skip_if_no_kernR()
  fit <- fit_of(make_anm_identifiable(), method = "ML")
  res <- janusplot_direction(fit, "x", "y", n_permutations = 199L,
                             seed = 7L)
  expect_identical(res$method, "ML")
})

test_that("n below n_min abstains through the fit entry point", {
  fit <- fit_of(make_anm_identifiable(n = 40L))
  res <- janusplot_direction(fit, "x", "y", n_min = 50L, n_max = 100L)
  expect_s3_class(res, "janusplot_direction")
  expect_identical(res$reason_code, "n_below_min")
  expect_identical(res$n, 40L)
  expect_identical(res$n_min, 50L)
  expect_true(is.na(res$edf_forward))
})

test_that("the alias warns once per call and returns the classed object", {
  d <- make_anm_identifiable(n = 25L)
  lifecycle::expect_deprecated(
    res <- janusplot_direction_test(d, "x", "y"),
    "janusplot_direction"
  )
  expect_s3_class(res, "janusplot_direction")
  expect_identical(res$reason_code, "n_below_min")
})

test_that("print() states the verdict, reason, p-values and rows", {
  skip_if_no_kernR()
  fit <- fit_of(make_anm_identifiable())
  res <- janusplot_direction(fit, "x", "y", n_permutations = 199L,
                             seed = 7L)
  expect_snapshot(print(res))
  below <- janusplot_direction(fit_of(make_anm_identifiable(n = 25L)),
                               "x", "y")
  expect_snapshot(print(below))
  expect_output(shown <- withVisible(print(below)), "n_below_min")
  expect_false(shown$visible)
})

test_that("both_independent separates an associated pair from no association", {
  withr::local_seed(2026L)
  x <- stats::rnorm(120L)
  assoc <- janusplot:::.both_independent_reason(0.4, 0.6, x,
                                                x + stats::rnorm(120L), 0.05)
  expect_match(assoc, "associated \\(r = ")
  expect_match(assoc, "direction is not identified")
  none <- janusplot:::.both_independent_reason(0.4, 0.6, x,
                                               stats::rnorm(120L), 0.05)
  expect_match(none, "no association between them")
  expect_no_match(none, "associated \\(r")
})

test_that("the adjust inform states the rows used", {
  skip_if_no_kernR()
  withr::local_seed(2026L)
  d <- data.frame(x = stats::rnorm(120L))
  d$y <- 0.5 * d$x + stats::rnorm(120L)
  d$g <- factor(rep(c("a", "b", "c"), length.out = 120L))
  d$g[1:15] <- NA
  fit <- suppressMessages(fit_of(d, vars = c("x", "y"), adjust = ~ g))
  msgs <- testthat::capture_messages(
    janusplot_direction(fit, "x", "y", n_permutations = 99L, seed = 7L)
  )
  expect_true(any(grepl("105 rows", msgs)))
  expect_true(any(grepl("missing an", msgs)))
})
