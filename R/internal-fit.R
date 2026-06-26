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

# ---------------------------------------------------------------
# Fitting-engine dispatch (Feature 4). `bam` is mgcv's "big additive
# model" — same formula language as `gam`, but uses fREML (fast REML)
# by default, block-Lanczos / discrete-method optimisations for the
# basis-coefficient solve, lower memory, and a built-in `nthreads`
# argument. bam objects inherit from gam (`class(b)` ==
# c("bam", "gam", "glm", "lm")) so every downstream code path
# (predict, summary, k.check, derivative LP-matrix arithmetic)
# works without modification — engine is plumbing, not redesign.
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
  n_unique <- length(unique(dat[[x_name]]))

  # Initial fit at user-requested k (mgcv resolves k=-1 internally).
  fml <- .build_formula(y_name, x_name, k_val, bs, adjust)
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
    out <- .empty_fit_result(x_name, y_name, n_used)
    out$error <- conditionMessage(fit)
    return(out)
  }

  # Strategy A — diagnostic, always on.
  k_diag <- .k_check_one_pair(fit, x_name, n_unique,
                              thresholds = k_check_thresholds)
  k_initial <- if (k_val < 0) {
    # mgcv default — surface the actual k' from k.check, not -1.
    if (!is.na(k_diag$k_prime)) k_diag$k_prime + 1 else NA_real_
  } else {
    as.numeric(k_val)
  }
  k_iterations <- 0L
  k_at_cap <- FALSE

  # Strategy B — opt-in doubling refit on flagged cells with usable n_unique.
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
    error    = NA_character_,
    engine   = engine,
    method   = resolved_method,
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

.empty_fit_result <- function(x_name, y_name, n_used) {
  list(
    x_name = x_name, y_name = y_name, fit = NULL,
    pred = data.frame(x = numeric(), fit = numeric(),
                      se = numeric(), lo = numeric(), hi = numeric()),
    deriv = list(),
    raw = data.frame(),
    edf = NA_real_, pvalue = NA_real_, dev_exp = NA_real_,
    n_used = n_used, error = NA_character_,
    engine = NA_character_, method = NA_character_,
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
      derivative_ci_nsim = derivative_ci_nsim,
      k_check_thresholds = k_check_thresholds,
      auto_refit_k = auto_refit_k,
      k_max_iter = k_max_iter,
      engine = engine, discrete = discrete,
      nthreads = nthreads, ...
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
# Per-cell k-check (Feature 1 — Strategy A diagnostic, always-on)
# ---------------------------------------------------------------
#
# Wraps mgcv::k.check() on a fitted GAM with a single s() term. Returns
# a named list of diagnostic fields. Cells with n_unique < 10 are
# marked "unreliable" — k.check's simulation p-value is meaningless
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
# and Wood (2017) §5.9. Exposed via `k_check_thresholds` on the public
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
