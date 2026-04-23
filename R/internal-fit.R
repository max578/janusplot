# Internal helpers — NOT EXPORTED.
# Fit-layer logic for janusplot(): input validation, formula assembly,
# GAM fitting, asymmetry index, and hclust reorder.

# Local null-coalesce (R >= 4.4 has this in base; keep local for 4.3 support).
`%||%` <- function(x, y) if (is.null(x)) y else x

# Argument validation — single positive scalar.
.check_scalar_positive <- function(x, arg_name) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0) {
    cli::cli_abort("{.arg {arg_name}} must be a single positive number.")
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

# ---------------------------------------------------------------
# Resolve vars — default to all numeric columns, validate otherwise
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

# ---------------------------------------------------------------
# Extract names of variables referenced in an adjust formula RHS
# ---------------------------------------------------------------

.adjust_vars <- function(adjust) {
  if (is.null(adjust)) return(character())
  all.vars(adjust)
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

.complete_pair <- function(data, x_name, y_name, adjust) {
  cols <- unique(c(x_name, y_name, .adjust_vars(adjust)))
  cols <- intersect(cols, names(data))
  sub <- data[, cols, drop = FALSE]
  sub[stats::complete.cases(sub), , drop = FALSE]
}

# ---------------------------------------------------------------
# Hold adjust-covariates at "typical" values for prediction
# numeric -> mean; factor -> most common level
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
# x_i of the (partial) fit shown in the cell — i.e. exactly what the
# user sees in the fit panel.
#
# Returns a named list keyed by order ("1", "2", ...) of data frames
# with the same schema as fit_obj$pred so the cell renderer can
# consume fit and derivative panels uniformly.
# ---------------------------------------------------------------

.derivatives_lpmatrix <- function(fit, newdata, x_grid, orders) {
  if (!length(orders)) return(list())
  if (is.null(fit) || !inherits(fit, "gam")) return(list())
  if (!is.numeric(x_grid) || length(x_grid) < 3L) return(list())
  h <- mean(diff(x_grid))
  if (!is.finite(h) || h <= 0) return(list())
  Xp <- tryCatch(
    stats::predict(fit, newdata = newdata, type = "lpmatrix"),
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
# for diagnostic record) — the point estimate and pointwise SE are
# unchanged and are reused from `.derivatives_lpmatrix()`.

.derivatives_simultaneous_bands <- function(fit, newdata, x_grid, orders,
                                            n_sim = 1000L, alpha = 0.05) {
  if (!length(orders)) return(list())
  if (is.null(fit) || !inherits(fit, "gam")) return(list())
  if (!is.numeric(x_grid) || length(x_grid) < 3L) return(list())
  h <- mean(diff(x_grid))
  if (!is.finite(h) || h <= 0) return(list())
  Xp <- tryCatch(
    stats::predict(fit, newdata = newdata, type = "lpmatrix"),
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
  # n_sim = 1000 and basis ranks in the low tens.
  Z  <- matrix(stats::rnorm(n_sim * p), nrow = n_sim)
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

.fit_pair <- function(x_name, y_name, data_full, adjust, method, k, bs,
                     na_action, n_grid = 100L,
                     derivatives = integer(),
                     derivative_ci = "pointwise",
                     derivative_ci_nsim = 1000L, ...) {
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

  fml <- .build_formula(y_name, x_name, k_val, bs, adjust)
  fit <- tryCatch(
    mgcv::gam(fml, data = dat, method = method, ...),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    out <- .empty_fit_result(x_name, y_name, n_used)
    out$error <- conditionMessage(fit)
    return(out)
  }

  smry <- summary(fit)
  # First smooth term is s(x); paranoid guard in case mgcv reorders
  s_row <- which(rownames(smry$s.table) ==
                   sprintf("s(%s)", x_name))[1L]
  if (is.na(s_row)) s_row <- 1L
  edf <- unname(smry$s.table[s_row, "edf"])
  pval <- unname(smry$s.table[s_row, "p-value"])
  dev_exp <- unname(smry$dev.expl %||% NA_real_)

  # Prediction grid on the response scale, holding adjust covariates at typical values
  x_vals <- dat[[x_name]]
  x_grid <- seq(min(x_vals), max(x_vals), length.out = n_grid)
  nd <- .typical_newdata(dat, x_name, x_grid, adjust)
  preds <- tryCatch(
    stats::predict(fit, newdata = nd, se.fit = TRUE),
    error = function(e) NULL
  )
  if (is.null(preds)) {
    pred_df <- data.frame(
      x = x_grid, fit = NA_real_, se = NA_real_,
      lo = NA_real_, hi = NA_real_
    )
  } else {
    pred_df <- data.frame(
      x  = x_grid,
      fit = as.numeric(preds$fit),
      se  = as.numeric(preds$se.fit),
      lo  = as.numeric(preds$fit) - 1.96 * as.numeric(preds$se.fit),
      hi  = as.numeric(preds$fit) + 1.96 * as.numeric(preds$se.fit)
    )
  }

  deriv_list <- if (length(derivatives)) {
    .derivatives_lpmatrix(fit, nd, x_grid, derivatives)
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
        n_sim = derivative_ci_nsim
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
    edf      = edf,
    pvalue   = pval,
    dev_exp  = dev_exp,
    n_used   = n_used,
    error    = NA_character_
  )
  out$corr  <- .compute_correlations(dat, x_name, y_name)
  out$shape <- .compute_shape_metrics_raw(out)
  out
}

.empty_fit_result <- function(x_name, y_name, n_used) {
  list(
    x_name = x_name, y_name = y_name, fit = NULL,
    pred = data.frame(x = numeric(), fit = numeric(),
                      se = numeric(), lo = numeric(), hi = numeric()),
    deriv = list(),
    raw = data.frame(),
    edf = NA_real_, pvalue = NA_real_, dev_exp = NA_real_,
    n_used = n_used, error = NA_character_,
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
                           derivative_ci_nsim = 1000L, ...) {
  .check_parallel_plan(parallel)
  if (na_action == "complete") {
    data <- data[stats::complete.cases(
      data[, unique(c(vars, .adjust_vars(adjust))), drop = FALSE]
    ), , drop = FALSE]
  }
  grid <- expand.grid(i = seq_along(vars), j = seq_along(vars),
                      KEEP.OUT.ATTRS = FALSE)
  grid <- grid[grid$i != grid$j, , drop = FALSE]

  fit_one <- function(i, j) {
    .fit_pair(
      x_name = vars[i], y_name = vars[j],
      data_full = data, adjust = adjust,
      method = method, k = k, bs = bs,
      na_action = na_action,
      n_grid = n_grid, derivatives = derivatives,
      derivative_ci = derivative_ci,
      derivative_ci_nsim = derivative_ci_nsim, ...
    )
  }

  if (isTRUE(parallel) && rlang::is_installed("future.apply")) {
    fits <- future.apply::future_mapply(
      fit_one, grid$i, grid$j, SIMPLIFY = FALSE,
      future.seed = TRUE
    )
  } else {
    fits <- mapply(fit_one, grid$i, grid$j, SIMPLIFY = FALSE)
  }
  names(fits) <- sprintf("%d_%d", grid$i, grid$j)
  fits
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
# p-value → glyph
# ---------------------------------------------------------------

.pvalue_to_glyph <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.001) "***"
  else if (p < 0.01) "**"
  else if (p < 0.05) "*"
  else if (p < 0.1) "\u00b7"  # middle dot
  else ""
}
