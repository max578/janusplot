# Internal helpers -- NOT EXPORTED.
# Fit-layer logic for janusplot(): input validation, formula assembly,
# GAM fitting, asymmetry index, and hclust reorder.

# Local null-coalesce (R >= 4.4 has this in base; keep local for 4.3 support).
`%||%` <- function(x, y) if (is.null(x)) y else x

# Argument validation -- single positive scalar.
.check_scalar_positive <- function(x, arg_name, call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0) {
    cli::cli_abort("{.arg {arg_name}} must be a single positive number.",
                   call = call)
  }
  invisible(NULL)
}

# Diagnose parallel = TRUE requests that would silently fall back to
# sequential execution. Throttled per session so simulation loops don't
# spam the console; tests can pass .throttle = FALSE to force emission.
.check_parallel_plan <- function(parallel, .throttle = TRUE) {
  if (!isTRUE(parallel)) return(invisible(NULL))
  freq <- if (isTRUE(.throttle)) "regularly" else "always"
  if (!rlang::is_installed("future.apply")) {
    cli::cli_inform(
      c(
        "!" = paste(
          "{.arg parallel} is {.val TRUE} but {.pkg future.apply} is",
          "not installed \u2014 falling back to sequential dispatch."
        ),
        i = "Install with {.code pak::pak(\"future.apply\")}."
      ),
      .frequency    = freq,
      .frequency_id = "janusplot_no_future_apply"
    )
    return(invisible(NULL))
  }
  if (rlang::is_installed("future") &&
      future::nbrOfWorkers() < 2L) {
    cli::cli_inform(
      c(
        "!" = paste(
          "{.arg parallel} is {.val TRUE} but the current",
          "{.code future::plan()} is sequential (1 worker)."
        ),
        i = paste(
          "To parallelise, run e.g.",
          "{.code future::plan(future::multisession, workers = 4)}",
          "before {.fn janusplot}."
        )
      ),
      .frequency    = freq,
      .frequency_id = "janusplot_sequential_plan"
    )
  }
  invisible(NULL)
}

# ---------------------------------------------------------------
# Validation
# ---------------------------------------------------------------

.validate_inputs <- function(data, vars, adjust, na_action) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }
  if (nrow(data) < 5L) {
    cli::cli_abort(c(
      "{.arg data} has {nrow(data)} row{?s}.",
      i = "A meaningful GAM needs at least ~5 rows per pair."
    ))
  }
  if (!is.null(vars)) {
    if (!is.character(vars)) {
      cli::cli_abort("{.arg vars} must be a character vector or NULL.")
    }
    missing <- setdiff(vars, names(data))
    if (length(missing)) {
      cli::cli_abort(c(
        "Column{?s} not found in {.arg data}: {.val {missing}}."
      ))
    }
  }
  if (!is.null(adjust)) {
    if (!inherits(adjust, "formula") || length(adjust) != 2L) {
      cli::cli_abort(
        "{.arg adjust} must be a one-sided formula (e.g., {.code ~ s(g, bs = 're')})."
      )
    }
  }
  invisible(NULL)
}

# Shared scalar-argument validation for janusplot() and janusplot_data().
# Both public entry points apply these five checks identically, so they
# delegate here rather than duplicate the logic. `call` is forwarded so the
# abort is reported against the calling entry point, not this helper.
.validate_shared_scalars <- function(discrete, nthreads, auto_refit_k,
                                     k_max_iter, derivative_ci_nsim,
                                     call = rlang::caller_env()) {
  if (!is.logical(discrete) || length(discrete) != 1L || is.na(discrete)) {
    cli::cli_abort("{.arg discrete} must be TRUE or FALSE.", call = call)
  }
  if (!is.numeric(nthreads) || length(nthreads) != 1L ||
      !is.finite(nthreads) || nthreads < 1L) {
    cli::cli_abort(
      "{.arg nthreads} must be a single positive integer.",
      call = call
    )
  }
  if (!is.logical(auto_refit_k) || length(auto_refit_k) != 1L ||
      is.na(auto_refit_k)) {
    cli::cli_abort("{.arg auto_refit_k} must be TRUE or FALSE.", call = call)
  }
  if (!is.numeric(k_max_iter) || length(k_max_iter) != 1L ||
      !is.finite(k_max_iter) || k_max_iter < 0) {
    cli::cli_abort(
      "{.arg k_max_iter} must be a single non-negative integer.",
      call = call
    )
  }
  if (!is.numeric(derivative_ci_nsim) || length(derivative_ci_nsim) != 1L ||
      !is.finite(derivative_ci_nsim) || derivative_ci_nsim < 100) {
    cli::cli_abort(
      "{.arg derivative_ci_nsim} must be a single integer >= 100.",
      call = call
    )
  }
  invisible(NULL)
}

# ---------------------------------------------------------------
# Resolve vars -- default to all numeric columns, validate otherwise
# ---------------------------------------------------------------

.resolve_vars <- function(data, vars) {
  if (is.null(vars)) {
    vars <- names(data)[vapply(data, is.numeric, logical(1L))]
    if (length(vars) < 2L) {
      cli::cli_abort(c(
        "{.arg data} has fewer than 2 numeric columns.",
        i = "Supply {.arg vars} explicitly, or add numeric columns."
      ))
    }
    return(vars)
  }
  if (length(vars) < 2L) {
    cli::cli_abort("{.arg vars} must have length >= 2.")
  }
  not_numeric <- vars[!vapply(data[vars], is.numeric, logical(1L))]
  if (length(not_numeric)) {
    cli::cli_abort(c(
      "Non-numeric column{?s} in {.arg vars}: {.val {not_numeric}}.",
      i = "janusplot() models smooth associations only over numeric variables."
    ))
  }
  vars
}

# ---------------------------------------------------------------
# Resolve k: either scalar or named list per variable
# ---------------------------------------------------------------

.resolve_k <- function(k, var_name) {
  if (is.list(k)) {
    k[[var_name]] %||% -1L
  } else {
    k
  }
}

# mgcv's default basis dimension for a univariate smooth of type `bs`
# when k = -1, read from the smooth.construct.<bs>.smooth.spec methods
# (mgcv 1.9) at the default penalty order `m` (janusplot never sets m):
#   tp, ts     -- null-space dimension M = 2 plus def.k = 8, so 10;
#   cr, cs, cc -- 10;
#   ps, cp     -- max(10, m[1] + 1) = 10 with m = c(2, 2) (cp: max(10, m[1]));
#   bs         -- max(10, m[1]) = 10 with m = c(3, 2).
# Any other basis returns NA: its default is left to mgcv and not capped.
.default_k_for_bs <- function(bs) {
  if (as.character(bs)[1L] %in%
      c("tp", "ts", "cr", "cs", "cc", "ps", "cp", "bs")) {
    10L
  } else {
    NA_integer_
  }
}

# Smallest basis dimension mgcv fits for a univariate smooth of type
# `bs` at the default `m` (checked against mgcv 1.9.4): below it mgcv
# raises k itself or fails, so capping lower would not help.
.min_k_for_bs <- function(bs) {
  switch(as.character(bs)[1L],
    cc = 4L,
    ps = 4L,
    bs = 5L,
    3L
  )
}

# Resolve the basis dimension for one ordered pair from that pair's own
# rows. mgcv refuses (tp, cr, cs) or warns (ps, bs) when k exceeds the
# number of distinct covariate values, so the effective k is
#   k_used = min(k requested or the mgcv default for bs, n_unique).
# `k_fit` is what goes into the formula: the user's value unchanged
# (including -1 for the mgcv default) unless the cap applies, so
# uncapped fits are identical to an uncapped call. A predictor with
# fewer distinct values than the basis minimum is not capped: no smooth
# of that basis can be fitted, and mgcv's own error is kept.
.resolve_pair_k <- function(k_val, bs, n_unique) {
  k_requested <- if (is.na(k_val) || k_val < 0) {
    .default_k_for_bs(bs)
  } else {
    as.integer(k_val)
  }
  k_capped <- !is.na(k_requested) && k_requested > n_unique &&
    n_unique >= .min_k_for_bs(bs)
  list(
    k_requested = k_requested,
    k_used      = if (k_capped) as.integer(n_unique) else k_requested,
    k_capped    = k_capped,
    k_fit       = if (k_capped) as.integer(n_unique) else k_val
  )
}

# ---------------------------------------------------------------
# Extract names of variables referenced in an adjust formula RHS
# ---------------------------------------------------------------

.adjust_vars <- function(adjust) {
  if (is.null(adjust)) return(character())
  all.vars(adjust)
}

# ---------------------------------------------------------------
# Internal aliasing for non-syntactic column names
# ---------------------------------------------------------------
# mgcv cannot parse s() on a non-syntactic name even when backticked,
# so fits run on make.names() aliases. All-syntactic input is returned
# untouched.

.alias_columns <- function(data, vars, adjust) {
  cols <- intersect(unique(c(vars, .adjust_vars(adjust))), names(data))
  aliases <- make.names(cols, unique = TRUE)
  if (identical(aliases, cols)) {
    return(list(data = data, vars = vars, adjust = adjust,
                aliased = FALSE, map = NULL))
  }
  work <- data[, cols, drop = FALSE]
  names(work) <- aliases
  lookup <- stats::setNames(aliases, cols)
  if (!is.null(adjust)) {
    adjust[[2L]] <- .rename_symbols(adjust[[2L]], lookup)
  }
  list(
    data    = work,
    vars    = unname(lookup[vars]),
    adjust  = adjust,
    aliased = TRUE,
    map     = stats::setNames(cols, aliases)
  )
}

# Replace every symbol named in `lookup` (original -> alias) inside a
# call, leaving function heads and constants alone.
.rename_symbols <- function(expr, lookup) {
  if (is.name(expr)) {
    nm <- as.character(expr)
    if (nzchar(nm) && nm %in% names(lookup)) {
      return(as.name(lookup[[nm]]))
    }
    return(expr)
  }
  if (is.call(expr) && length(expr) > 1L) {
    for (i in 2:length(expr)) {
      if (!identical(expr[[i]], quote(expr = ))) {
        expr[[i]] <- .rename_symbols(expr[[i]], lookup)
      }
    }
  }
  expr
}

# Per-variable k lists are keyed by original names; re-key them onto
# the aliases so .resolve_k() finds them.
.alias_k <- function(k, map) {
  if (!is.list(k) || is.null(map) || is.null(names(k))) return(k)
  rev_map <- stats::setNames(names(map), map)
  hit <- names(k) %in% names(rev_map)
  names(k)[hit] <- rev_map[names(k)[hit]]
  k
}

# Aliases -> original names in message text: whole tokens, one pass,
# so an alias equal to another column's original name is not rewritten
# twice.
.restore_names_in_text <- function(txt, map) {
  if (is.null(map) || !length(txt)) return(txt)
  changed <- map[names(map) != map]
  if (!length(changed)) return(txt)
  keys <- names(changed)[order(nchar(names(changed)), decreasing = TRUE)]
  esc <- gsub("([.\\\\])", "\\\\\\1", keys)
  pattern <- paste0("(?<![A-Za-z0-9._])(", paste(esc, collapse = "|"),
                    ")(?![A-Za-z0-9._])")
  vapply(txt, function(t) {
    if (is.na(t)) return(t)
    m <- gregexpr(pattern, t, perl = TRUE)
    hits <- regmatches(t, m)[[1L]]
    if (!length(hits)) return(t)
    regmatches(t, m) <- list(unname(changed[hits]))
    t
  }, character(1L), USE.NAMES = FALSE)
}

# Put the original names back on a fitted cell.
.restore_fit_names <- function(f, map) {
  f$x_name <- map[[f$x_name]]
  f$y_name <- map[[f$y_name]]
  if (is.data.frame(f$raw) && ncol(f$raw) > 0L) {
    nm <- names(f$raw)
    hit <- nm %in% names(map)
    nm[hit] <- map[nm[hit]]
    names(f$raw) <- nm
  }
  if (!is.null(f$error) && !is.na(f$error)) {
    f$error <- .restore_names_in_text(f$error, map)
  }
  f
}

# Original column name for an internal (possibly aliased) name.
.original_names <- function(nms, map) {
  if (is.null(map)) return(nms)
  unname(map[nms])
}

# Character and logical adjust variables make mgcv fail on model-frame
# construction; coerce them to factor so fixed and random-effect terms
# both work.
.coerce_adjust_factors <- function(data, vars, adjust, map = NULL,
                                   quiet = FALSE) {
  adj <- setdiff(intersect(.adjust_vars(adjust), names(data)), vars)
  to_coerce <- adj[vapply(data[adj], function(col) {
    is.character(col) || is.logical(col)
  }, logical(1L))]
  if (!length(to_coerce)) return(data)
  for (nm in to_coerce) data[[nm]] <- factor(data[[nm]])
  if (quiet) return(data)
  coerced <- .original_names(to_coerce, map)                  # nolint: object_usage_linter.
  cli::cli_inform(c(
    i = "Converted character or logical {.arg adjust} column{?s} {.val {coerced}} to factor."
  ))
  data
}

# mgcv fails on +/-Inf; treat them as missing so pairwise or listwise
# deletion removes them and n_used counts only finite rows.
.drop_infinite <- function(data, vars, adjust, map = NULL, quiet = FALSE) {
  cols <- intersect(unique(c(vars, .adjust_vars(adjust))), names(data))
  cols <- cols[vapply(data[cols], is.numeric, logical(1L))]
  n_inf <- vapply(data[cols], function(col) sum(is.infinite(col)),
                  integer(1L))
  hit <- cols[n_inf > 0L]
  if (!length(hit)) return(data)
  for (nm in hit) data[[nm]][is.infinite(data[[nm]])] <- NA
  if (quiet) return(data)
  counts <- paste0(.original_names(hit, map), " (", n_inf[hit], ")") # nolint: object_usage_linter.
  cli::cli_warn(c(
    "!" = "Infinite values treated as missing in column{?s}: {counts}.",
    i = "Affected rows are dropped from every cell that uses those columns."
  ))
  data
}

# ---------------------------------------------------------------
# Build the pairwise GAM formula
# ---------------------------------------------------------------

.build_formula <- function(y_name, x_name, k_val, bs, adjust) {
  rhs <- sprintf("s(`%s`, k = %d, bs = %s)", x_name, as.integer(k_val),
                 deparse(bs))
  if (!is.null(adjust)) {
    adj_rhs <- deparse(adjust[[2L]], width.cutoff = 500L)
    adj_rhs <- paste(adj_rhs, collapse = " ")
    rhs <- paste(rhs, "+", adj_rhs)
  }
  stats::as.formula(sprintf("`%s` ~ %s", y_name, rhs))
}

# ---------------------------------------------------------------
# Subset data to complete cases on the variables a pair uses
# ---------------------------------------------------------------

# The columns a pair's fit is complete on: x, y and the adjust variables
# that exist in `data`.
.pair_columns <- function(data, x_name, y_name, adjust) {
  cols <- unique(c(x_name, y_name, .adjust_vars(adjust)))
  intersect(cols, names(data))
}

.complete_pair <- function(data, x_name, y_name, adjust) {
  sub <- data[, .pair_columns(data, x_name, y_name, adjust), drop = FALSE]
  sub[stats::complete.cases(sub), , drop = FALSE]
}

# ---------------------------------------------------------------
# Hold adjust-covariates at "typical" values for prediction
# numeric -> mean; factor -> most common level. A factor that only
# enters through a random-effect term keeps the modal level as a valid
# placeholder; that term is excluded from prediction (see below).
# ---------------------------------------------------------------

.typical_newdata <- function(train_data, x_name, x_grid, adjust) {
  nd <- data.frame(placeholder = x_grid)
  names(nd) <- x_name
  adj_names <- setdiff(.adjust_vars(adjust), x_name)
  for (nm in adj_names) {
    col <- train_data[[nm]]
    if (is.null(col)) next
    nd[[nm]] <- if (is.numeric(col)) {
      mean(col, na.rm = TRUE)
    } else if (is.factor(col)) {
      tb <- sort(table(col), decreasing = TRUE)
      factor(names(tb)[1L], levels = levels(col))
    } else {
      tb <- sort(table(col), decreasing = TRUE)
      names(tb)[1L]
    }
  }
  nd
}

# ---------------------------------------------------------------
# Random-effect smooth terms to drop from prediction, so the curve,
# its band and its derivatives are population-level rather than
# conditional on whichever group the prediction grid happens to name.
# Covers `bs = "re"` (class random.effect) and factor-smooth
# interactions `bs = "fs"` (class fs.interaction), both of which are
# random effects in mgcv's mixed-model representation.
# ---------------------------------------------------------------

.random_effect_terms <- function(fit) {
  if (is.null(fit) || !length(fit$smooth)) return(character())
  is_re <- vapply(fit$smooth, function(sm) {
    inherits(sm, c("random.effect", "fs.interaction"))
  }, logical(1L))
  vapply(fit$smooth[is_re], function(sm) sm$label, character(1L))
}

# Predict on the grid, excluding random-effect terms when there are
# any. The grid already carries a valid level for every factor, so
# mgcv's newdata checks can be skipped (`newdata.guaranteed = TRUE`).
.predict_population <- function(fit, newdata, exclude, ...) {
  if (length(exclude)) {
    stats::predict(fit, newdata = newdata, exclude = exclude,
                   newdata.guaranteed = TRUE, ...)
  } else {
    stats::predict(fit, newdata = newdata, ...)
  }
}

# What each adjust variable is held at on the prediction grid: the
# mean for a numeric covariate, the most frequent level for a factor,
# or "excluded (random effect)" when every model term using the
# variable is a random-effect smooth dropped from prediction.
.prediction_reference <- function(fit, newdata, x_name, adjust, exclude) {
  adj_names <- setdiff(.adjust_vars(adjust), x_name)
  adj_names <- intersect(adj_names, names(newdata))
  empty <- data.frame(variable = character(), reference = character(),
                      value = numeric(), stringsAsFactors = FALSE)
  if (!length(adj_names)) return(empty)
  kept_vars <- character()
  excl_vars <- character()
  if (!is.null(fit$pterms)) {
    kept_vars <- all.vars(stats::delete.response(fit$pterms))
  }
  for (sm in fit$smooth) {
    sm_vars <- setdiff(c(sm$term, sm$by), "NA")
    if (sm$label %in% exclude) {
      excl_vars <- c(excl_vars, sm_vars)
    } else {
      kept_vars <- c(kept_vars, sm_vars)
    }
  }
  rows <- lapply(adj_names, function(nm) {
    val <- newdata[[nm]][1L]
    if (nm %in% excl_vars && !(nm %in% kept_vars)) {
      ref <- "excluded (random effect)"
      num <- NA_real_
    } else if (is.numeric(val)) {
      ref <- format(signif(val, 6L))
      num <- as.numeric(val)
    } else {
      ref <- as.character(val)
      num <- NA_real_
    }
    data.frame(variable = nm, reference = ref, value = num,
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# ---------------------------------------------------------------
# Partial residuals under adjustment (identity link only)
#
# For row i the fit's linear predictor is eta_i = f(x_i) + a_i + b_i, where
# a_i is the contribution of the fixed adjust terms at that row's
# covariates and b_i that of its random effects. The reference curve
# f(x) + a_ref holds the covariates at typical values with random effects
# excluded. Then
#   offset_i  = eta_i - (f(x_i) + a_ref)      (this row's whole adjustment)
#   shift     = mean(a_i - a_ref)              (the average fixed adjustment)
#   partial_i = y_i - offset_i + shift
# and the curve is moved up by `shift`. Every point keeps its residual
# from the fit, the cloud and the curve share one level, and the curve is
# the smooth averaged over the data's fixed adjustment covariates with
# random effects at their population mean of zero. Returns NULL when the
# predictions cannot be formed, so the caller keeps raw points.
# ---------------------------------------------------------------

.partial_residuals <- function(fit, dat, x_name, y_name, adjust, re_terms) {
  eta_obs <- tryCatch(as.numeric(stats::predict(fit, newdata = dat)),
                      error = function(e) NULL)
  eta_fixed <- tryCatch(as.numeric(.predict_population(fit, dat, re_terms)),
                        error = function(e) NULL)
  nd_ref <- .typical_newdata(dat, x_name, dat[[x_name]], adjust)
  eta_ref <- tryCatch(as.numeric(.predict_population(fit, nd_ref, re_terms)),
                      error = function(e) NULL)
  n <- nrow(dat)
  ok <- function(v) !is.null(v) && length(v) == n && !anyNA(v)
  if (!ok(eta_obs) || !ok(eta_fixed) || !ok(eta_ref)) return(NULL)
  offset <- eta_obs - eta_ref
  shift <- mean(eta_fixed - eta_ref)
  list(partial = dat[[y_name]] - offset + shift, shift = shift)
}

# ---------------------------------------------------------------
# Analytic pointwise derivatives of a univariate mgcv::gam smooth via
# the LP (linear-predictor) matrix. Let X_p be the LP matrix evaluated
# on the plotting grid, with beta = coef(fit) and V_p = fit$Vp the
# Bayesian posterior covariance of the coefficients. If D is a matrix
# whose rows finite-difference the rows of X_p at order k, then
#   f^{(k)}_hat = D %*% beta,   Var(f^{(k)}_hat) = D %*% V_p %*% t(D),
# and the pointwise pairwise SE is sqrt(diag(.)). See Wood (2017)
# Generalized Additive Models, 2nd ed., 7.2.4; Simpson (2018)
# Frontiers in Ecology and Evolution for the simultaneous-CI extension.
#
# When the model also includes `adjust` terms held at typical values,
# the corresponding columns of X_p are identical across grid rows,
# their finite differences are zero, and they contribute nothing to
# either estimate or variance. So the derivative is with respect to
# x_i of the (partial) fit shown in the cell -- i.e. exactly what the
# user sees in the fit panel.
# Random-effect terms are passed as `exclude`, which zeroes their LP
# columns; as they are constant across the grid this leaves the
# derivative unchanged and keeps it consistent with the fit panel.
#
# Returns a named list keyed by order ("1", "2", ...) of data frames
# with the same schema as fit_obj$pred so the cell renderer can
# consume fit and derivative panels uniformly.
# ---------------------------------------------------------------

.derivatives_lpmatrix <- function(fit, newdata, x_grid, orders,
                                  exclude = character()) {
  if (!length(orders)) return(list())
  if (is.null(fit) || !inherits(fit, "gam")) return(list())
  if (!is.numeric(x_grid) || length(x_grid) < 3L) return(list())
  h <- mean(diff(x_grid))
  if (!is.finite(h) || h <= 0) return(list())
  Xp <- tryCatch(
    .predict_population(fit, newdata, exclude, type = "lpmatrix"),
    error = function(e) NULL
  )
  if (is.null(Xp) || !is.matrix(Xp) || nrow(Xp) != length(x_grid)) {
    return(list())
  }
  Vp   <- fit$Vp
  beta <- stats::coef(fit)
  if (is.null(Vp) || is.null(beta) ||
      ncol(Xp) != length(beta) || any(dim(Vp) != length(beta))) {
    return(list())
  }
  out <- list()
  for (k in orders) {
    k_int <- as.integer(k)
    if (!is.finite(k_int) || k_int < 1L) next
    D <- .diff_stencil(Xp, h = h, order = k_int)
    if (is.null(D)) next
    d_hat <- as.numeric(D %*% beta)
    # diag(D %*% Vp %*% t(D)) without materialising the full product:
    se_sq <- rowSums((D %*% Vp) * D)
    se_sq[!is.finite(se_sq) | se_sq < 0] <- 0
    se    <- sqrt(se_sq)
    out[[as.character(k_int)]] <- data.frame(
      x   = x_grid,
      fit = d_hat,
      se  = se,
      lo  = d_hat - 1.96 * se,
      hi  = d_hat + 1.96 * se
    )
  }
  out
}

# Simultaneous confidence bands for the derivative curve via the
# Ruppert, Wand & Carroll (2003) / Simpson (2018) Monte Carlo
# construction: draw beta* ~ N(beta_hat, V_p), compute the
# normalised max-deviation statistic max_x |D_i (beta* - beta_hat)|
# / se_i across the plotting grid, and use the (1 - alpha) quantile
# as a critical multiplier on the pointwise SE. Returns only the
# replacement `lo` and `hi` columns (plus the critical multiplier
# for diagnostic record) -- the point estimate and pointwise SE are
# unchanged and are reused from `.derivatives_lpmatrix()`.

.derivatives_simultaneous_bands <- function(fit, newdata, x_grid, orders,
                                            n_sim = 1000L, alpha = 0.05,
                                            exclude = character()) {
  if (!length(orders)) return(list())
  if (is.null(fit) || !inherits(fit, "gam")) return(list())
  if (!is.numeric(x_grid) || length(x_grid) < 3L) return(list())
  h <- mean(diff(x_grid))
  if (!is.finite(h) || h <= 0) return(list())
  Xp <- tryCatch(
    .predict_population(fit, newdata, exclude, type = "lpmatrix"),
    error = function(e) NULL
  )
  if (is.null(Xp) || !is.matrix(Xp) || nrow(Xp) != length(x_grid)) {
    return(list())
  }
  Vp   <- fit$Vp
  beta <- stats::coef(fit)
  p    <- length(beta)
  if (is.null(Vp) || is.null(beta) ||
      ncol(Xp) != p || any(dim(Vp) != p)) return(list())

  # Cholesky of V_p with small diagonal jitter fallback for the
  # occasional near-singular case at high basis dimension.
  L <- tryCatch(
    chol(Vp),
    error = function(e) {
      tryCatch(
        chol(Vp + diag(sqrt(.Machine$double.eps), p)),
        error = function(e2) NULL
      )
    }
  )
  if (is.null(L)) return(list())

  # dB[b, ] = beta*_b - beta_hat, drawn as Z %*% L with Z standard
  # normal (n_sim x p). Keeps memory O(n_sim * p), fast for
  # n_sim = 1000 and basis ranks in the low tens. The caller's RNG
  # stream is left where it was.
  Z  <- .with_preserved_seed(matrix(stats::rnorm(n_sim * p), nrow = n_sim))
  dB <- Z %*% L

  out <- list()
  for (k in orders) {
    k_int <- as.integer(k)
    D <- .diff_stencil(Xp, h = h, order = k_int)
    if (is.null(D)) next
    d_hat <- as.numeric(D %*% beta)
    se_sq <- rowSums((D %*% Vp) * D)
    se_sq[!is.finite(se_sq) | se_sq < 0] <- 0
    se_pw <- sqrt(se_sq)
    # Deviation matrix: (n_grid x p) %*% (p x n_sim) = (n_grid x n_sim).
    dev_mat <- D %*% t(dB)
    ok <- se_pw > 0 & is.finite(se_pw)
    if (!any(ok)) next
    dev_std <- matrix(0, nrow = nrow(dev_mat), ncol = ncol(dev_mat))
    dev_std[ok, ] <- dev_mat[ok, ] / se_pw[ok]
    max_abs_dev <- apply(abs(dev_std), 2L, max, na.rm = TRUE)
    crit <- as.numeric(stats::quantile(
      max_abs_dev, probs = 1 - alpha, na.rm = TRUE, names = FALSE
    ))
    if (!is.finite(crit)) next
    out[[as.character(k_int)]] <- list(
      lo = d_hat - crit * se_pw,
      hi = d_hat + crit * se_pw,
      crit_multiplier = crit
    )
  }
  out
}

# Finite-difference stencil on the rows of an LP matrix. Central
# differences in the interior; second-order-accurate forward/backward
# stencils at the two endpoints so the derivative is defined on the
# full plotting grid. Orders beyond 2 iterate the first-order stencil;
# accuracy degrades rapidly and we advise against k >= 3 in the docs.
.diff_stencil <- function(X, h, order) {
  n <- nrow(X)
  if (is.null(n) || n < 3L) return(NULL)
  if (order == 1L) {
    D <- matrix(0, nrow = n, ncol = ncol(X))
    # forward at the left endpoint (second-order): (-3*X[1] + 4*X[2] - X[3]) / (2h)
    D[1L, ]  <- (-3 * X[1L, ] + 4 * X[2L, ] - X[3L, ]) / (2 * h)
    # backward at the right endpoint (second-order)
    D[n, ]   <- (3 * X[n, ]  - 4 * X[n - 1L, ] + X[n - 2L, ]) / (2 * h)
    idx      <- 2:(n - 1L)
    D[idx, ] <- (X[idx + 1L, ] - X[idx - 1L, ]) / (2 * h)
    return(D)
  }
  if (order == 2L) {
    if (n < 4L) return(NULL)
    D <- matrix(0, nrow = n, ncol = ncol(X))
    # Four-point second-order forward/backward stencils at endpoints;
    # three-point central in the interior.
    D[1L, ] <- (2 * X[1L, ] - 5 * X[2L, ] + 4 * X[3L, ] - X[4L, ]) / h^2
    D[n, ]  <- (2 * X[n, ]  - 5 * X[n - 1L, ] +
                4 * X[n - 2L, ] - X[n - 3L, ]) / h^2
    idx      <- 2:(n - 1L)
    D[idx, ] <- (X[idx + 1L, ] - 2 * X[idx, ] + X[idx - 1L, ]) / h^2
    return(D)
  }
  # Order >= 3: iterate. Not exposed in janusplot() by default; present
  # for diagnostic completeness.
  D <- .diff_stencil(X, h, 1L)
  for (i in 2:order) D <- .diff_stencil(D, h, 1L)
  D
}

# ---------------------------------------------------------------
# Pairwise correlations on the complete-case (x, y) subset.
# Computed once per fit and cached on the fit object so downstream
# rendering + data-table construction is free. Also records the
# tie ratio (max of x, y) so callers can flag Spearman coefficients
# computed on heavily tied variables.
# ---------------------------------------------------------------

.compute_correlations <- function(dat, x_name, y_name) {
  na_out <- list(
    cor_pearson  = NA_real_,
    cor_spearman = NA_real_,
    cor_kendall  = NA_real_,
    tie_ratio    = NA_real_
  )
  if (is.null(dat) || nrow(dat) < 3L) return(na_out)
  x <- dat[[x_name]]
  y <- dat[[y_name]]
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]
  if (length(x) < 3L) return(na_out)
  safe_cor <- function(m) {
    tryCatch(
      stats::cor(x, y, method = m),
      error = function(e) NA_real_,
      warning = function(w) suppressWarnings(stats::cor(x, y, method = m))
    )
  }
  n <- length(x)
  tie_x <- 1 - length(unique(x)) / n
  tie_y <- 1 - length(unique(y)) / n
  list(
    cor_pearson  = safe_cor("pearson"),
    cor_spearman = safe_cor("spearman"),
    cor_kendall  = safe_cor("kendall"),
    tie_ratio    = max(tie_x, tie_y)
  )
}

# ---------------------------------------------------------------
# Fit a single pairwise GAM and summarise
# ---------------------------------------------------------------

# ---------------------------------------------------------------
# Fitting-engine dispatch (Feature 4). `bam` is mgcv's "big additive
# model" -- same formula language as `gam`, but uses fREML (fast REML)
# by default, block-Lanczos / discrete-method optimisations for the
# basis-coefficient solve, lower memory, and a built-in `nthreads`
# argument. bam objects inherit from gam (`class(b)` ==
# c("bam", "gam", "glm", "lm")) so every downstream code path
# (predict, summary, k.check, derivative LP-matrix arithmetic)
# works without modification -- engine is plumbing, not redesign.
#
# Default method-per-engine: `fREML` for bam (mgcv's recommended at
# scale), `REML` for gam (v0.1.0 behaviour). A user-supplied `method`
# overrides both.
# ---------------------------------------------------------------

.engine_default_method <- function(engine) {
  if (identical(engine, "bam")) "fREML" else "REML"
}

.fit_one_gam <- function(fml, dat, engine, method, discrete, nthreads, ...) {
  method <- if (is.null(method) || identical(method, "auto") ||
                identical(method, "default")) {
    .engine_default_method(engine)
  } else {
    method
  }
  if (identical(engine, "bam")) {
    mgcv::bam(
      formula  = fml,
      data     = dat,
      method   = method,
      discrete = isTRUE(discrete),
      nthreads = as.integer(nthreads %||% 1L),
      ...
    )
  } else {
    mgcv::gam(formula = fml, data = dat, method = method, ...)
  }
}

# ---------------------------------------------------------------
# Deviance gap: deviance explained by the smooth minus deviance
# explained by the straight-line fit of the same ordered pair, with
# the same adjust terms, engine, method and family, clamped to
# [0, 1]. Penalisation can leave a smooth that is shrunk to a line
# fractionally below the unpenalised line; that rounds to a gap of 0.
# ---------------------------------------------------------------

.deviance_gap <- function(fit, dev_exp, dat, x_name, y_name, adjust,
                          engine, method, discrete, nthreads, ...) {
  if (!is.finite(dev_exp)) return(NA_real_)
  rhs <- sprintf("`%s`", x_name)
  if (!is.null(adjust)) {
    adj_rhs <- paste(deparse(adjust[[2L]], width.cutoff = 500L),
                     collapse = " ")
    rhs <- paste(rhs, "+", adj_rhs)
  }
  lin_fml <- stats::as.formula(sprintf("`%s` ~ %s", y_name, rhs))
  has_other_smooths <- length(fit$smooth) > 1L
  lin <- tryCatch(
    .fit_one_gam(lin_fml, dat, engine = engine, method = method,
                 discrete = isTRUE(discrete) && has_other_smooths,
                 nthreads = nthreads, ...),
    error = function(e) NULL
  )
  if (is.null(lin)) return(NA_real_)
  dev_lin <- summary(lin)$dev.expl %||% NA_real_
  if (!is.finite(dev_lin)) return(NA_real_)
  min(1, max(0, dev_exp - dev_lin))
}

.fit_pair <- function(x_name, y_name, data_full, adjust, method, k, bs,
                     na_action, n_grid = 100L,
                     derivatives = integer(),
                     derivative_ci = "pointwise",
                     derivative_ci_nsim = 1000L,
                     k_check_thresholds = .default_k_thresholds(),
                     auto_refit_k = FALSE,
                     k_max_iter = 2L,
                     engine = "bam",
                     discrete = FALSE,
                     nthreads = 1L, ...) {
  k_val <- .resolve_k(k, x_name)
  if (na_action == "pairwise") {
    dat <- .complete_pair(data_full, x_name, y_name, adjust)
  } else {
    dat <- data_full
  }
  n_used <- nrow(dat)
  if (n_used < 5L) {
    return(.empty_fit_result(x_name, y_name, n_used))
  }
  degenerate <- .degenerate_pair_message(dat[[x_name]], dat[[y_name]],
                                         x_name, y_name)
  if (!is.na(degenerate)) {
    out <- .empty_fit_result(x_name, y_name, NA_integer_)
    out$error <- degenerate
    return(out)
  }
  n_unique <- length(unique(dat[[x_name]]))
  k_res <- .resolve_pair_k(k_val, bs, n_unique)
  k_fit <- k_res$k_fit

  # Initial fit at user-requested k (mgcv resolves k=-1 internally),
  # capped at the pair's distinct x count when the request exceeds it.
  fml <- .build_formula(y_name, x_name, k_fit, bs, adjust)
  resolved_method <- if (is.null(method) || identical(method, "auto") ||
                         identical(method, "default")) {
    .engine_default_method(engine)
  } else {
    method
  }
  fit <- tryCatch(
    .fit_one_gam(fml, dat,
                 engine = engine, method = resolved_method,
                 discrete = discrete, nthreads = nthreads, ...),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    # The fit never completed, so n_used (a count of rows *offered* to
    # mgcv) would misrepresent a completed fit's sample size. Report it
    # as unknown rather than a number that looks like a successful cell.
    out <- .empty_fit_result(x_name, y_name, NA_integer_)
    out$error <- conditionMessage(fit)
    out$k_requested <- k_res$k_requested
    out$k_used      <- k_res$k_used
    out$k_capped    <- k_res$k_capped
    return(out)
  }

  # Strategy A -- diagnostic, always on.
  k_diag <- .k_check_one_pair(fit, x_name, n_unique,
                              thresholds = k_check_thresholds)
  k_initial <- if (k_fit < 0) {
    # mgcv default -- surface the actual k' from k.check, not -1.
    if (!is.na(k_diag$k_prime)) k_diag$k_prime + 1 else NA_real_
  } else {
    as.numeric(k_val)
  }
  k_iterations <- 0L
  k_at_cap <- FALSE

  # Strategy B -- opt-in doubling refit on flagged cells with usable n_unique.
  if (isTRUE(auto_refit_k) &&
      identical(k_diag$k_check_status, "flagged")) {
    k_cap <- n_unique - 1L
    k_cur <- if (is.na(k_initial)) {
      if (!is.na(k_diag$k_prime)) k_diag$k_prime + 1 else 10
    } else {
      k_initial
    }
    while (isTRUE(k_diag$k_flag) &&
           k_iterations < k_max_iter &&
           2 * k_cur <= k_cap) {
      k_new <- min(2 * k_cur, k_cap)
      fml_new <- .build_formula(y_name, x_name, k_new, bs, adjust)
      new_fit <- tryCatch(
        .fit_one_gam(fml_new, dat,
                     engine = engine, method = resolved_method,
                     discrete = discrete, nthreads = nthreads, ...),
        error = function(e) e
      )
      if (inherits(new_fit, "error")) break
      fit <- new_fit
      k_cur <- k_new
      k_iterations <- k_iterations + 1L
      k_diag <- .k_check_one_pair(fit, x_name, n_unique,
                                  thresholds = k_check_thresholds)
      if (k_new >= k_cap) {
        k_at_cap <- TRUE
        break
      }
    }
    k_final <- k_cur
  } else {
    k_final <- k_initial
  }
  # After a refit, k_used reports the basis dimension of the returned fit;
  # the refit cap (n_unique - 1) keeps it below the distinct-value limit.
  k_used <- if (k_iterations > 0L) as.integer(k_final) else k_res$k_used

  smry <- summary(fit)
  # First smooth term is s(x); paranoid guard in case mgcv reorders
  s_row <- which(rownames(smry$s.table) ==
                   sprintf("s(%s)", x_name))[1L]
  if (is.na(s_row)) s_row <- 1L
  edf <- unname(smry$s.table[s_row, "edf"])
  pval <- unname(smry$s.table[s_row, "p-value"])
  dev_exp <- unname(smry$dev.expl %||% NA_real_)
  deviance_gap <- .deviance_gap(fit, dev_exp, dat, x_name, y_name, adjust,
                                engine = engine, method = resolved_method,
                                discrete = discrete, nthreads = nthreads,
                                ...)

  # Prediction grid on the response scale, holding adjust covariates at typical values
  x_vals <- dat[[x_name]]
  x_grid <- seq(min(x_vals), max(x_vals), length.out = n_grid)
  # Random-effect terms are excluded so the curve and its band are
  # population-level, not conditional on the modal group.
  nd <- .typical_newdata(dat, x_name, x_grid, adjust)
  re_terms <- .random_effect_terms(fit)
  pred_ref <- .prediction_reference(fit, nd, x_name, adjust, re_terms)
  preds <- tryCatch(
    .predict_population(fit, nd, re_terms, se.fit = TRUE),
    error = function(e) NULL
  )
  if (is.null(preds)) {
    pred_df <- data.frame(
      x = x_grid, fit = NA_real_, se = NA_real_,
      lo = NA_real_, hi = NA_real_
    )
  } else {
    # mgcv predicts on the link scale; the band is formed there and
    # mapped through the inverse link, so it stays valid for any
    # monotone link. pmin/pmax keep lo <= hi for a decreasing link.
    eta <- as.numeric(preds$fit)
    se  <- as.numeric(preds$se.fit)
    linkinv <- fit$family$linkinv
    bound_a <- linkinv(eta - 1.96 * se)
    bound_b <- linkinv(eta + 1.96 * se)
    pred_df <- data.frame(
      x  = x_grid,
      fit = linkinv(eta),
      se  = se,
      lo  = pmin(bound_a, bound_b),
      hi  = pmax(bound_a, bound_b)
    )
    # The shape label is read on the link scale (the linear predictor).
    if (!identical(fit$family$link, "identity")) pred_df$fit_link <- eta
  }

  # Under adjustment with an identity link, the curve is moved to the
  # average adjustment and each point is drawn as a partial residual, so
  # the cloud and the curve share one level (see .partial_residuals()).
  partial <- NULL
  if (!is.null(adjust) && !is.null(preds) &&
      identical(fit$family$link, "identity")) {
    pr <- .partial_residuals(fit, dat, x_name, y_name, adjust, re_terms)
    if (!is.null(pr)) {
      partial <- pr$partial
      pred_df$fit <- pred_df$fit + pr$shift
      pred_df$lo  <- pred_df$lo + pr$shift
      pred_df$hi  <- pred_df$hi + pr$shift
      fixed <- pred_ref$reference != "excluded (random effect)"
      if (any(fixed)) {
        pred_ref$reference[fixed] <- "averaged over the data"
        pred_ref$value[fixed] <- NA_real_
      }
    }
  }

  deriv_list <- if (length(derivatives)) {
    .derivatives_lpmatrix(fit, nd, x_grid, derivatives, exclude = re_terms)
  } else {
    list()
  }
  # If the caller asked for simultaneous bands, replace the
  # pointwise lo/hi in the derivative data frames with the
  # simultaneous ones. Stamp a `ci_type` column on every derivative
  # frame so the renderer and downstream callers can tell them apart.
  if (length(deriv_list)) {
    for (k_nm in names(deriv_list)) {
      deriv_list[[k_nm]]$ci_type <- derivative_ci
    }
    if (identical(derivative_ci, "simultaneous")) {
      sim <- .derivatives_simultaneous_bands(
        fit, nd, x_grid, derivatives,
        n_sim = derivative_ci_nsim, exclude = re_terms
      )
      for (k_nm in names(sim)) {
        if (!is.null(deriv_list[[k_nm]])) {
          deriv_list[[k_nm]]$lo <- sim[[k_nm]]$lo
          deriv_list[[k_nm]]$hi <- sim[[k_nm]]$hi
          attr(deriv_list[[k_nm]], "crit_multiplier") <-
            sim[[k_nm]]$crit_multiplier
        }
      }
    }
  }

  out <- list(
    x_name   = x_name,
    y_name   = y_name,
    fit      = fit,
    pred     = pred_df,
    deriv    = deriv_list,
    raw      = dat[, c(x_name, y_name), drop = FALSE],
    partial  = partial,
    df_residual = as.numeric(fit$df.residual %||% NA_real_),
    edf      = edf,
    pvalue   = pval,
    dev_exp  = dev_exp,
    deviance_gap = deviance_gap,
    n_used   = n_used,
    error    = NA_character_,
    engine   = engine,
    method   = resolved_method,
    k_requested = k_res$k_requested,
    k_used      = k_used,
    k_capped    = isTRUE(k_res$k_capped) || k_at_cap,
    prediction_reference = pred_ref,
    k_check  = list(
      k_prime         = k_diag$k_prime,
      k_index         = k_diag$k_index,
      k_p             = k_diag$k_p,
      k_flag          = k_diag$k_flag,
      k_check_status  = k_diag$k_check_status,
      k_initial       = as.numeric(k_initial),
      k_final         = as.numeric(k_final),
      k_iterations    = as.integer(k_iterations),
      k_at_cap        = isTRUE(k_at_cap)
    )
  )
  out$corr  <- .compute_correlations(dat, x_name, y_name)
  out$shape <- .compute_shape_metrics_raw(out)
  out
}

# mgcv stops with an uninformative message when y is an exact copy or
# an exact affine transform of x, or when either column is constant on
# the pair's rows; name the cause instead.
.degenerate_pair_message <- function(x, y, x_name, y_name) {
  if (identical(x, y)) {
    return(sprintf("`%s` and `%s` are identical; no smooth can be fitted.",
                   x_name, y_name))
  }
  constant <- c(x_name, y_name)[c(stats::sd(x) == 0, stats::sd(y) == 0)]
  if (length(constant)) {
    return(sprintf(
      "`%s` is constant on the rows of this pair; no smooth can be fitted.",
      constant[1L]
    ))
  }
  if (stats::sd(x) > 0 && stats::sd(y) > 0) {
    r <- stats::cor(x, y)
    if (is.finite(r) && abs(1 - abs(r)) <= 1e-12) {
      return(sprintf(
        "`%s` and `%s` are perfectly collinear (|r| = 1); no smooth can be fitted.",
        x_name, y_name
      ))
    }
  }
  NA_character_
}

.empty_fit_result <- function(x_name, y_name, n_used) {
  list(
    x_name = x_name, y_name = y_name, fit = NULL,
    pred = data.frame(x = numeric(), fit = numeric(),
                      se = numeric(), lo = numeric(), hi = numeric()),
    deriv = list(),
    raw = data.frame(),
    edf = NA_real_, pvalue = NA_real_, dev_exp = NA_real_,
    deviance_gap = NA_real_,
    n_used = n_used, error = NA_character_,
    engine = NA_character_, method = NA_character_,
    k_requested = NA_integer_, k_used = NA_integer_, k_capped = NA,
    prediction_reference = data.frame(
      variable = character(), reference = character(),
      value = numeric(), stringsAsFactors = FALSE
    ),
    k_check = list(
      k_prime        = NA_real_,
      k_index        = NA_real_,
      k_p            = NA_real_,
      k_flag         = NA,
      k_check_status = NA_character_,
      k_initial      = NA_real_,
      k_final        = NA_real_,
      k_iterations   = 0L,
      k_at_cap       = FALSE
    ),
    corr  = list(cor_pearson = NA_real_, cor_spearman = NA_real_,
                 cor_kendall = NA_real_, tie_ratio = NA_real_),
    shape = .na_shape_raw()
  )
}

# ---------------------------------------------------------------
# Fit every ordered pair (i != j)
# ---------------------------------------------------------------

.fit_all_pairs <- function(data, vars, adjust, method, k, bs,
                           na_action, parallel,
                           n_grid = 100L,
                           derivatives = integer(),
                           derivative_ci = "pointwise",
                           derivative_ci_nsim = 1000L,
                           k_check_thresholds = .default_k_thresholds(),
                           auto_refit_k = FALSE,
                           k_max_iter = 2L,
                           engine = "bam",
                           discrete = FALSE,
                           nthreads = 1L, ...) {
  .check_parallel_plan(parallel)
  aliasing <- .alias_columns(data, vars, adjust)
  data   <- aliasing$data
  vars   <- aliasing$vars
  adjust <- aliasing$adjust
  k      <- .alias_k(k, aliasing$map)
  data   <- .coerce_adjust_factors(data, vars, adjust, aliasing$map)
  data   <- .drop_infinite(data, vars, adjust, aliasing$map)
  if (na_action == "complete") {
    data <- data[stats::complete.cases(
      data[, unique(c(vars, .adjust_vars(adjust))), drop = FALSE]
    ), , drop = FALSE]
  }
  grid <- expand.grid(i = seq_along(vars), j = seq_along(vars),
                      KEEP.OUT.ATTRS = FALSE)
  grid <- grid[grid$i != grid$j, , drop = FALSE]
  .check_any_pair_fittable(data, vars, adjust, na_action, aliasing$map,
                           call = rlang::caller_env())

  fit_one <- function(i, j) {
    .fit_pair(
      x_name = vars[i], y_name = vars[j],
      data_full = data, adjust = adjust,
      method = method, k = k, bs = bs,
      na_action = na_action,
      n_grid = n_grid, derivatives = derivatives,
      derivative_ci = derivative_ci,
      derivative_ci_nsim = derivative_ci_nsim,
      k_check_thresholds = k_check_thresholds,
      auto_refit_k = auto_refit_k,
      k_max_iter = k_max_iter,
      engine = engine, discrete = discrete,
      nthreads = nthreads, ...
    )
  }

  run_fits <- function() {
    if (isTRUE(parallel) && rlang::is_installed("future.apply")) {
      future.apply::future_mapply(
        fit_one, grid$i, grid$j, SIMPLIFY = FALSE,
        future.seed = TRUE
      )
    } else {
      mapply(fit_one, grid$i, grid$j, SIMPLIFY = FALSE)
    }
  }
  if (isTRUE(aliasing$aliased)) {
    # Warnings raised by mgcv name the aliases; re-signal them with the
    # original column names restored.
    fits <- withCallingHandlers(
      run_fits(),
      warning = function(w) {
        msg <- conditionMessage(w)
        restored <- .restore_names_in_text(msg, aliasing$map)
        if (!identical(restored, msg)) {
          warning(restored, call. = FALSE)
          invokeRestart("muffleWarning")
        }
      }
    )
    fits <- lapply(fits, .restore_fit_names, map = aliasing$map)
  } else {
    fits <- run_fits()
  }
  names(fits) <- sprintf("%d_%d", grid$i, grid$j)
  fits
}

# A single sparse pair never stops the matrix, but a matrix in which no
# pair reaches 5 shared rows has nothing to show.
.check_any_pair_fittable <- function(data, vars, adjust, na_action,
                                     map = NULL,
                                     call = rlang::caller_env()) {
  adj <- intersect(.adjust_vars(adjust), names(data))
  n_shared <- if (na_action == "complete") {
    nrow(data)
  } else {
    pairs <- utils::combn(vars, 2L, simplify = FALSE)
    vapply(pairs, function(p) {
      sum(stats::complete.cases(data[, unique(c(p, adj)), drop = FALSE]))
    }, integer(1L))
  }
  if (any(n_shared >= 5L)) return(invisible(NULL))
  max_shared <- max(n_shared)                                 # nolint: object_usage_linter.
  cli::cli_abort(c(
    "Every pair of {.arg vars} shares fewer than 5 complete rows.",
    i = "The largest shared count is {max_shared}; no cell can be fitted."
  ), call = call)
}

# ---------------------------------------------------------------
# Save and restore the global RNG state around an expression. Base-R
# substitute for withr::with_preserve_seed() so the runtime code path
# doesn't depend on `withr` (Suggests-only).
# ---------------------------------------------------------------

.with_preserved_seed <- function(expr) {
  old_seed <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else {
    NULL
  }
  on.exit({
    if (is.null(old_seed) &&
        exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(list = ".Random.seed", envir = .GlobalEnv)
    } else if (!is.null(old_seed)) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    }
  })
  force(expr)
}

# ---------------------------------------------------------------
# Per-cell k-check (Feature 1 -- Strategy A diagnostic, always-on)
# ---------------------------------------------------------------
#
# Wraps mgcv::k.check() on a fitted GAM with a single s() term. Returns
# a named list of diagnostic fields. Cells with n_unique < 10 are
# marked "unreliable" -- k.check's simulation p-value is meaningless
# at very low n_unique. Wood's flag-trifecta (edf/k' close to 1 AND
# k-index < 1 AND p-value < threshold) drives `k_flag`.
.k_check_one_pair <- function(fit, x_name, n_unique,
                              thresholds = .default_k_thresholds()) {
  na_pack <- list(
    k_prime         = NA_real_,
    k_index         = NA_real_,
    k_p             = NA_real_,
    k_flag          = NA,
    k_check_status  = NA_character_
  )
  if (is.null(fit) || inherits(fit, "error")) return(na_pack)
  if (is.na(n_unique) || n_unique < 10L) {
    na_pack$k_check_status <- "unreliable"
    return(na_pack)
  }
  # mgcv::k.check() runs its own simulation (default n.rep = 400) for
  # the basis-deficiency p-value. Isolate that RNG draw so the
  # diagnostic doesn't shift downstream MC consumers (simultaneous-CI
  # bands, future.seed reproducibility). Base-R seed-stash so this
  # works without `withr` at runtime (withr is Suggests-only).
  tab <- .with_preserved_seed(tryCatch(
    mgcv::k.check(fit),
    error = function(e) NULL
  ))
  if (is.null(tab) || !is.matrix(tab) || nrow(tab) < 1L) {
    return(na_pack)
  }
  row_label <- sprintf("s(%s)", x_name)
  row <- which(rownames(tab) == row_label)[1L]
  if (is.na(row)) row <- 1L
  k_prime <- unname(tab[row, "k'"])
  edf_val <- unname(tab[row, "edf"])
  k_index <- unname(tab[row, "k-index"])
  k_p     <- unname(tab[row, "p-value"])

  if (!is.finite(k_prime) || k_prime <= 0) {
    return(na_pack)
  }
  ratio <- edf_val / k_prime
  flag <- isTRUE(ratio    >  thresholds$edf_ratio) &&
          isTRUE(k_index  <  thresholds$k_index)   &&
          isTRUE(k_p      <  thresholds$p)
  list(
    k_prime         = as.numeric(k_prime),
    k_index         = as.numeric(k_index),
    k_p             = as.numeric(k_p),
    k_flag          = isTRUE(flag),
    k_check_status  = if (isTRUE(flag)) "flagged" else "ok"
  )
}

# Default k-check thresholds. Sourced from mgcv::gam.check() conventions
# and Wood (2017) section 5.9. Exposed via `k_check_thresholds` on the public
# API so users can tune.
.default_k_thresholds <- function() {
  list(edf_ratio = 0.9, k_index = 1.0, p = 0.05)
}

.validate_k_thresholds <- function(thresholds) {
  if (!is.list(thresholds)) {
    cli::cli_abort(
      "{.arg k_check_thresholds} must be a named list with edf_ratio / k_index / p."
    )
  }
  required <- c("edf_ratio", "k_index", "p")
  missing <- setdiff(required, names(thresholds))
  if (length(missing)) {
    cli::cli_abort(c(
      "{.arg k_check_thresholds} is missing entries: {.val {missing}}.",
      i = "Required: {.val {required}}."
    ))
  }
  for (nm in required) {
    v <- thresholds[[nm]]
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v <= 0) {
      cli::cli_abort(
        "{.arg k_check_thresholds${nm}} must be a single positive finite number."
      )
    }
  }
  invisible(thresholds)
}

# ---------------------------------------------------------------
# Cross-matrix k-check summary (Feature 1, console surface).
# Emits a 3-line cli_inform when at least one cell is flagged. Never
# fires when nothing is flagged or every cell is unreliable.
# ---------------------------------------------------------------

.warn_failed_cells <- function(fits) {
  if (!length(fits)) return(invisible(NULL))
  failed <- vapply(fits, function(f) {
    err <- f$error
    !is.null(err) && !is.na(err) && nzchar(err)
  }, logical(1L))
  # Cells that never reached mgcv because the pair shares < 5 rows.
  sparse <- !failed & vapply(fits, function(f) {
    n <- f$n_used
    !is.null(n) && !is.na(n) && n < 5L && is.null(f$fit)
  }, logical(1L))
  n_failed <- sum(failed)                                    # nolint: object_usage_linter.
  if (n_failed == 0L && !any(sparse)) return(invisible(NULL))
  n_cells <- length(fits)                                     # nolint: object_usage_linter.
  bullets <- character()
  if (n_failed > 0L) {
    first_msg <- fits[[which(failed)[1L]]]$error              # nolint: object_usage_linter.
    bullets <- c(
      "!" = "{n_failed} of {n_cells} cell{?s} failed to fit and carry no result.",
      i = "First failure: {first_msg}"
    )
  }
  if (any(sparse)) {
    sp <- fits[sparse]
    key <- vapply(sp, function(f) {
      paste(sort(c(f$x_name, f$y_name)), collapse = "\r")
    }, character(1L))
    sp <- sp[!duplicated(key)]
    sparse_pairs <- vapply(sp, function(f) {                  # nolint: object_usage_linter.
      sprintf("%s vs %s (n = %d)", f$y_name, f$x_name, as.integer(f$n_used))
    }, character(1L), USE.NAMES = FALSE)
    n_sparse <- length(sparse_pairs)                          # nolint: object_usage_linter.
    bullets <- c(
      bullets,
      "!" = paste(
        "{n_sparse} pair{?s} share{?s/} fewer than 5 complete rows and",
        "{?is/are} shown as {.val n < 5}: {sparse_pairs}."
      )
    )
  }
  bullets <- c(
    bullets,
    i = paste0(
      "Inspect {.code n_used}/{.code error} in the returned table -- a failed cell ",
      "reports {.code n_used = NA} and {.code edf = NA}, never a completed fit; ",
      "a sparse cell reports its shared-row count in {.code n_used}."
    )
  )
  cli::cli_warn(bullets)
  invisible(NULL)
}

# One message per call naming every predictor whose basis dimension was
# capped at its distinct-value count, with the k used. A predictor capped
# at one k in every pair is listed once; otherwise each pair is listed.
# A smooth with fewer than 5 residual degrees of freedom passes close to
# every point (11 rows and the default basis reach EDF 9), so its shape
# says little. One warning names every such cell.
.warn_low_residual_df <- function(fits, floor = 5) {
  low <- Filter(function(f) {
    df <- f$df_residual
    !is.null(df) && is.finite(df) && df < floor
  }, fits)
  if (!length(low)) return(invisible(NULL))
  cells <- vapply(low, function(f) {                             # nolint: object_usage_linter.
    sprintf("%s ~ s(%s) (n %d, EDF %.1f)", f$y_name, f$x_name,
            as.integer(f$n_used), f$edf)
  }, character(1L))
  cli::cli_warn(c(
    "!" = paste(
      "{length(low)} cell{?s} nearly interpolate{?s/} the data, with fewer",
      "than {floor} residual degrees of freedom: {cells}."
    ),
    i = "Read their shapes with care, or set a smaller {.arg k}, for example {.code k = 3L}."
  ))
  invisible(NULL)
}

.inform_k_capped <- function(fits) {
  capped <- Filter(function(f) isTRUE(f$k_capped), fits)
  if (!length(capped)) return(invisible(NULL))
  x_names <- vapply(capped, function(f) f$x_name, character(1L))
  y_names <- vapply(capped, function(f) f$y_name, character(1L))
  k_used  <- vapply(capped, function(f) as.integer(f$k_used), integer(1L))
  items <- unlist(lapply(unique(x_names), function(v) {         # nolint: object_usage_linter.
    sel <- x_names == v
    ks <- unique(k_used[sel])
    if (length(ks) == 1L) {
      sprintf("%s (k = %d)", v, ks)
    } else {
      sprintf("%s predicting %s (k = %d)", v, y_names[sel], k_used[sel])
    }
  }))
  n_capped <- length(capped)                                     # nolint: object_usage_linter.
  cli::cli_inform(c(
    i = paste(
      "Capped the basis dimension by the number of distinct predictor",
      "values in {n_capped} cell{?s}: {items}."
    ),
    i = "See {.code k_requested}, {.code k_used} and {.code k_capped} in the returned data."
  ))
  invisible(NULL)
}

.summarise_k_check <- function(fits, thresholds, auto_refit_k) {
  if (!length(fits)) return(invisible(NULL))
  status <- vapply(fits, function(f) {
    s <- f$k_check$k_check_status
    if (is.null(s) || length(s) == 0L) NA_character_ else as.character(s)
  }, character(1L))
  flag <- vapply(fits, function(f) isTRUE(f$k_check$k_flag), logical(1L))
  # The following locals look unused to lintr's object_usage_linter
  # because they're consumed via cli's `{var}` template interpolation
  # below. cli resolves them dynamically through .envir = parent.frame().
  n_cells     <- length(fits)                                # nolint: object_usage_linter.
  n_reliable  <- sum(status %in% c("ok", "flagged"))         # nolint: object_usage_linter.
  n_flagged   <- sum(flag, na.rm = TRUE)
  if (n_flagged == 0L) return(invisible(NULL))
  chance <- n_reliable * thresholds$p
  n_post_flagged <- sum(vapply(fits, function(f) {            # nolint: object_usage_linter.
    isTRUE(f$k_check$k_flag) && f$k_check$k_iterations > 0L
  }, logical(1L)))
  chance_txt    <- format(chance, digits = 2)                # nolint: object_usage_linter.
  alpha_txt     <- format(thresholds$p, digits = 2)          # nolint: object_usage_linter.
  if (isTRUE(auto_refit_k)) {
    cli::cli_inform(c(
      i = "{n_flagged} of {n_cells} cell{?s} flagged for possible k underfit.",
      i = "{chance_txt} expected by chance at alpha = {alpha_txt} across {n_reliable} test{?s}.",
      i = paste0(
        "{n_post_flagged} cell{?s} still flagged after refit; ",
        "consider raising {.arg k_max_iter} or inspecting them directly."
      )
    ))
  } else {
    cli::cli_inform(c(
      i = "{n_flagged} of {n_cells} cell{?s} flagged for possible k underfit.",
      i = "{chance_txt} expected by chance at alpha = {alpha_txt} across {n_reliable} test{?s}.",
      i = "Inspect {.code result$pairs[[i]]$k_check_*} or set {.code auto_refit_k = TRUE}."
    ))
  }
  invisible(NULL)
}

# ---------------------------------------------------------------
# Asymmetry index in [0, 1]
# ---------------------------------------------------------------

.compute_asymmetry_index <- function(edf_yx, edf_xy) {
  if (is.na(edf_yx) || is.na(edf_xy)) return(NA_real_)
  denom <- edf_yx + edf_xy
  if (!is.finite(denom) || denom <= 0) return(NA_real_)
  abs(edf_yx - edf_xy) / denom
}

# ---------------------------------------------------------------
# Reorder variables by hierarchical clustering of |cor|
# ---------------------------------------------------------------

.reorder_hclust <- function(data, vars) {
  mat <- stats::cor(data[, vars, drop = FALSE],
                    use = "pairwise.complete.obs")
  mat[is.na(mat)] <- 0
  d <- stats::as.dist(1 - abs(mat))
  if (length(vars) < 3L) return(vars)
  h <- stats::hclust(d, method = "average")
  vars[h$order]
}

# ---------------------------------------------------------------
# p-value -> glyph
# ---------------------------------------------------------------

.pvalue_to_glyph <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.001) "***"
  else if (p < 0.01) "**"
  else if (p < 0.05) "*"
  else if (p < 0.1) "\u00b7"  # middle dot
  else ""
}
