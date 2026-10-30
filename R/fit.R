# fit.R -- The janusplot_fit object: one GAM fit of every ordered pair, the
# per-pair results, the per-cell table, the cleaned data copy and the fit
# flags, with print() and summary() methods. The fit internals live in
# internal-fit.R; the shape classifier and its borderline margin in
# shape-metrics.R. janusplot_data() remains in janusplot.R as a deprecated
# alias of janusplot_fit().

#' Fit every ordered pair of a smoothed-association matrix
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Fits `gam(x_j ~ s(x_i) + <adjust>)` once for every ordered pair of
#' numeric variables and returns a `janusplot_fit` object holding the
#' per-pair results, a per-cell summary table, a cleaned copy of the data
#' used and the fit settings. [janusplot()] draws the matrix; `summary()`
#' returns the per-cell table.
#'
#' @details
#' Suffixes name the direction of fit. `_xy` is `vars[i] ~ s(vars[j])` for
#' `i < j`, the upper-triangle cell at row `i`, column `j`; `_yx` is
#' `vars[j] ~ s(vars[i])`, the lower-triangle cell. In `$table` each row
#' is one directed cell with `var_x` the predictor and `var_y` the
#' response.
#'
#' First and second derivatives of every smooth are computed at fit time
#' by default, so `n_grid = NULL` resolves to 200 evaluation points. The
#' shape indices `M` and `C`, the turning-point and inflection counts and
#' the flat-range ratio are computed on this grid.
#'
#' The smooth F-test p-values of the `k(k - 1)` directed cells form one
#' family. `p_adjust` adjusts them once with [stats::p.adjust()] and the
#' result is stored beside the raw values as `association_p_adj`; failed
#' cells stay `NA`. Under `"none"` the adjusted columns equal the raw ones.
#'
#' `directional_complexity_yx` is `(EDF_yx - EDF_xy) / (EDF_yx + EDF_xy)`
#' in `[-1, 1]`, positive when the fit of `var_j` on `var_i` is the more
#' complex direction; `directional_complexity_xy` is its negative and
#' `asymmetry_index` its magnitude. A is unreliable when either direction
#' had its basis dimension capped (`k_capped_yx` or `k_capped_xy`), either
#' at the first fit or when an `auto_refit_k` refit reached the cap
#' (`k_at_cap` in the k-check columns).
#'
#' `shape_borderline` is the smallest absolute gap between a shape index
#' and a classification cutoff whose crossing by that index alone would
#' change the `shape_category` label, on the index's own scale: `M` and
#' `C` against the monotonicity and curvature cutoffs, the flat-range
#' ratio against the `flat` cutoff. A small value marks a label that a
#' slightly different smooth would have moved. Only `flat` and the
#' monotone labels of a curve with no turning point and no inflection
#' carry a margin. Every other label is decided by the turning-point and
#' inflection counts and has `NA`: the margin does not measure how near a
#' count is to changing.
#'
#' `$data` is the cleaned copy of the columns used: the fitted variables,
#' the `adjust` variables and every factor, character or logical column
#' of `data`, under the original column names, after infinite values are
#' set to `NA` and character or logical `adjust` columns are converted to
#' factor. It keeps every row under `na_action = "pairwise"` and the
#' listwise-complete rows under `"complete"`; a cell's raw points are its
#' two columns on the rows complete for them and the `adjust` columns.
#'
#' @param data A data frame. Column names need not be syntactic; fits run
#'   under internal aliases and every result reports the original names.
#' @param vars Character vector of numeric column names to fit, in matrix
#'   order. `NULL` (the default) takes every numeric column of `data`.
#'   Identical or exactly collinear columns are not fitted against each
#'   other; their cells are listed in `flags$failed`.
#' @param adjust One-sided formula of covariates and random effects added
#'   to every pairwise model, for example `~ s(age) + s(site, bs = "re")`.
#'   `NULL` (the default) fits unadjusted smooths. Character and logical
#'   `adjust` columns are converted to factor before fitting. Predictions
#'   hold numeric covariates at their mean and fixed factors at their
#'   most frequent level, and exclude random-effect smooths, so the curve
#'   and its band are population-level.
#' @param k Basis dimension for `s()`: a single integer, or a named list
#'   of integers keyed by variable name. `-1L` (the default) leaves the
#'   choice to mgcv. Each cell's basis is capped at the number of distinct
#'   predictor values in its rows, and an `auto_refit_k` refit stops one
#'   below that number; capped cells are listed in
#'   `flags$k_capped` and recorded as `k_requested`, `k_used` and
#'   `k_capped`.
#' @param bs Basis type for `s()`; `"tp"` (thin plate) by default.
#' @param engine `"bam"` (the default) fits with [mgcv::bam()], `"gam"`
#'   with [mgcv::gam()]. The two differ in their default `method` and by
#'   about one to three percent in EDF on the same data.
#' @param method Smoothing-parameter estimation method passed to mgcv.
#'   `NULL` (the default) resolves to `"fREML"` for `engine = "bam"` and
#'   `"REML"` for `engine = "gam"`.
#' @param na_action `"pairwise"` (the default) fits each cell on the rows
#'   complete for its own variables and the `adjust` columns;
#'   `"complete"` first drops every row with a missing value in any fitted
#'   or adjusting column. Infinite values count as missing and are
#'   reported in a warning. A pair sharing fewer than 5 complete rows is
#'   not fitted and is listed in `flags$sparse`; an error is raised only
#'   when no pair reaches 5 rows.
#' @param n_grid Number of equally spaced points at which each smooth and
#'   its derivatives are evaluated, at least 10. `NULL` (the default)
#'   resolves to `200L` when `derivatives` is non-empty and `100L`
#'   otherwise.
#' @param derivatives Integer vector of derivative orders to compute for
#'   every cell, a subset of `1:2`. The default `1:2` computes both;
#'   `integer()` computes none.
#' @param derivative_ci The band stored with each derivative curve:
#'   `"pointwise"` (the default), `"none"` or `"simultaneous"`. Simultaneous
#'   bands use the Monte Carlo critical multiplier of Ruppert, Wand and
#'   Carroll (2003) as applied to GAMs by Simpson (2018).
#' @param derivative_ci_nsim Number of Monte Carlo draws for
#'   `derivative_ci = "simultaneous"`; `1000L` by default and at least 100.
#' @param p_adjust Multiplicity adjustment of the smooth F-test p-values
#'   across the `k(k - 1)` directed cells: `"none"` (the default), `"BH"`
#'   or `"holm"`, applied once with [stats::p.adjust()]. Raw and adjusted
#'   values are both kept.
#' @param shape_cutoffs Named list of classification thresholds, from
#'   [janusplot_shape_cutoffs()], mapping the shape indices to a
#'   `shape_category` label.
#' @param k_check_thresholds Named list with entries `edf_ratio`,
#'   `k_index` and `p` for the basis-dimension diagnostic that follows
#'   [mgcv::k.check()]. `NULL` (the default) uses `edf_ratio = 0.9`,
#'   `k_index = 1` and `p = 0.05`.
#' @param auto_refit_k Logical. When `TRUE`, a cell flagged by the k-check
#'   is refitted with a doubled basis until the flag clears, the
#'   distinct-value cap is reached or `k_max_iter` doublings have run.
#'   The diagnostic is computed either way; the default is `FALSE`.
#' @param k_max_iter Maximum number of doublings per cell when
#'   `auto_refit_k = TRUE`; `2L` by default.
#' @param discrete Logical. Passes mgcv's covariate discretisation to
#'   [mgcv::bam()]; `FALSE` by default and ignored for `engine = "gam"`.
#' @param nthreads Integer. Threads used inside each [mgcv::bam()] fit;
#'   `1L` by default, which avoids oversubscription under
#'   `parallel = TRUE`. Ignored for `engine = "gam"`.
#' @param parallel Logical. When `TRUE`, pairs are fitted with
#'   `future.apply::future_mapply()` under the user's `future::plan()`;
#'   `FALSE` by default.
#' @param keep_fits Logical. When `TRUE`, the mgcv model objects are kept
#'   in `$fits` and as `fit_yx` / `fit_xy` of every pair; `FALSE` (the
#'   default) keeps metrics and prediction grids only.
#' @param ... Further arguments passed to [mgcv::gam()] or [mgcv::bam()].
#'   The `print()` and `summary()` methods ignore them. Under a `family`
#'   with a non-identity link the curve and its band are drawn on the
#'   response scale, while the derivatives, the shape indices and the
#'   shape label describe the linear predictor (the link scale). The two
#'   agree on monotone labels; a curvature label can differ, for example
#'   a log-linear Poisson mean is `linear_up` on the link scale and convex
#'   on the response scale.
#' @param x A `janusplot_fit` object.
#' @param object A `janusplot_fit` object.
#'
#' @returns A list of class `janusplot_fit` with components, in order:
#' \describe{
#'   \item{`vars`}{Character vector of the variables fitted, in matrix
#'     order.}
#'   \item{`pairs`}{List with one element per unordered pair `i < j`. Each
#'     element carries `i`, `j`, `var_i`, `var_j`, `fit_yx`, `fit_xy`
#'     (`NULL` unless `keep_fits = TRUE`), the prediction grids `pred_yx`,
#'     `pred_xy` (data frames with `x`, `fit`, `se`, `lo`, `hi` on the
#'     response scale, `se` on the link scale, and `fit_link` when the
#'     link is not the identity),
#'     `edf_yx`, `edf_xy`, `association_p_yx`, `association_p_xy`,
#'     `association_p_adj_yx`, `association_p_adj_xy`, `dev_exp_yx`,
#'     `dev_exp_xy`, `deviance_gap_yx`, `deviance_gap_xy`, `n_used`,
#'     `asymmetry_index`, `k_capped_yx`, `k_capped_xy`,
#'     `directional_complexity_yx`, `directional_complexity_xy`, the
#'     correlations `cor_pearson`, `cor_spearman`, `cor_kendall` and
#'     `tie_ratio`, the shape indices `monotonicity_index_*`,
#'     `convexity_index_*`, the counts `n_turning_*`, `n_inflect_*`, the
#'     labels `shape_*`, `shape_code_*`, `shape_archetype_*`,
#'     `shape_monotonic_*`, `shape_linear_*`, the margins
#'     `shape_borderline_yx`, `shape_borderline_xy` (`NA` for an
#'     `indeterminate` or count-decided label), the derivative
#'     curves `deriv_yx`, `deriv_xy` (lists keyed `"1"`, `"2"` of data
#'     frames with `x`, `fit`, `se`, `lo`, `hi`, `ci_type`), the
#'     prediction references `prediction_reference_yx`,
#'     `prediction_reference_xy`, the k-check lists `k_check_yx`,
#'     `k_check_xy`, `k_requested_*`, `k_used_*`, `engine`, `method`,
#'     `error_yx` and `error_xy`.}
#'   \item{`table`}{Data frame with one row per directed cell: `var_x`,
#'     `var_y`, `position` (`"upper"` if `var_y` is first), `n_used`, `edf`,
#'     `association_p`, `association_p_adj`, `signif` (glyph from the
#'     adjusted p-value), `dev_exp`, `deviance_gap`, `asymmetry_index`,
#'     `k_capped_yx`, `k_capped_xy`, `directional_complexity` (signed for
#'     this cell), the correlations, the shape indices, counts and
#'     labels, `shape_borderline`, the k-check columns `k_prime`,
#'     `k_index`, `k_p`, `k_flag`, `k_check_status`, `k_initial`,
#'     `k_final`, `k_iterations`, `k_at_cap`, `k_requested`, `k_used`,
#'     `k_capped`, `engine`, `method` and `error`. `summary()` returns
#'     this table.}
#'   \item{`data`}{The cleaned copy of the columns used, as described in
#'     Details.}
#'   \item{`adjust`}{The `adjust` formula, or `NULL`.}
#'   \item{`settings`}{Named list of the fit settings as resolved:
#'     `engine`, `method`, `k`, `bs`, `na_action`, `n_grid`,
#'     `derivatives`, `derivative_ci`, `derivative_ci_nsim`, `p_adjust`,
#'     `shape_cutoffs`, `k_check_thresholds`, `auto_refit_k`,
#'     `k_max_iter`, `family` and `link` (names, as in
#'     [stats::family()]), `discrete` and `nthreads`.}
#'   \item{`flags`}{List with `failed` (data frame of `var_x`, `var_y`,
#'     `reason` for cells that carry no fit), `k_capped` and `k_flagged`
#'     (character vectors of cells as `"var_y ~ s(var_x)"`) and `sparse`
#'     (data frame of `var_i`, `var_j`, `n_shared` for pairs with fewer
#'     than 5 shared rows).}
#'   \item{`fits`}{When `keep_fits = TRUE`, the list of mgcv objects keyed
#'     `"i_j"` for the cell `vars[j] ~ s(vars[i])`; otherwise `NULL`.}
#'   \item{`call`}{The matched call.}
#' }
#' `print()` returns `x` invisibly; `summary()` returns the `table`
#' component.
#'
#' @family smooth-associations
#' @seealso [janusplot()] for the matrix, [janusplot_shape_metrics()] for
#'   the shape indices, [janusplot_shape_cutoffs()] for the
#'   classification thresholds.
#'
#' @examples
#' fit <- janusplot_fit(mtcars[, c("mpg", "hp", "wt")], engine = "gam")
#' fit
#' summary(fit)[, c("var_x", "var_y", "edf", "association_p",
#'                  "shape_category")]
#' fit$pairs[[1L]]$asymmetry_index
#' @export
janusplot_fit <- function(
  data,
  vars = NULL,
  adjust = NULL,
  k = -1L,
  bs = "tp",
  engine = c("bam", "gam"),
  method = NULL,
  na_action = c("pairwise", "complete"),
  n_grid = NULL,
  derivatives = 1:2,
  derivative_ci = c("pointwise", "none", "simultaneous"),
  derivative_ci_nsim = 1000L,
  p_adjust = c("none", "BH", "holm"),
  shape_cutoffs = janusplot_shape_cutoffs(),
  k_check_thresholds = NULL,
  auto_refit_k = FALSE,
  k_max_iter = 2L,
  discrete = FALSE,
  nthreads = 1L,
  parallel = FALSE,
  keep_fits = FALSE,
  ...
) {
  engine        <- rlang::arg_match(engine)
  na_action     <- rlang::arg_match(na_action)
  derivative_ci <- rlang::arg_match(derivative_ci)
  p_adjust      <- rlang::arg_match(p_adjust)
  .validate_shared_scalars(
    discrete, nthreads, auto_refit_k, k_max_iter, derivative_ci_nsim
  )
  .check_flag(keep_fits, "keep_fits")
  .validate_inputs(data, vars, adjust, na_action)
  vars         <- .resolve_vars(data, vars)
  k_thresholds <- .validate_k_thresholds(
    k_check_thresholds %||% .default_k_thresholds()
  )
  derivatives  <- .validate_derivatives(derivatives)
  n_grid       <- .resolve_n_grid(n_grid, derivatives)
  method       <- .resolve_method(method, engine)
  nthreads           <- as.integer(nthreads)
  k_max_iter         <- as.integer(k_max_iter)
  derivative_ci_nsim <- as.integer(derivative_ci_nsim)

  # Fit every ordered pair -----------------------------------------------
  fits <- .fit_all_pairs(
    data = data, vars = vars, adjust = adjust,
    method = method, k = k, bs = bs,
    na_action = na_action, parallel = parallel,
    n_grid = n_grid, derivatives = derivatives,
    derivative_ci = derivative_ci,
    derivative_ci_nsim = derivative_ci_nsim,
    k_check_thresholds = k_thresholds,
    auto_refit_k = auto_refit_k,
    k_max_iter = k_max_iter,
    engine = engine, discrete = discrete, nthreads = nthreads, ...
  )
  .warn_failed_cells(fits)
  .inform_k_capped(fits)
  .summarise_k_check(fits, k_thresholds, auto_refit_k)

  # Matrix-wide quantities and the object --------------------------------
  p_adj <- .adjust_association_p(fits, p_adjust)
  family <- .resolve_family(list(...))
  settings <- list(
    engine             = engine,
    method             = method,
    k                  = k,
    bs                 = bs,
    na_action          = na_action,
    n_grid             = n_grid,
    derivatives        = derivatives,
    derivative_ci      = derivative_ci,
    derivative_ci_nsim = derivative_ci_nsim,
    p_adjust           = p_adjust,
    shape_cutoffs      = shape_cutoffs,
    k_check_thresholds = k_thresholds,
    auto_refit_k       = auto_refit_k,
    k_max_iter         = k_max_iter,
    family             = family$family,
    link               = family$link,
    discrete           = discrete,
    nthreads           = nthreads
  )
  out <- list(
    vars     = vars,
    pairs    = .build_pairs(fits, vars, p_adj, shape_cutoffs, keep_fits),
    table    = .build_fit_table(fits, p_adj, shape_cutoffs),
    data     = .clean_data_copy(data, vars, adjust, na_action),
    adjust   = adjust,
    settings = settings,
    flags    = .fit_flags(fits),
    fits     = if (keep_fits) lapply(fits, function(f) f$fit) else NULL,
    call     = match.call()
  )
  structure(out, class = c("janusplot_fit", "list"))
}

# ---------------------------------------------------------------
# Argument validation and resolution
# ---------------------------------------------------------------

# A single non-missing TRUE or FALSE.
.check_flag <- function(x, arg_name, call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg {arg_name}} must be TRUE or FALSE.", call = call)
  }
  invisible(NULL)
}

# Derivative orders: an integer subset of 1:2 without duplicates, or
# empty for none.
.validate_derivatives <- function(derivatives, call = rlang::caller_env()) {
  if (!length(derivatives)) return(integer())
  if (!is.numeric(derivatives) || anyNA(derivatives)) {
    cli::cli_abort(
      "{.arg derivatives} must be an integer vector of orders in 1:2.",
      call = call
    )
  }
  derivatives <- as.integer(derivatives)
  if (any(derivatives < 1L | derivatives > 2L)) {
    cli::cli_abort(
      "{.arg derivatives} entries must be in 1:2; higher orders are not supported.",
      call = call
    )
  }
  if (anyDuplicated(derivatives)) {
    cli::cli_abort("{.arg derivatives} must not contain duplicates.",
                   call = call)
  }
  derivatives
}

# Grid size: NULL resolves to 200 points with derivatives and 100 without;
# grids above 500 are flagged for their O(n_grid) prediction cost.
.resolve_n_grid <- function(n_grid, derivatives, call = rlang::caller_env()) {
  if (is.null(n_grid)) {
    return(if (length(derivatives)) 200L else 100L)
  }
  if (!is.numeric(n_grid) || length(n_grid) != 1L ||
      !is.finite(n_grid) || n_grid < 10) {
    cli::cli_abort(
      "{.arg n_grid} must be a single finite number >= 10 or NULL.",
      call = call
    )
  }
  n_grid <- as.integer(n_grid)
  if (n_grid > 500L) {
    cli::cli_inform(c(
      "!" = paste(
        "{.arg n_grid} = {n_grid} is unusually large;",
        "each pair pays an O(n_grid) predict cost."
      ),
      i = "Grids above ~300 rarely improve readability."
    ))
  }
  n_grid
}

# The mgcv method actually used: the engine default unless the user
# named one.
.resolve_method <- function(method, engine) {
  if (is.null(method) || identical(method, "auto") ||
      identical(method, "default")) {
    .engine_default_method(engine)
  } else {
    method
  }
}

# The family passed through `...`, resolved the way mgcv resolves it
# (a name, a family function or a family object), so the fit can record
# its name and link.
.resolve_family <- function(dots) {
  family <- dots$family %||% stats::gaussian()
  if (is.character(family)) {
    family <- get(family, mode = "function", envir = asNamespace("mgcv"))
  }
  if (is.function(family)) family <- family()
  family
}

# ---------------------------------------------------------------
# Matrix-wide quantities
# ---------------------------------------------------------------

# Adjusted smooth F-test p-values over the directed cells, keyed like
# `fits`. Failed cells (NA) are left out of the family and stay NA.
.adjust_association_p <- function(fits, method) {
  p_raw <- vapply(fits, function(f) as.numeric(f$pvalue %||% NA_real_),
                  numeric(1L))
  p_adj <- p_raw
  ok <- !is.na(p_raw)
  if (any(ok)) p_adj[ok] <- stats::p.adjust(p_raw[ok], method = method)
  p_adj
}

# Signed complexity difference in [-1, 1]: positive when the yx direction
# carries the larger EDF. Its magnitude is the asymmetry index.
.directional_complexity <- function(edf_yx, edf_xy) {
  if (is.na(edf_yx) || is.na(edf_xy)) return(NA_real_)
  denom <- edf_yx + edf_xy
  if (!is.finite(denom) || denom <= 0) return(NA_real_)
  (edf_yx - edf_xy) / denom
}

# Shape label and its borderline margin for one fitted cell.
.cell_shape <- function(f, cutoffs) {
  .classify_shape(
    f$shape$monotonicity_index, f$shape$convexity_index,
    f$shape$n_turning_points, f$shape$n_inflections,
    f$shape$flat_range_ratio, cutoffs,
    extremum = f$shape$extremum_type
  )
}

.cell_shape_borderline <- function(f, cutoffs) {
  .shape_borderline(
    f$shape$monotonicity_index, f$shape$convexity_index,
    f$shape$n_turning_points, f$shape$n_inflections,
    f$shape$flat_range_ratio, cutoffs,
    extremum = f$shape$extremum_type
  )
}

# ---------------------------------------------------------------
# Per-pair results, one element per unordered pair i < j
# ---------------------------------------------------------------

.build_pairs <- function(fits, vars, p_adj, shape_cutoffs, keep_fits) {
  k_n <- length(vars)
  pairs_out <- vector("list", k_n * (k_n - 1L) %/% 2L)
  idx <- 0L
  for (i in seq_len(k_n - 1L)) {
    for (j in (i + 1L):k_n) {
      key_yx <- sprintf("%d_%d", i, j)   # y = vars[j] ~ s(vars[i])
      key_xy <- sprintf("%d_%d", j, i)   # y = vars[i] ~ s(vars[j])
      f_yx <- fits[[key_yx]]
      f_xy <- fits[[key_xy]]
      shape_yx <- .cell_shape(f_yx, shape_cutoffs)
      shape_xy <- .cell_shape(f_xy, shape_cutoffs)
      complexity_yx <- .directional_complexity(f_yx$edf, f_xy$edf)
      corr <- f_yx$corr %||% f_xy$corr
      idx <- idx + 1L
      pairs_out[[idx]] <- list(
        i                         = i,
        j                         = j,
        var_i                     = vars[i],
        var_j                     = vars[j],
        fit_yx                    = if (keep_fits) f_yx$fit else NULL,
        fit_xy                    = if (keep_fits) f_xy$fit else NULL,
        pred_yx                   = f_yx$pred,
        pred_xy                   = f_xy$pred,
        edf_yx                    = f_yx$edf,
        edf_xy                    = f_xy$edf,
        association_p_yx          = f_yx$pvalue,
        association_p_xy          = f_xy$pvalue,
        association_p_adj_yx      = unname(p_adj[[key_yx]]),
        association_p_adj_xy      = unname(p_adj[[key_xy]]),
        dev_exp_yx                = f_yx$dev_exp,
        dev_exp_xy                = f_xy$dev_exp,
        deviance_gap_yx           = f_yx$deviance_gap %||% NA_real_,
        deviance_gap_xy           = f_xy$deviance_gap %||% NA_real_,
        n_used                    = min(f_yx$n_used, f_xy$n_used),
        asymmetry_index           = .compute_asymmetry_index(f_yx$edf,
                                                             f_xy$edf),
        k_capped_yx               = isTRUE(f_yx$k_capped),
        k_capped_xy               = isTRUE(f_xy$k_capped),
        directional_complexity_yx = complexity_yx,
        directional_complexity_xy = -complexity_yx,
        cor_pearson               = corr$cor_pearson,
        cor_spearman              = corr$cor_spearman,
        cor_kendall               = corr$cor_kendall,
        tie_ratio                 = corr$tie_ratio,
        monotonicity_index_yx     = f_yx$shape$monotonicity_index,
        convexity_index_yx        = f_yx$shape$convexity_index,
        monotonicity_index_xy     = f_xy$shape$monotonicity_index,
        convexity_index_xy        = f_xy$shape$convexity_index,
        n_turning_yx              = f_yx$shape$n_turning_points,
        n_inflect_yx              = f_yx$shape$n_inflections,
        n_turning_xy              = f_xy$shape$n_turning_points,
        n_inflect_xy              = f_xy$shape$n_inflections,
        shape_yx                  = shape_yx,
        shape_xy                  = shape_xy,
        shape_code_yx             = .shape_lookup(shape_yx, "code"),
        shape_code_xy             = .shape_lookup(shape_xy, "code"),
        shape_archetype_yx        = .shape_lookup(shape_yx, "archetype"),
        shape_archetype_xy        = .shape_lookup(shape_xy, "archetype"),
        shape_monotonic_yx        = .shape_lookup(shape_yx, "monotonic"),
        shape_monotonic_xy        = .shape_lookup(shape_xy, "monotonic"),
        shape_linear_yx           = .shape_lookup(shape_yx, "linear"),
        shape_linear_xy           = .shape_lookup(shape_xy, "linear"),
        shape_borderline_yx       = .cell_shape_borderline(f_yx,
                                                           shape_cutoffs),
        shape_borderline_xy       = .cell_shape_borderline(f_xy,
                                                           shape_cutoffs),
        deriv_yx                  = f_yx$deriv,
        deriv_xy                  = f_xy$deriv,
        prediction_reference_yx   = f_yx$prediction_reference,
        prediction_reference_xy   = f_xy$prediction_reference,
        k_check_yx                = f_yx$k_check,
        k_check_xy                = f_xy$k_check,
        k_requested_yx            = f_yx$k_requested,
        k_requested_xy            = f_xy$k_requested,
        k_used_yx                 = f_yx$k_used,
        k_used_xy                 = f_xy$k_used,
        engine                    = f_yx$engine %||% f_xy$engine %||%
                                      NA_character_,
        method                    = f_yx$method %||% f_xy$method %||%
                                      NA_character_,
        error_yx                  = f_yx$error %||% NA_character_,
        error_xy                  = f_xy$error %||% NA_character_
      )
    }
  }
  pairs_out
}

# ---------------------------------------------------------------
# Per-cell table, one row per directed cell
# ---------------------------------------------------------------

.build_fit_table <- function(fits, p_adj, shape_cutoffs) {
  rows <- lapply(names(fits), function(key) {
    f <- fits[[key]]
    ij <- as.integer(strsplit(key, "_", fixed = TRUE)[[1L]])
    position <- if (ij[1L] > ij[2L]) "upper" else "lower"
    # Pair-level quantities keyed like A: _yx is vars[j] ~ s(vars[i]), i < j.
    f_yx  <- fits[[sprintf("%d_%d", min(ij), max(ij))]]
    f_xy  <- fits[[sprintf("%d_%d", max(ij), min(ij))]]
    f_rev <- fits[[sprintf("%d_%d", ij[2L], ij[1L])]]
    shape_cat <- .cell_shape(f, shape_cutoffs)
    p_cell <- unname(p_adj[[key]])
    kc <- f$k_check %||% list(
      k_prime = NA_real_, k_index = NA_real_, k_p = NA_real_,
      k_flag = NA, k_check_status = NA_character_,
      k_initial = NA_real_, k_final = NA_real_,
      k_iterations = 0L, k_at_cap = FALSE
    )
    data.frame(
      var_x                  = f$x_name,
      var_y                  = f$y_name,
      position               = position,
      n_used                 = f$n_used,
      edf                    = f$edf,
      association_p          = f$pvalue,
      association_p_adj      = p_cell,
      signif                 = .pvalue_to_glyph(p_cell),
      dev_exp                = f$dev_exp,
      deviance_gap           = f$deviance_gap %||% NA_real_,
      asymmetry_index        = .compute_asymmetry_index(f_yx$edf, f_xy$edf),
      k_capped_yx            = isTRUE(f_yx$k_capped),
      k_capped_xy            = isTRUE(f_xy$k_capped),
      directional_complexity = .directional_complexity(f$edf, f_rev$edf),
      cor_pearson            = f$corr$cor_pearson,
      cor_spearman           = f$corr$cor_spearman,
      cor_kendall            = f$corr$cor_kendall,
      tie_ratio              = f$corr$tie_ratio,
      monotonicity_index     = f$shape$monotonicity_index,
      convexity_index        = f$shape$convexity_index,
      n_turning_points       = f$shape$n_turning_points,
      n_inflections          = f$shape$n_inflections,
      flat_range_ratio       = f$shape$flat_range_ratio,
      shape_category         = shape_cat,
      shape_code             = .shape_lookup(shape_cat, "code"),
      shape_archetype        = .shape_lookup(shape_cat, "archetype"),
      shape_monotonic        = .shape_lookup(shape_cat, "monotonic"),
      shape_linear           = .shape_lookup(shape_cat, "linear"),
      shape_borderline       = .cell_shape_borderline(f, shape_cutoffs),
      k_prime                = kc$k_prime,
      k_index                = kc$k_index,
      k_p                    = kc$k_p,
      k_flag                 = isTRUE(kc$k_flag),
      k_check_status         = kc$k_check_status,
      k_initial              = kc$k_initial,
      k_final                = kc$k_final,
      k_iterations           = as.integer(kc$k_iterations %||% 0L),
      k_at_cap               = isTRUE(kc$k_at_cap),
      k_requested            = as.integer(f$k_requested %||% NA_integer_),
      k_used                 = as.integer(f$k_used %||% NA_integer_),
      k_capped               = isTRUE(f$k_capped),
      engine                 = f$engine %||% NA_character_,
      method                 = f$method %||% NA_character_,
      error                  = f$error %||% NA_character_,
      stringsAsFactors       = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# ---------------------------------------------------------------
# Cleaned copy of the data used by the fit
# ---------------------------------------------------------------

# The columns used plus every categorical column, under the original
# names, cleaned as the fit cleaned them (messages already emitted there).
.clean_data_copy <- function(data, vars, adjust, na_action) {
  adj  <- intersect(.adjust_vars(adjust), names(data))
  used <- unique(c(vars, adj))
  categorical <- vapply(data, function(col) {
    is.factor(col) || is.character(col) || is.logical(col)
  }, logical(1L))
  keep <- names(data)[names(data) %in% used | categorical]
  out <- data[, keep, drop = FALSE]
  out <- .coerce_adjust_factors(out, vars, adjust, quiet = TRUE)
  out <- .drop_infinite(out, vars, adjust, quiet = TRUE)
  if (na_action == "complete") {
    complete <- stats::complete.cases(out[, used, drop = FALSE])
    out <- out[complete, , drop = FALSE]
  }
  out
}

# ---------------------------------------------------------------
# Flags: failed, capped, k-flagged cells and sparse pairs
# ---------------------------------------------------------------

.fit_flags <- function(fits) {
  has_error <- vapply(fits, function(f) {
    err <- f$error
    !is.null(err) && !is.na(err) && nzchar(err)
  }, logical(1L))
  failed_cells <- fits[has_error]
  failed <- data.frame(
    var_x  = .cell_field(failed_cells, "x_name"),
    var_y  = .cell_field(failed_cells, "y_name"),
    reason = .cell_field(failed_cells, "error"),
    stringsAsFactors = FALSE
  )
  cell_label <- function(f) sprintf("%s ~ s(%s)", f$y_name, f$x_name)
  k_capped <- vapply(Filter(function(f) isTRUE(f$k_capped), fits),
                     cell_label, character(1L), USE.NAMES = FALSE)
  k_flagged <- vapply(Filter(function(f) isTRUE(f$k_check$k_flag), fits),
                      cell_label, character(1L), USE.NAMES = FALSE)
  # Both directions of a pair share the same rows, so a sparse pair is
  # listed once, from its upper cell (i < j).
  is_sparse <- !has_error & vapply(fits, function(f) {
    n <- f$n_used
    !is.null(n) && !is.na(n) && n < 5L && is.null(f$fit)
  }, logical(1L))
  is_upper <- vapply(names(fits), function(key) {
    ij <- as.integer(strsplit(key, "_", fixed = TRUE)[[1L]])
    ij[1L] < ij[2L]
  }, logical(1L))
  sparse_cells <- fits[is_sparse & is_upper]
  sparse <- data.frame(
    var_i    = .cell_field(sparse_cells, "x_name"),
    var_j    = .cell_field(sparse_cells, "y_name"),
    n_shared = vapply(sparse_cells, function(f) as.integer(f$n_used),
                      integer(1L), USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
  list(failed = failed, k_capped = k_capped, k_flagged = k_flagged,
       sparse = sparse)
}

# One character field from each cell of a fit list.
.cell_field <- function(cells, field) {
  vapply(cells, function(f) as.character(f[[field]]), character(1L),
         USE.NAMES = FALSE)
}

# ---------------------------------------------------------------
# Methods
# ---------------------------------------------------------------

#' @rdname janusplot_fit
#' @export
print.janusplot_fit <- function(x, ...) {
  k_n     <- length(x$vars)
  n_pairs <- length(x$pairs)
  shown <- if (k_n > 8L) c(x$vars[seq_len(8L)], "...") else x$vars
  adjust_txt <- if (is.null(x$adjust)) {
    "none"
  } else {
    paste(deparse(x$adjust, width.cutoff = 500L), collapse = " ")
  }
  cli::cat_line(sprintf("janusplot fit: %d variables (%s)", k_n,
                        paste(shown, collapse = ", ")))
  cli::cat_line(sprintf("%d %s, %d directed cells", n_pairs,
                        if (n_pairs == 1L) "pair" else "pairs",
                        k_n * (k_n - 1L)))
  cli::cat_line(sprintf("engine = %s, method = %s, adjust = %s",
                        x$settings$engine, x$settings$method, adjust_txt))
  cli::cat_line(.format_flags(x$flags))
  cli::cat_line("Largest asymmetries:")
  for (line in .format_top_asymmetries(x$pairs,
                                      p_adjust = x$settings$p_adjust)) {
    cli::cat_line("  ", line)
  }
  cli::cat_line(
    "Use summary() for the per-cell table and plot() for the matrix."
  )
  invisible(x)
}

#' @rdname janusplot_fit
#' @export
summary.janusplot_fit <- function(object, ...) {
  object$table
}

# The flags line of print(): non-zero counts only, or "no flags".
.format_flags <- function(flags) {
  counts <- c(
    "failed cell"    = nrow(flags$failed),
    "k-capped cell"  = length(flags$k_capped),
    "k-flagged cell" = length(flags$k_flagged),
    "sparse pair"    = nrow(flags$sparse)
  )
  counts <- counts[counts > 0L]
  if (!length(counts)) return("no flags")
  items <- sprintf("%d %s%s", counts, names(counts),
                   ifelse(counts == 1L, "", "s"))
  paste0("flags: ", paste(items, collapse = ", "))
}

# The n_top largest asymmetries, one formatted line each; pairs without
# an index are left out.
.format_top_asymmetries <- function(pairs, n_top = 5L, p_adjust = "none") {
  a  <- vapply(pairs, function(p) as.numeric(p$asymmetry_index), numeric(1L))
  ok <- which(is.finite(a))
  if (!length(ok)) return("(no pair has an asymmetry index)")
  top <- ok[order(-a[ok])][seq_len(min(n_top, length(ok)))]
  p_name <- if (identical(p_adjust, "none")) "p" else "p_adj"
  direction <- function(y, x, edf, p, shape) {
    p_txt <- if (is.na(p)) {
      paste(p_name, "NA")
    } else if (p < 0.001) {
      paste(p_name, "< 0.001")
    } else {
      sprintf("%s = %.3f", p_name, p)
    }
    ns <- if (is.finite(p) && p >= 0.05) " n.s." else ""
    sprintf("%s ~ %s: EDF %.1f, %s, %s%s", y, x, edf, p_txt, shape, ns)
  }
  vapply(pairs[top], function(p) {
    sprintf("%s <-> %s  A = %.2f  %s | %s",
            p$var_i, p$var_j, p$asymmetry_index,
            direction(p$var_j, p$var_i, p$edf_yx,
                      p$association_p_adj_yx, p$shape_yx),
            direction(p$var_i, p$var_j, p$edf_xy,
                      p$association_p_adj_xy, p$shape_xy))
  }, character(1L), USE.NAMES = FALSE)
}
