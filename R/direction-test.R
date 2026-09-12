# Residual-independence test for a directional claim.
#
# janusplot()'s asymmetry index is a diagnostic: it reports that the two
# directions of fit differ, not that one of them is the causal one. Under
# the additive-noise-model (ANM) identifiability result, a direction is
# supported only when the residuals of the fit in that direction are
# independent of the putative cause AND the residuals of the fit in the
# opposite direction are not. This file adds that test, so the package can
# say whether the condition that licenses a directional reading actually
# holds.
#
# Exposed publicly via janusplot_direction_test(). Internals are
# dot-prefixed.

# ---------------------------------------------------------------
# Optional-dependency probe. Isolated in its own function so the
# missing-kernR path can be exercised in tests without uninstalling
# anything.
# ---------------------------------------------------------------

.kernR_available <- function() {
  requireNamespace("kernR", quietly = TRUE)
}

# ---------------------------------------------------------------
# Departure of a fitted smooth from a straight line, in [0, 1].
#
# For a simple regression of the fitted values on the predictor,
# R^2 == cor(fitted, x)^2, so 1 - cor(fitted, x)^2 is the share of the
# fitted variation that no straight line in x can reproduce. A smooth
# with no variation to explain (a flat fit) is a straight line of zero
# slope, so it scores 0 rather than an undefined correlation.
# ---------------------------------------------------------------

.smooth_curvature <- function(fitted_values, x_values, y_values) {
  sd_fit <- stats::sd(fitted_values)
  sd_y   <- stats::sd(y_values)
  if (!is.finite(sd_fit) || !is.finite(sd_y)) return(NA_real_)
  if (sd_fit <= 1e-6 * sd_y) return(0)
  r <- stats::cor(fitted_values, x_values)
  if (!is.finite(r)) return(NA_real_)
  1 - r^2
}

# ---------------------------------------------------------------
# Shapiro-Wilk p-value. The test itself is defined for 3 to 5000
# observations; longer vectors are thinned on a deterministic
# equally-spaced index so the answer is reproducible without a seed.
# A constant vector is not Gaussian and is reported as p = 0 rather
# than allowed to error inside stats::shapiro.test().
# ---------------------------------------------------------------

.normality_pvalue <- function(v) {
  v <- v[is.finite(v)]
  n <- length(v)
  if (n < 3L) return(NA_real_)
  if (n > 5000L) v <- v[round(seq(1, n, length.out = 5000L))]
  if (stats::sd(v) <= 0) return(0)
  stats::shapiro.test(v)$p.value
}

# ---------------------------------------------------------------
# Fit one direction and return everything the verdict needs.
# ---------------------------------------------------------------

.direction_fit <- function(dat, x_name, y_name, k, bs, method) {
  fml <- .build_formula(y_name, x_name, .resolve_k(k, x_name), bs, NULL)
  resolved_method <- if (is.null(method) || identical(method, "auto") ||
                         identical(method, "default")) {
    .engine_default_method("gam")
  } else {
    method
  }
  fit <- .fit_one_gam(fml, dat,
                      engine = "gam", method = resolved_method,
                      discrete = FALSE, nthreads = 1L)
  smry  <- summary(fit)
  s_row <- which(rownames(smry$s.table) == sprintf("s(%s)", x_name))[1L]
  if (is.na(s_row)) s_row <- 1L
  list(
    fit       = fit,
    residuals = as.numeric(stats::residuals(fit, type = "response")),
    edf       = unname(smry$s.table[s_row, "edf"]),
    curvature = .smooth_curvature(
      as.numeric(stats::fitted(fit)), dat[[x_name]], dat[[y_name]]
    ),
    method    = resolved_method
  )
}

# ---------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------

#' Test whether the residual-independence condition licenses a direction
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' [janusplot()] renders a pair twice -- `y ~ s(x)` in one triangle and
#' `x ~ s(y)` in the other -- and summarises the difference between the
#' two fits as an asymmetry index. That index is a *diagnostic*: it says
#' the two directions of fit are not interchangeable, not that either one
#' is the causal direction.
#'
#' This function runs the test that turns the picture into a claim. Under
#' the additive-noise model `y = f(x) + e` with `e` independent of `x`,
#' the model holds in at most one direction for all but a small set of
#' exceptional joint distributions. So a direction is supported when
#'
#' * the residuals of the fit in that direction are independent of the
#'   putative cause, **and**
#' * the residuals of the fit in the opposite direction are not.
#'
#' Independence is assessed with the kernel (HSIC) permutation test in
#' `kernR::hsic_test()`. Anything other than the clean one-sided pattern
#' -- both directions admitting an additive-noise model, neither doing
#' so, or the known non-identifiable linear-Gaussian case -- returns
#' `"undecided"`. The smaller of the two p-values is never read as a
#' direction.
#'
#' @details
#' ## The linear-Gaussian exception
#'
#' Identifiability fails exactly when the relationship is linear and both
#' the cause and the noise are Gaussian: a bivariate Gaussian is
#' reproduced perfectly by a linear model with Gaussian noise in either
#' direction, so the residual-independence condition holds both ways and
#' carries no directional information. This case is detected before the
#' two independence tests are read, and returns `"undecided"` with
#' `reason_code = "linear_gaussian"`. It is flagged when *both* of the
#' following hold:
#'
#' * **Linearity.** Each fitted smooth departs from a straight line by
#'   less than `linear_tol`, measured as `1 - cor(fitted, x)^2` -- the
#'   share of the fitted variation that no straight line in the predictor
#'   can reproduce.
#' * **Gaussianity.** Shapiro-Wilk applied to `x`, `y`, and both residual
#'   vectors fails to reject normality at `gaussian_alpha` in all four
#'   cases.
#'
#' `gaussian_alpha` defaults to `0.01`, not `0.05`: the consequence of
#' the flag is abstention, so the threshold is set to withhold a
#' directional claim unless the data argue clearly against Gaussianity.
#'
#' ## Reading the result
#'
#' A `"forward"` or `"reverse"` verdict states that the condition
#' licensing that direction holds on this sample. It is not a proof of
#' causation: the additive-noise model assumes no unobserved common
#' cause, no feedback, and additive noise, and none of those assumptions
#' is testable from the pair alone.
#'
#' @param data A data frame containing both variables.
#' @param x Character. Column name of the first variable -- the putative
#'   cause under the forward hypothesis.
#' @param y Character. Column name of the second variable -- the putative
#'   effect under the forward hypothesis.
#' @param k Basis dimension passed to [mgcv::s()]. Default `-1L` lets
#'   `mgcv` choose.
#' @param bs Character. Spline basis passed to [mgcv::s()]. Default
#'   `"tp"` (thin-plate regression spline).
#' @param method Smoothing-parameter selection method passed to
#'   [mgcv::gam()]. `NULL` (default) uses `"REML"`.
#' @param alpha Numeric in `(0, 1)`. Significance level for the two
#'   residual-independence tests. Residuals are called independent when
#'   the HSIC p-value exceeds `alpha`. Default `0.05`.
#' @param n_permutations Integer. Permutations used to build each HSIC
#'   null distribution. Must be at least `99` -- the smallest attainable
#'   p-value is `1 / (n_permutations + 1)`. Default `500L`.
#' @param linear_tol Numeric in `(0, 1)`. A fitted smooth counts as a
#'   straight line when `1 - cor(fitted, x)^2` falls below this value.
#'   Default `0.01`.
#' @param gaussian_alpha Numeric in `(0, 1)`. Significance level for the
#'   four Shapiro-Wilk normality tests used by the linear-Gaussian
#'   detector. Default `0.01`.
#' @param seed Integer or `NULL`. Seed for the HSIC permutation draws.
#'   The reverse direction is seeded at `seed + 1` so the two null
#'   distributions are not drawn from the same permutation sequence.
#'
#' @returns A named list:
#'   \describe{
#'     \item{`verdict`}{One of `"forward"` (`x` drives `y`),
#'       `"reverse"` (`y` drives `x`), or `"undecided"`.}
#'     \item{`reason_code`}{Machine-readable ground for the verdict:
#'       `"forward_only"`, `"reverse_only"`, `"both_independent"`,
#'       `"neither_independent"`, or `"linear_gaussian"`.}
#'     \item{`reason`}{One-paragraph statement of the same ground.}
#'     \item{`x`, `y`}{The column names, as supplied.}
#'     \item{`forward`, `reverse`}{The two hypotheses as printable
#'       strings, e.g. `"x -> y"`.}
#'     \item{`p_forward`, `p_reverse`}{HSIC permutation p-values for
#'       residual-versus-cause independence in each direction.}
#'     \item{`statistic_forward`, `statistic_reverse`}{The two observed
#'       HSIC statistics.}
#'     \item{`independent_forward`, `independent_reverse`}{Whether each
#'       p-value exceeds `alpha`.}
#'     \item{`edf_forward`, `edf_reverse`}{Effective degrees of freedom
#'       of each fitted smooth.}
#'     \item{`curvature_forward`, `curvature_reverse`}{Departure of each
#'       smooth from a straight line; see Details.}
#'     \item{`normality_p`}{Named numeric vector of the four
#'       Shapiro-Wilk p-values (`x`, `y`, `residuals_forward`,
#'       `residuals_reverse`).}
#'     \item{`linear_gaussian`}{`TRUE` when the non-identifiable
#'       linear-Gaussian case was detected.}
#'     \item{`n`}{Complete cases used.}
#'     \item{`alpha`, `gaussian_alpha`, `linear_tol`,
#'       `n_permutations`}{The settings the verdict was reached under.}
#'   }
#'
#' @references
#' Hoyer, P. O., Janzing, D., Mooij, J. M., Peters, J., &
#'   Scholkopf, B. (2009). Nonlinear causal discovery with additive
#'   noise models. *Advances in Neural Information Processing Systems*,
#'   **21**, 689-696.
#'
#' Gretton, A., Fukumizu, K., Teo, C. H., Song, L., Scholkopf, B., &
#'   Smola, A. J. (2008). A kernel statistical test of independence.
#'   *Advances in Neural Information Processing Systems*, **20**,
#'   585-592.
#'
#' Shimizu, S., Hoyer, P. O., Hyvarinen, A., & Kerminen, A. (2006). A
#'   linear non-Gaussian acyclic model for causal discovery. *Journal of
#'   Machine Learning Research*, **7**, 2003-2030.
#'
#' @seealso [janusplot()], [janusplot_data()].
#'
#' @examples
#' if (requireNamespace("kernR", quietly = TRUE)) {
#'   # x drives y through a non-linear function with non-Gaussian noise:
#'   # the additive-noise model is identifiable here.
#'   set.seed(2026L)
#'   n <- 200L
#'   x <- stats::runif(n, -3, 3)
#'   y <- x^3 / 5 + stats::runif(n, -1, 1)
#'   d <- data.frame(x = x, y = y)
#'
#'   res <- janusplot_direction_test(d, "x", "y", n_permutations = 199L,
#'                                   seed = 1L)
#'   res$verdict      # "forward"
#'   res$reason
#'   c(forward = res$p_forward, reverse = res$p_reverse)
#'
#'   # The same pair read the other way round returns "reverse".
#'   janusplot_direction_test(d, "y", "x", n_permutations = 199L,
#'                            seed = 1L)$verdict
#' }
#' @export
janusplot_direction_test <- function(data, x, y,
                                     k              = -1L,
                                     bs             = "tp",
                                     method         = NULL,
                                     alpha          = 0.05,
                                     n_permutations = 500L,
                                     linear_tol     = 0.01,
                                     gaussian_alpha = 0.01,
                                     seed           = NULL) {
  .validate_direction_args(
    data, x, y, k, bs, alpha, n_permutations, linear_tol, gaussian_alpha, seed
  )

  dat <- .complete_pair(data, x, y, NULL)
  n_used <- nrow(dat)
  if (n_used < 20L) {
    # Well-typed arguments, but the method's own requirement -- enough
    # complete cases to fit two smooths and permute a kernel statistic
    # over their residuals -- is not met. Declines with a classed
    # condition rather than returning a verdict it cannot support.
    cli::cli_abort(
      c(
        "{.arg data} has {n_used} complete case{?s} on {.val {x}} and {.val {y}}.",
        i = "At least 20 are needed to fit both directions and permute the HSIC null."
      ),
      class = c("janusplot_refusal", "orchestra_refusal")
    )
  }
  if (!.kernR_available()) {
    cli::cli_abort(c(
      "{.pkg kernR} is required for {.fn janusplot_direction_test}.",
      i = paste(
        "The residual-independence test is",
        "{.fn kernR::hsic_test}; without it the direction cannot be",
        "licensed, only its fit asymmetry described by {.fn janusplot}."
      ),
      i = "Install with {.code pak::pak(\"max578/kernR\")}."
    ))
  }

  forward <- .direction_fit(dat, x, y, k, bs, method)
  reverse <- .direction_fit(dat, y, x, k, bs, method)

  seed_forward <- if (is.null(seed)) NULL else as.integer(seed)
  seed_reverse <- if (is.null(seed)) NULL else as.integer(seed) + 1L
  hsic_forward <- kernR::hsic_test(
    forward$residuals, dat[[x]],
    n_permutations = as.integer(n_permutations),
    alpha = alpha, seed = seed_forward
  )
  hsic_reverse <- kernR::hsic_test(
    reverse$residuals, dat[[y]],
    n_permutations = as.integer(n_permutations),
    alpha = alpha, seed = seed_reverse
  )

  independent_forward <- hsic_forward$p_value > alpha
  independent_reverse <- hsic_reverse$p_value > alpha

  normality_p <- c(
    x                 = .normality_pvalue(dat[[x]]),
    y                 = .normality_pvalue(dat[[y]]),
    residuals_forward = .normality_pvalue(forward$residuals),
    residuals_reverse = .normality_pvalue(reverse$residuals)
  )
  both_linear <- is.finite(forward$curvature) &&
    is.finite(reverse$curvature) &&
    forward$curvature < linear_tol &&
    reverse$curvature < linear_tol
  all_gaussian <- all(is.finite(normality_p)) &&
    all(normality_p > gaussian_alpha)
  linear_gaussian <- both_linear && all_gaussian

  fwd_label <- sprintf("%s -> %s", x, y)
  rev_label <- sprintf("%s -> %s", y, x)

  # Dispatch order matters. The linear-Gaussian case is a structural
  # failure of identifiability, so it is read before the two independence
  # tests: in that regime both directions reproduce the joint
  # distribution exactly, and whichever p-value happens to come out
  # smaller carries no directional information at all.
  if (linear_gaussian) {
    verdict     <- "undecided"
    reason_code <- "linear_gaussian"
    reason <- paste0(
      "Both fits are straight lines, and ", x, ", ", y, " and both sets ",
      "of residuals are consistent with Gaussian distributions. The ",
      "additive-noise model is not identifiable in the linear-Gaussian ",
      "case: a linear model with Gaussian noise reproduces this joint ",
      "distribution exactly in either direction, so the ",
      "residual-independence condition holds both ways and supports ",
      "neither direction."
    )
  } else if (independent_forward && !independent_reverse) {
    verdict     <- "forward"
    reason_code <- "forward_only"
    reason <- paste0(
      "Residuals of the fit ", fwd_label, " are independent of ", x,
      " (p = ", format(signif(hsic_forward$p_value, 3L)),
      "), while residuals of the fit ", rev_label, " remain dependent on ",
      y, " (p = ", format(signif(hsic_reverse$p_value, 3L)),
      "). The additive-noise model holds in the forward direction only."
    )
  } else if (independent_reverse && !independent_forward) {
    verdict     <- "reverse"
    reason_code <- "reverse_only"
    reason <- paste0(
      "Residuals of the fit ", rev_label, " are independent of ", y,
      " (p = ", format(signif(hsic_reverse$p_value, 3L)),
      "), while residuals of the fit ", fwd_label, " remain dependent on ",
      x, " (p = ", format(signif(hsic_forward$p_value, 3L)),
      "). The additive-noise model holds in the reverse direction only."
    )
  } else if (independent_forward && independent_reverse) {
    verdict     <- "undecided"
    reason_code <- "both_independent"
    reason <- paste0(
      "Residuals are independent of the putative cause in both ",
      "directions (p = ", format(signif(hsic_forward$p_value, 3L)),
      " and ", format(signif(hsic_reverse$p_value, 3L)),
      "). An additive-noise model fits either way, which is what two ",
      "variables carrying no association between them also look like, ",
      "so neither direction is supported."
    )
  } else {
    verdict     <- "undecided"
    reason_code <- "neither_independent"
    reason <- paste0(
      "Residuals stay dependent on the putative cause in both ",
      "directions (p = ", format(signif(hsic_forward$p_value, 3L)),
      " and ", format(signif(hsic_reverse$p_value, 3L)),
      "). No additive-noise model fits this pair, so the premise the ",
      "directional test rests on does not hold here -- a hidden common ",
      "cause, feedback, or non-additive noise would all produce this."
    )
  }

  list(
    verdict             = verdict,
    reason_code         = reason_code,
    reason              = reason,
    x                   = x,
    y                   = y,
    forward             = fwd_label,
    reverse             = rev_label,
    p_forward           = hsic_forward$p_value,
    p_reverse           = hsic_reverse$p_value,
    statistic_forward   = hsic_forward$statistic,
    statistic_reverse   = hsic_reverse$statistic,
    independent_forward = independent_forward,
    independent_reverse = independent_reverse,
    edf_forward         = forward$edf,
    edf_reverse         = reverse$edf,
    curvature_forward   = forward$curvature,
    curvature_reverse   = reverse$curvature,
    normality_p         = normality_p,
    linear_gaussian     = linear_gaussian,
    n                   = n_used,
    alpha               = alpha,
    gaussian_alpha      = gaussian_alpha,
    linear_tol          = linear_tol,
    n_permutations      = as.integer(n_permutations)
  )
}

# ---------------------------------------------------------------
# Argument validation for janusplot_direction_test()
# ---------------------------------------------------------------

.check_unit_interval <- function(value, arg_name, call) {
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value) ||
      value <= 0 || value >= 1) {
    cli::cli_abort(
      "{.arg {arg_name}} must be a single number strictly between 0 and 1.",
      call = call
    )
  }
  invisible(NULL)
}

.validate_direction_args <- function(data, x, y, k, bs, alpha, n_permutations,
                                     linear_tol, gaussian_alpha, seed,
                                     call = rlang::caller_env()) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.", call = call)
  }
  for (nm in c("x", "y")) {
    value <- if (identical(nm, "x")) x else y
    if (!is.character(value) || length(value) != 1L || is.na(value)) {
      cli::cli_abort(
        "{.arg {nm}} must be a single column name.",
        call = call
      )
    }
  }
  if (identical(x, y)) {
    cli::cli_abort(
      "{.arg x} and {.arg y} must name two different columns.",
      call = call
    )
  }
  missing_cols <- setdiff(c(x, y), names(data))
  if (length(missing_cols)) {
    cli::cli_abort(
      "Column{?s} not found in {.arg data}: {.val {missing_cols}}.",
      call = call
    )
  }
  non_numeric <- c(x, y)[!vapply(data[, c(x, y), drop = FALSE],
                                 is.numeric, logical(1L))]
  if (length(non_numeric)) {
    cli::cli_abort(
      c(
        "Column{?s} {.val {non_numeric}} {?is/are} not numeric.",
        i = "The additive-noise model is defined for continuous variables."
      ),
      call = call
    )
  }
  if (!is.numeric(k) || length(k) != 1L || !is.finite(k)) {
    cli::cli_abort("{.arg k} must be a single number.", call = call)
  }
  if (!is.character(bs) || length(bs) != 1L || is.na(bs)) {
    cli::cli_abort("{.arg bs} must be a single basis name.", call = call)
  }
  .check_unit_interval(alpha, "alpha", call)
  .check_unit_interval(linear_tol, "linear_tol", call)
  .check_unit_interval(gaussian_alpha, "gaussian_alpha", call)
  if (!is.numeric(n_permutations) || length(n_permutations) != 1L ||
      !is.finite(n_permutations) || n_permutations < 99) {
    cli::cli_abort(
      c(
        "{.arg n_permutations} must be a single number of at least 99.",
        i = "The smallest attainable p-value is 1 / (n_permutations + 1)."
      ),
      call = call
    )
  }
  if (!is.null(seed) &&
      (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed))) {
    cli::cli_abort(
      "{.arg seed} must be a single number or {.code NULL}.",
      call = call
    )
  }
  invisible(NULL)
}
