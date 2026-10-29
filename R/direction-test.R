# Residual-independence test for a directional claim.
#
# The asymmetry index of a fit is a diagnostic: it reports that the two
# directions of fit differ, not that one of them is the causal one. Under
# the additive-noise-model (ANM) identifiability result, a direction is
# supported only when the residuals of the fit in that direction are
# independent of the putative cause AND the residuals of the fit in the
# opposite direction are not. This file adds that test, so the package can
# say whether the condition that licenses a directional reading actually
# holds.
#
# Exposed publicly via janusplot_direction() on a janusplot_fit, with
# janusplot_direction_test() kept as a deprecated alias on a data frame.
# Both call .direction_engine(). Internals are dot-prefixed.

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
# Row subsample for the n x n kernel matrices. Drawn with `seed`, or
# with 2026 when `seed` is NULL, so the subsample is reproducible
# either way; the global RNG state is restored afterwards. Rows keep
# their original order.
# ---------------------------------------------------------------

.direction_subsample <- function(dat, n_max, seed) {
  n <- nrow(dat)
  if (n <= n_max) return(dat)
  sub_seed <- if (is.null(seed)) 2026L else as.integer(seed)
  idx <- .with_preserved_seed({
    set.seed(sub_seed)
    sort(sample.int(n, n_max))
  })
  dat[idx, , drop = FALSE]
}
# ---------------------------------------------------------------
# Fit one direction and return everything the verdict needs.
# ---------------------------------------------------------------

.direction_fit <- function(dat, x_name, y_name, k, bs, method) {
  fml <- .build_formula(y_name, x_name, .resolve_k(k, x_name), bs, NULL)
  resolved_method <- .resolve_method(method, "gam")
  model <- .fit_one_gam(fml, dat,
                        engine = "gam", method = resolved_method,
                        discrete = FALSE, nthreads = 1L)
  .direction_summary(model, dat[[x_name]], dat[[y_name]], resolved_method)
}

# The residuals, EDF and curvature of one fitted direction. The model
# has a single smooth term, the first row of its s.table.
.direction_summary <- function(model, x_values, y_values, method) {
  smry <- summary(model)
  list(
    fit       = model,
    residuals = as.numeric(stats::residuals(model, type = "response")),
    edf       = unname(smry$s.table[1L, "edf"]),
    curvature = .smooth_curvature(
      as.numeric(stats::fitted(model)), x_values, y_values
    ),
    method    = method
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
#' [janusplot_pair()] draws a pair twice -- `y ~ s(x)` on the left and
#' `x ~ s(y)` on the right -- and the fit summarises the difference
#' between the two directions as an asymmetry index. That index is a
#' *diagnostic*: it says the two directions of fit are not
#' interchangeable, not that either one is the causal direction.
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
#' ## What the fit supplies
#'
#' The rows are those the pair was fitted on in `fit`: complete on `x`,
#' `y` and the `adjust` variables, so `n` equals the pair's `n_used`.
#' Each direction is fitted with the basis dimension that direction used
#' in `fit` (`k_used_yx` or `k_used_xy` of the pair) and the basis type
#' `fit$settings$bs`, so the verdict rests on the smooths the matrix
#' draws.
#'
#' Both directions are fitted with [mgcv::gam()]. A fit made with
#' `engine = "gam"` passes its `method`; a fit made with `engine = "bam"`
#' carries a [mgcv::bam()] method such as `"fREML"`, so the test uses the
#' [mgcv::gam()] default `"REML"` instead. The method used is returned as
#' `method`.
#'
#' The test is bivariate. When `fit` was made with an `adjust` formula,
#' the adjust terms do not enter the two direction fits and a message
#' says so; only the rows they select carry over.
#'
#' When `fit` keeps its models (`keep_fits = TRUE`), was made with
#' `engine = "gam"` and no `adjust` formula, and `n` does not exceed
#' `n_max`, the residuals, EDFs and fitted values of the two kept models
#' are used without refitting. The result is the same as a refit.
#'
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
#' @param fit A `janusplot_fit` object from [janusplot_fit()].
#' @param x Character. Name of the first variable, one of `fit$vars` --
#'   the putative cause under the forward hypothesis. For `print()`, a
#'   `janusplot_direction` object.
#' @param y Character. Name of the second variable, one of `fit$vars` --
#'   the putative effect under the forward hypothesis. Names need not be
#'   syntactic: names with spaces or symbols are returned and reported as
#'   supplied.
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
#'   Also seeds the row subsample taken when the complete cases exceed
#'   `n_max`; with `seed = NULL` that subsample uses seed `2026`, so it
#'   is reproducible in both cases. The subsample does not change the
#'   global random-number state.
#' @param n_min Integer. Smallest number of complete cases on which a
#'   verdict is given. Below it the function returns `"undecided"` with
#'   `reason_code = "n_below_min"` and `reason = "n below n_min"`,
#'   without fitting or testing. Default `30L`. Samples below 20
#'   complete cases are refused with an error whatever `n_min` is.
#' @param n_max Integer. Largest number of rows used for the fits and
#'   the HSIC tests, which build `n` by `n` kernel matrices. Above it a
#'   random subsample of `n_max` rows is drawn (see `seed`). Default
#'   `2000L`. The HSIC verdict depends on `n`: with more rows the test
#'   detects smaller departures from independence, so verdicts at
#'   different `n` are not directly comparable.
#'
#' @returns A list of class `janusplot_direction`, printed as the
#'   verdict, its reason, the two p-values and the rows used:
#'   \describe{
#'     \item{`verdict`}{One of `"forward"` (`x` drives `y`),
#'       `"reverse"` (`y` drives `x`), or `"undecided"`.}
#'     \item{`reason_code`}{Machine-readable ground for the verdict:
#'       `"forward_only"`, `"reverse_only"`, `"both_independent"`,
#'       `"neither_independent"`, `"linear_gaussian"`, or
#'       `"n_below_min"`. For `"n_below_min"` the p-values, statistics,
#'       EDFs, curvatures and normality p-values are `NA`.}
#'     \item{`reason`}{One-paragraph statement of the same ground.}
#'     \item{`x`, `y`}{The variable names, as supplied.}
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
#'     \item{`n`}{Complete cases on `x` and `y`.}
#'     \item{`n_used`}{Rows used for the fits and tests: `n`, or
#'       `n_max` when `n` exceeds it.}
#'     \item{`alpha`, `gaussian_alpha`, `linear_tol`,
#'       `n_permutations`, `n_min`, `n_max`}{The settings the verdict
#'       was reached under.}
#'     \item{`method`}{The [mgcv::gam()] smoothing-parameter method of
#'       the two direction fits.}
#'   }
#'   `print()` returns its argument invisibly.
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
#' @family smooth-associations
#' @seealso [janusplot_fit()] for the fit, [janusplot_pair()] for the two
#'   directions drawn side by side.
#'
#' @examples
#' if (requireNamespace("kernR", quietly = TRUE)) {
#'   # x drives y through a non-linear function with non-Gaussian noise:
#'   # the additive-noise model is identifiable here.
#'   set.seed(2026L)
#'   n <- 200L
#'   x <- stats::runif(n, -3, 3)
#'   y <- x^3 / 5 + stats::runif(n, -1, 1)
#'   fit <- janusplot_fit(data.frame(x = x, y = y), engine = "gam")
#'
#'   res <- janusplot_direction(fit, "x", "y", n_permutations = 199L,
#'                              seed = 2026L)
#'   res
#'   c(forward = res$p_forward, reverse = res$p_reverse)
#'
#'   # The same pair read the other way round names the other direction.
#'   janusplot_direction(fit, "y", "x", n_permutations = 199L,
#'                       seed = 2026L)$verdict
#' }
#' @export
janusplot_direction <- function(
  fit,
  x,
  y,
  alpha = 0.05,
  n_permutations = 500L,
  linear_tol = 0.01,
  gaussian_alpha = 0.01,
  seed = NULL,
  n_min = 30L,
  n_max = 2000L
) {
  .check_fit_pair(fit, x, y)
  .validate_direction_settings(
    alpha, n_permutations, linear_tol, gaussian_alpha, seed
  )
  .validate_n_guards(n_min, n_max)

  # What the fit supplies: rows, basis, method ---------------------------
  pair <- fit$pairs[[.find_pair(fit, x, y)]]
  forward_dir <- if (identical(x, pair$var_i)) "yx" else "xy"
  reverse_dir <- if (forward_dir == "yx") "xy" else "yx"
  k_forward <- .direction_k(pair[[paste0("k_used_", forward_dir)]])
  k_reverse <- .direction_k(pair[[paste0("k_used_", reverse_dir)]])
  is_gam <- identical(fit$settings$engine, "gam")
  method <- if (is_gam) fit$settings$method else .engine_default_method("gam")
  if (!is.null(fit$adjust)) {
    adjust_txt <- paste(deparse(fit$adjust, width.cutoff = 500L), # nolint: object_usage_linter.
                        collapse = " ")
    cli::cli_inform(c(
      i = paste(
        "The direction test is bivariate: the {.arg adjust} terms of",
        "{.arg fit} ({.code {adjust_txt}}) do not enter the two fits."
      )
    ))
  }
  rows <- .cell_rows(fit, x, y)
  dat <- fit$data[rows, c(x, y), drop = FALSE]

  # Kept models replace the refit when they are the same fits -------------
  models <- NULL
  if (is_gam && is.null(fit$adjust) && !is.null(fit$fits) &&
      length(rows) <= n_max) {
    ix <- match(x, fit$vars)
    iy <- match(y, fit$vars)
    kept <- list(
      forward = fit$fits[[sprintf("%d_%d", ix, iy)]],
      reverse = fit$fits[[sprintf("%d_%d", iy, ix)]]
    )
    if (!is.null(kept$forward) && !is.null(kept$reverse)) models <- kept
  }

  .direction_engine(
    dat, x, y,
    k_forward = k_forward, k_reverse = k_reverse,
    bs = fit$settings$bs, method = method,
    alpha = alpha, n_permutations = n_permutations,
    linear_tol = linear_tol, gaussian_alpha = gaussian_alpha,
    seed = seed, n_min = n_min, n_max = n_max,
    models = models
  )
}

# The basis dimension of one direction of a fit; mgcv's default when the
# fit recorded none.
.direction_k <- function(k_used) {
  if (is.null(k_used) || is.na(k_used)) -1L else as.integer(k_used)
}

#' Deprecated: residual-independence direction test on a data frame
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `janusplot_direction_test()` was replaced by [janusplot_direction()]
#' in janusplot 1.0.0, which takes the rows, basis dimension and method
#' from a [janusplot_fit()] object. This alias runs the same test on the
#' complete cases of two columns of `data` for one more release.
#'
#' @param data A data frame containing both variables.
#' @param x Character. Column name of the putative cause under the
#'   forward hypothesis.
#' @param y Character. Column name of the putative effect under the
#'   forward hypothesis.
#' @param k Basis dimension passed to [mgcv::s()]. Default `-1L` lets
#'   mgcv choose.
#' @param bs Character. Spline basis passed to [mgcv::s()]. Default
#'   `"tp"`.
#' @param method Smoothing-parameter selection method passed to
#'   [mgcv::gam()]. `NULL` (default) uses `"REML"`.
#' @inheritParams janusplot_direction
#'
#' @returns A `janusplot_direction` object; see [janusplot_direction()].
#'
#' @keywords internal
#' @export
janusplot_direction_test <- function(
  data,
  x,
  y,
  k = -1L,
  bs = "tp",
  method = NULL,
  alpha = 0.05,
  n_permutations = 500L,
  linear_tol = 0.01,
  gaussian_alpha = 0.01,
  seed = NULL,
  n_min = 30L,
  n_max = 2000L
) {
  lifecycle::deprecate_warn(
    when = "1.0.0",
    what = "janusplot_direction_test()",
    with = "janusplot_direction()",
    user_env = rlang::caller_env()
  )
  .validate_direction_args(
    data, x, y, k, bs, alpha, n_permutations, linear_tol, gaussian_alpha, seed
  )
  .validate_n_guards(n_min, n_max)
  dat <- .complete_pair(data, x, y, NULL)
  .direction_engine(
    dat[, c(x, y), drop = FALSE], x, y,
    k_forward = k, k_reverse = k, bs = bs, method = method,
    alpha = alpha, n_permutations = n_permutations,
    linear_tol = linear_tol, gaussian_alpha = gaussian_alpha,
    seed = seed, n_min = n_min, n_max = n_max
  )
}

# ---------------------------------------------------------------
# The engine both entry points call. `dat` is a two-column data frame
# of the complete rows under the user's names; `models`, when given,
# is list(forward, reverse) of mgcv fits on exactly those rows.
# ---------------------------------------------------------------

.direction_engine <- function(dat, x, y, k_forward, k_reverse, bs, method,
                              alpha, n_permutations, linear_tol,
                              gaussian_alpha, seed, n_min, n_max,
                              models = NULL, call = rlang::caller_env()) {
  n_min <- as.integer(n_min)
  n_max <- as.integer(n_max)
  n_complete <- nrow(dat)

  # Refusal and the n_min abstention --------------------------------------
  if (n_complete < 20L) {
    # Well-typed arguments, but the method's own requirement -- enough
    # complete cases to fit two smooths and permute a kernel statistic
    # over their residuals -- is not met. Declines with a classed
    # condition rather than returning a verdict it cannot support.
    cli::cli_abort(
      c(
        "Only {n_complete} complete case{?s} on {.val {x}} and {.val {y}}.",
        i = "At least 20 are needed to fit both directions and permute the HSIC null."
      ),
      class = c("janusplot_refusal", "orchestra_refusal"),
      call = call
    )
  }
  settings <- list(
    alpha          = alpha,
    gaussian_alpha = gaussian_alpha,
    linear_tol     = linear_tol,
    n_permutations = as.integer(n_permutations),
    n_min          = n_min,
    n_max          = n_max,
    method         = .resolve_method(method, "gam")
  )
  if (n_complete < n_min) {
    return(.direction_result(
      verdict = "undecided", reason_code = "n_below_min",
      reason = "n below n_min", x = x, y = y,
      n = n_complete, n_used = n_complete, settings = settings
    ))
  }
  dat <- .direction_subsample(dat, n_max, seed)
  n_used <- nrow(dat)
  if (n_used < n_complete) models <- NULL

  if (!.kernR_available()) {
    cli::cli_abort(c(
      "{.pkg kernR} is required for {.fn janusplot_direction}.",
      i = paste(
        "The residual-independence test is",
        "{.fn kernR::hsic_test}; without it the direction cannot be",
        "licensed, only its fit asymmetry described by {.fn janusplot}."
      ),
      i = "Install with {.code pak::pak(\"max578/kernR\")}."
    ), call = call)
  }

  # The two direction fits ------------------------------------------------
  # Fitted on syntactic aliases so column names with spaces or symbols
  # reach mgcv's formula parser intact; x and y keep the user's names
  # for the return value and every message.
  work <- data.frame(janus_x = dat[[x]], janus_y = dat[[y]])
  if (is.null(models)) {
    forward <- .direction_fit(work, "janus_x", "janus_y", k_forward, bs,
                              settings$method)
    reverse <- .direction_fit(work, "janus_y", "janus_x", k_reverse, bs,
                              settings$method)
  } else {
    forward <- .direction_summary(models$forward, work$janus_x,
                                  work$janus_y, settings$method)
    reverse <- .direction_summary(models$reverse, work$janus_y,
                                  work$janus_x, settings$method)
  }

  # Independence and the linear-Gaussian detector -------------------------
  seed_forward <- if (is.null(seed)) NULL else as.integer(seed)
  seed_reverse <- if (is.null(seed)) NULL else as.integer(seed) + 1L
  hsic_forward <- kernR::hsic_test(
    forward$residuals, work$janus_x,
    n_permutations = as.integer(n_permutations),
    alpha = alpha, seed = seed_forward
  )
  hsic_reverse <- kernR::hsic_test(
    reverse$residuals, work$janus_y,
    n_permutations = as.integer(n_permutations),
    alpha = alpha, seed = seed_reverse
  )

  independent_forward <- hsic_forward$p_value > alpha
  independent_reverse <- hsic_reverse$p_value > alpha

  normality_p <- c(
    x                 = .normality_pvalue(work$janus_x),
    y                 = .normality_pvalue(work$janus_y),
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

  # Verdict ---------------------------------------------------------------
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

  .direction_result(
    verdict             = verdict,
    reason_code         = reason_code,
    reason              = reason,
    x                   = x,
    y                   = y,
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
    n                   = n_complete,
    n_used              = n_used,
    settings            = settings
  )
}

# ---------------------------------------------------------------
# print() method
# ---------------------------------------------------------------

#' @rdname janusplot_direction
#' @param ... Ignored.
#' @export
print.janusplot_direction <- function(x, ...) {
  named <- switch(x$verdict,
    forward = x$forward,
    reverse = x$reverse,
    "no direction"
  )
  format_p <- function(p) {
    if (is.na(p)) "not tested" else sprintf("p = %s", format(signif(p, 3L)))
  }
  cli::cat_line(sprintf("janusplot direction test: %s against %s",
                        x$forward, x$reverse))
  cli::cat_line(sprintf("verdict: %s (%s), reason %s",
                        x$verdict, named, x$reason_code))
  for (line in strwrap(x$reason, width = 72L, indent = 2L, exdent = 2L)) {
    cli::cat_line(line)
  }
  cli::cat_line(sprintf("HSIC residual independence (alpha = %s):",
                        format(x$alpha)))
  cli::cat_line(sprintf("  %s  %s", x$forward, format_p(x$p_forward)))
  cli::cat_line(sprintf("  %s  %s", x$reverse, format_p(x$p_reverse)))
  cli::cat_line(sprintf("n_used = %d of n = %d complete cases",
                        as.integer(x$n_used), as.integer(x$n)))
  invisible(x)
}

# ---------------------------------------------------------------
# Assemble the return list. Defaults are the NA fill used when no
# test was run (n below n_min).
# ---------------------------------------------------------------

.direction_result <- function(verdict, reason_code, reason, x, y,
                              n, n_used, settings,
                              p_forward           = NA_real_,
                              p_reverse           = NA_real_,
                              statistic_forward   = NA_real_,
                              statistic_reverse   = NA_real_,
                              independent_forward = NA,
                              independent_reverse = NA,
                              edf_forward         = NA_real_,
                              edf_reverse         = NA_real_,
                              curvature_forward   = NA_real_,
                              curvature_reverse   = NA_real_,
                              normality_p         = c(
                                x                 = NA_real_,
                                y                 = NA_real_,
                                residuals_forward = NA_real_,
                                residuals_reverse = NA_real_
                              ),
                              linear_gaussian     = NA) {
  out <- list(
    verdict             = verdict,
    reason_code         = reason_code,
    reason              = reason,
    x                   = x,
    y                   = y,
    forward             = sprintf("%s -> %s", x, y),
    reverse             = sprintf("%s -> %s", y, x),
    p_forward           = p_forward,
    p_reverse           = p_reverse,
    statistic_forward   = statistic_forward,
    statistic_reverse   = statistic_reverse,
    independent_forward = independent_forward,
    independent_reverse = independent_reverse,
    edf_forward         = edf_forward,
    edf_reverse         = edf_reverse,
    curvature_forward   = curvature_forward,
    curvature_reverse   = curvature_reverse,
    normality_p         = normality_p,
    linear_gaussian     = linear_gaussian,
    n                   = n,
    n_used              = n_used,
    alpha               = settings$alpha,
    gaussian_alpha      = settings$gaussian_alpha,
    linear_tol          = settings$linear_tol,
    n_permutations      = settings$n_permutations,
    n_min               = settings$n_min,
    n_max               = settings$n_max,
    method              = settings$method
  )
  structure(out, class = c("janusplot_direction", "list"))
}

.validate_n_guards <- function(n_min, n_max, call = rlang::caller_env()) {
  for (nm in c("n_min", "n_max")) {
    value <- if (identical(nm, "n_min")) n_min else n_max
    if (!is.numeric(value) || length(value) != 1L || !is.finite(value) ||
        value < 1 || value != round(value)) {
      cli::cli_abort(
        "{.arg {nm}} must be a single positive whole number.",
        call = call
      )
    }
  }
  if (n_max < 20) {
    cli::cli_abort(
      c(
        "{.arg n_max} must be at least 20.",
        i = "Fewer rows cannot support fits in both directions."
      ),
      call = call
    )
  }
  if (n_max < n_min) {
    cli::cli_abort(
      "{.arg n_max} ({n_max}) must not be smaller than {.arg n_min} ({n_min}).",
      call = call
    )
  }
  invisible(NULL)
}

# ---------------------------------------------------------------
# Argument validation for janusplot_direction() and its alias
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
  .validate_direction_settings(
    alpha, n_permutations, linear_tol, gaussian_alpha, seed, call = call
  )
  invisible(NULL)
}

# The settings shared by janusplot_direction() and the alias.
.validate_direction_settings <- function(alpha, n_permutations, linear_tol,
                                         gaussian_alpha, seed,
                                         call = rlang::caller_env()) {
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
