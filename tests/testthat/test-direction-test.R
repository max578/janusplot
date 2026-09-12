# Known-truth oracle tests for janusplot_direction_test().
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
  res <- janusplot_direction_test(d, "x", "y",
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
  res <- janusplot_direction_test(d, "y", "x",
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
  res <- janusplot_direction_test(d, "x", "y",
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
  res <- janusplot_direction_test(d, "y", "x",
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
  res <- janusplot_direction_test(d, "x", "y",
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
    res <- janusplot_direction_test(d, "x", "y",
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
    res <- janusplot_direction_test(d, "x", "y",
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
  res <- janusplot_direction_test(d, "x", "y",
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
  a <- janusplot_direction_test(d, "x", "y", n_permutations = 199L, seed = 9L)
  b <- janusplot_direction_test(d, "x", "y", n_permutations = 199L, seed = 9L)
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
    janusplot_direction_test(d, "x", "y"),
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
  expect_error(janusplot_direction_test(list(a = 1), "x", "y"), "data frame")
  expect_error(janusplot_direction_test(d, "x", "nope"), "not found")
  expect_error(janusplot_direction_test(d, "x", "x"), "different columns")
  expect_error(janusplot_direction_test(d, "x", c("y", "y")),
               "single column name")
  expect_error(janusplot_direction_test(d, "x", "y", alpha = 0),
               "strictly between 0 and 1")
  expect_error(janusplot_direction_test(d, "x", "y", gaussian_alpha = 1),
               "strictly between 0 and 1")
  expect_error(janusplot_direction_test(d, "x", "y", linear_tol = -0.1),
               "strictly between 0 and 1")
  expect_error(janusplot_direction_test(d, "x", "y", n_permutations = 10L),
               "at least 99")
  expect_error(janusplot_direction_test(d, "x", "y", seed = "one"),
               "single number")
})

test_that("a non-numeric column is refused", {
  d <- make_anm_identifiable(n = 40L)
  d$g <- rep(letters[1:4], length.out = nrow(d))
  expect_error(janusplot_direction_test(d, "x", "g"), "not numeric")
})

test_that("too few complete cases declines as an orchestra refusal", {
  d <- make_anm_identifiable(n = 40L)[seq_len(12L), , drop = FALSE]
  expect_error(
    janusplot_direction_test(d, "x", "y"),
    class = "orchestra_refusal"
  )
})

test_that("incomplete rows are dropped pairwise before fitting", {
  skip_if_no_kernR()
  d <- make_anm_identifiable()
  d$y[seq_len(10L)] <- NA_real_
  res <- janusplot_direction_test(d, "x", "y",
                                  n_permutations = 199L, seed = 7L)
  expect_identical(res$n, 290L)
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
