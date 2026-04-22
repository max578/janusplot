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
        i = "Install with {.code install.packages(\"future.apply\")}."
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
                     na_action, n_grid = 100L, ...) {
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

  out <- list(
    x_name   = x_name,
    y_name   = y_name,
    fit      = fit,
    pred     = pred_df,
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
                           na_action, parallel, ...) {
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
      na_action = na_action, ...
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
