# reference.R -- janusplot_reference(): a bootstrap reference for the
# asymmetry index A of chosen pairs. A is rarely zero even when nothing
# about a pair is asymmetric in an interesting way: a straight line with a
# non-Gaussian predictor gives a curved reverse conditional mean, and
# noise lets either smooth bend. For each direction the reference
# simulates the cell's own fitted smooth with additive resampled
# residuals, keeps the predictor and the adjustment as observed, refits
# both directions and returns the distribution of A it produces. The
# question it answers: is the observed A more than one direction's smooth,
# plus additive noise and these marginals, would give?

#' Bootstrap reference for the asymmetry index of a pair
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The asymmetry index `A` of a pair varies a great deal from sample to
#' sample, and it is not zero for a straight line: a straight line in one
#' direction gives a curved conditional mean in the other whenever the
#' predictor is not Gaussian, and noise lets either smooth bend.
#' `janusplot_reference()` measures how large `A` gets from those sources
#' alone. For each pair and each direction it simulates the fitted smooth
#' of that direction with additive noise, keeping the observed predictor,
#' the adjustment and the residual distribution, refits both directional
#' smooths as [janusplot_fit()] did, and records `A`.
#'
#' @details
#' For the mechanism `x -> y`, the cell `y ~ s(x)` (with the fit's
#' `adjust` terms) is refitted to the pair's rows. Each replicate draws
#' `y* = fitted + e*`, with `e*` resampled from that fit's centred
#' residuals, and keeps `x` and the adjustment covariates as observed.
#' Both directional smooths, `y* ~ s(x)` and `x ~ s(y*)`, are then fitted
#' with the engine, method, basis and basis dimension of the original
#' cells, and `A*` is computed from their EDFs. The mechanism `y -> x`
#' swaps the roles. When the fitted smooth is a straight line, the
#' mechanism is a straight line with additive noise.
#'
#' `p_value` is the share of replicates with `A*` at least the observed
#' `A`, computed as `(1 + #{A* >= A}) / (1 + B_ok)`. A large value says
#' that the smooth of that direction, with additive noise of constant
#' spread and these marginals, readily gives an `A` this large: the index
#' adds nothing to the two fitted smooths. A small value under both
#' mechanisms says neither direction with additive noise reproduces the
#' asymmetry, as with a spread that changes along the predictor. Neither
#' result identifies a causal direction. `A_ref_q95` shows how large `A`
#' gets by chance at this sample size.
#'
#' The reference needs the Gaussian family with the identity link. It
#' resamples residuals, so the simulated responses are continuous; for a
#' variable with many tied values (see `tie_ratio` in `summary()`) the
#' reference is approximate. Each pair costs `4 * B + 2` model fits, so
#' the function is meant for a few chosen pairs; `parallel = TRUE`
#' spreads the replicates over a [future][future::plan] plan.
#'
#' @param fit A `janusplot_fit` object from [janusplot_fit()].
#' @param x,y Variable names of the pairs to reference: two equal-length
#'   character vectors, element `i` of `x` paired with element `i` of
#'   `y`; or a two-column data frame in `x` with `y` missing, as for
#'   [janusplot_pair()]. `NULL` for both (the default) takes every pair of
#'   the fit.
#' @param B Positive integer, the number of replicates per mechanism;
#'   `99L` by default. Use 499 or more for a reported p-value.
#' @param seed Integer seed for the replicates, or `NULL` (the default) to
#'   draw from the current random-number stream. With a seed, the stream
#'   in the calling session is restored afterwards.
#' @param parallel Logical. `TRUE` runs the replicates through
#'   `future.apply` under the current [future][future::plan] plan;
#'   `FALSE` (the default) runs them sequentially.
#'
#' @returns A data frame of class `janusplot_reference` with one row per
#'   pair and mechanism: `var_x`, `var_y` (the pair), `mechanism`
#'   (`"var_x -> var_y"` or `"var_y -> var_x"`), `n_used`, `A` (the
#'   observed index), `A_ref_median`, `A_ref_q95` (the median and 95th
#'   percentile of `A*`), `p_value` and `B_ok` (replicates that fitted).
#'   The replicate values are kept in the attribute `"draws"`. `print()`
#'   adds a one-line reading per pair; `plot()` draws the reference
#'   distributions with the observed `A` marked.
#'
#' @family smooth-associations
#' @seealso [janusplot_fit()] for the index, [janusplot_direction()] for a
#'   residual-independence test of the direction of a pair.
#'
#' @examples
#' \donttest{
#' # A straight line with a uniform predictor: the reverse smooth bends,
#' # so A is well above zero, and the reference shows the line explains it.
#' set.seed(1L)
#' x <- runif(200L, -2, 2)
#' d <- data.frame(x = x, y = x + rnorm(200L, sd = 0.4))
#' fit <- janusplot_fit(d, engine = "gam")
#' ref <- janusplot_reference(fit, B = 49L, seed = 2L)
#' ref
#' plot(ref)
#' }
#' @export
janusplot_reference <- function(fit, x = NULL, y = NULL, B = 99L,
                                seed = NULL, parallel = FALSE) {
  .check_fit_object(fit)
  B <- .check_positive_integer(B, "B")
  .check_flag(parallel, "parallel")
  if (!is.null(seed) &&
      (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed))) {
    cli::cli_abort("{.arg seed} must be a single number or NULL.")
  }
  if (!identical(fit$settings$family %||% "gaussian", "gaussian") ||
      !identical(fit$settings$link %||% "identity", "identity")) {
    cli::cli_abort(c(
      "The reference needs the Gaussian family with the identity link.",
      i = "This fit used {.val {fit$settings$family}} with link {.val {fit$settings$link}}."
    ))
  }
  pairs <- if (is.null(x) && is.null(y)) {
    data.frame(
      x = vapply(fit$pairs, function(p) p$var_i, character(1L)),
      y = vapply(fit$pairs, function(p) p$var_j, character(1L)),
      stringsAsFactors = FALSE
    )
  } else {
    .resolve_pairs(fit, x, y)
  }
  if (isTRUE(parallel)) {
    rlang::check_installed("future.apply",
                           reason = "for `parallel = TRUE`.")
    .check_parallel_plan(parallel)
  }
  cli::cli_inform(c(
    i = paste("Fitting {4L * B * nrow(pairs)} reference model{?s}",
              "({nrow(pairs)} pair{?s}, B = {B} per direction).")
  ))

  run <- function() {
    if (!is.null(seed)) set.seed(seed)
    lapply(seq_len(nrow(pairs)), function(i) {
      .reference_pair(fit, pairs$x[i], pairs$y[i], B, parallel)
    })
  }
  results <- if (is.null(seed)) run() else .with_preserved_seed(run())

  rows <- do.call(rbind, lapply(results, `[[`, "rows"))
  rownames(rows) <- NULL
  draws <- unlist(lapply(results, `[[`, "draws"), recursive = FALSE)
  structure(rows, draws = draws, B = B,
            class = c("janusplot_reference", "data.frame"))
}

# ---------------------------------------------------------------
# One pair: the observed A and both mechanisms' replicates
# ---------------------------------------------------------------

.reference_pair <- function(fit, x_name, y_name, B, parallel) {
  pair <- fit$pairs[[.find_pair(fit, x_name, y_name)]]
  a_obs <- pair$asymmetry_index
  rows_used <- .cell_rows(fit, x_name, y_name)
  dat <- fit$data[rows_used, , drop = FALSE]
  settings <- fit$settings
  k_x <- .reference_k(settings, x_name, dat[[x_name]])
  k_y <- .reference_k(settings, y_name, dat[[y_name]])

  al <- .alias_columns(dat, c(x_name, y_name), fit$adjust)
  work <- al$data
  xa <- al$vars[1L]
  ya <- al$vars[2L]
  adjust <- al$adjust

  mech <- list(
    list(from = xa, to = ya, role = "forward",
         label = sprintf("%s -> %s", x_name, y_name)),
    list(from = ya, to = xa, role = "reverse",
         label = sprintf("%s -> %s", y_name, x_name))
  )
  out_rows <- list()
  draws <- list()
  for (m in mech) {
    a_star <- if (is.na(a_obs)) {
      rep(NA_real_, B)
    } else {
      .reference_draws(work, m$from, m$to, xa, ya, k_x, k_y, adjust,
                       settings, B, parallel)
    }
    ok <- is.finite(a_star)
    b_ok <- sum(ok)
    p_val <- if (b_ok > 0L && is.finite(a_obs)) {
      (1 + sum(a_star[ok] >= a_obs - 1e-12)) / (1 + b_ok)
    } else {
      NA_real_
    }
    out_rows[[length(out_rows) + 1L]] <- data.frame(
      var_x        = x_name,
      var_y        = y_name,
      mechanism    = m$label,
      n_used       = length(rows_used),
      A            = a_obs,
      A_ref_median = if (b_ok) stats::median(a_star[ok]) else NA_real_,
      A_ref_q95    = if (b_ok) {
        unname(stats::quantile(a_star[ok], 0.95, type = 7))
      } else {
        NA_real_
      },
      p_value      = p_val,
      B_ok         = b_ok,
      stringsAsFactors = FALSE
    )
    draws[[length(draws) + 1L]] <- list(
      pair = sprintf("%s <-> %s", x_name, y_name), mechanism = m$label,
      role = m$role, A_star = a_star
    )
  }
  list(rows = do.call(rbind, out_rows), draws = draws)
}

# The basis dimension the original cell with this predictor was fitted at:
# the requested k, capped at the predictor's distinct values as
# janusplot_fit() caps it.
.reference_k <- function(settings, predictor, values) {
  k_val <- .resolve_k(settings$k, predictor)
  .resolve_pair_k(k_val, settings$bs, length(unique(values)))$k_fit
}

# B replicates of A under the mechanism from -> to: the fitted smooth of
# that direction plus resampled residuals, with the predictor and the
# adjustment covariates held as observed.
.reference_draws <- function(work, from, to, xa, ya, k_x, k_y, adjust,
                             settings, B, parallel) {
  k_from <- if (identical(from, xa)) k_x else k_y
  mech_fit <- .fit_one_gam(
    .build_formula(to, from, k_from, settings$bs, adjust), work,
    engine = settings$engine, method = settings$method,
    discrete = isTRUE(settings$discrete),
    nthreads = settings$nthreads %||% 1L
  )
  mu <- as.numeric(stats::fitted(mech_fit))
  res <- as.numeric(stats::residuals(mech_fit, type = "response"))
  res <- res - mean(res)
  f_xy <- .build_formula(ya, xa, k_x, settings$bs, adjust)   # y ~ s(x)
  f_yx <- .build_formula(xa, ya, k_y, settings$bs, adjust)   # x ~ s(y)
  one <- function(b) {
    sim <- work
    sim[[to]] <- mu + sample(res, length(res), replace = TRUE)
    e1 <- .reference_edf(f_xy, sim, xa, settings)
    e2 <- .reference_edf(f_yx, sim, ya, settings)
    .compute_asymmetry_index(e1, e2)
  }
  vals <- if (isTRUE(parallel)) {
    future.apply::future_vapply(seq_len(B), one, numeric(1L),
                                future.seed = TRUE)
  } else {
    vapply(seq_len(B), one, numeric(1L))
  }
  as.numeric(vals)
}

# EDF of s(predictor) in one refit, NA when the fit fails.
.reference_edf <- function(fml, dat, predictor, settings) {
  f <- tryCatch(
    suppressWarnings(.fit_one_gam(
      fml, dat, engine = settings$engine, method = settings$method,
      discrete = isTRUE(settings$discrete),
      nthreads = settings$nthreads %||% 1L
    )),
    error = function(e) NULL
  )
  if (is.null(f)) return(NA_real_)
  label <- sprintf("s(%s)", predictor)
  sm <- Filter(function(s) identical(s$label, label), f$smooth)
  if (!length(sm)) return(NA_real_)
  sm <- sm[[1L]]
  sum(f$edf[sm$first.para:sm$last.para])
}

# ---------------------------------------------------------------
# Methods
# ---------------------------------------------------------------

#' @rdname janusplot_reference
#' @param ... Ignored.
#' @export
print.janusplot_reference <- function(x, ...) {
  B <- attr(x, "B")
  cli::cat_line(sprintf(
    "janusplot reference for A: %d pair%s, B = %d per mechanism",
    nrow(x) %/% 2L, if (nrow(x) == 2L) "" else "s", B
  ))
  tab <- as.data.frame(unclass(x)[c("var_x", "var_y", "mechanism", "A",
                                    "A_ref_median", "A_ref_q95",
                                    "p_value")],
                       stringsAsFactors = FALSE)
  num <- c("A", "A_ref_median", "A_ref_q95", "p_value")
  tab[num] <- lapply(tab[num], function(v) round(v, 3L))
  print(tab, row.names = FALSE)
  keys <- unique(paste(x$var_x, x$var_y, sep = "\r"))
  for (key in keys) {
    sel <- paste(x$var_x, x$var_y, sep = "\r") == key
    cli::cat_line(.reference_reading(x[sel, , drop = FALSE]))
  }
  invisible(x)
}

# One sentence per pair from its two mechanism rows.
.reference_reading <- function(rows) {
  pair <- sprintf("%s <-> %s", rows$var_x[1L], rows$var_y[1L])
  p <- rows$p_value
  if (anyNA(p)) return(sprintf("%s: no reference (a fit failed).", pair))
  if (all(p < 0.05)) {
    return(sprintf(paste(
      "%s: A = %.2f exceeds what either direction's smooth with additive",
      "noise gives with these marginals."), pair, rows$A[1L]))
  }
  best <- rows$mechanism[which.max(p)]
  sprintf("%s: A = %.2f is within what the smooth %s with additive noise gives (p = %.2f).",
          pair, rows$A[1L], best, max(p))
}

#' @rdname janusplot_reference
#' @export
plot.janusplot_reference <- function(x, ...) {
  draws <- attr(x, "draws")
  df <- do.call(rbind, lapply(draws, function(d) {
    v <- d$A_star[is.finite(d$A_star)]
    if (!length(v)) return(NULL)
    data.frame(pair = d$pair, mechanism = d$mechanism, role = d$role,
               A_star = v, stringsAsFactors = FALSE)
  }))
  obs <- data.frame(pair = paste(x$var_x, x$var_y, sep = " <-> "),
                    A = x$A, stringsAsFactors = FALSE)
  obs <- obs[!duplicated(obs$pair), , drop = FALSE]
  if (is.null(df) || !nrow(df)) {
    cli::cli_abort("No reference replicates to draw.")
  }
  # One pair: the legend names the two lines. Several pairs: the legend
  # names the roles, as listed (x -> y) and reversed (y -> x).
  one_pair <- length(unique(df$pair)) == 1L
  if (one_pair) {
    df$fill <- factor(df$mechanism, levels = unique(df$mechanism))
  } else {
    df$fill <- factor(ifelse(df$role == "forward", "x -> y as listed",
                             "y -> x"),
                      levels = c("x -> y as listed", "y -> x"))
  }
  ggplot2::ggplot(df, ggplot2::aes(x = .data$A_star, fill = .data$fill)) +
    ggplot2::geom_histogram(
      binwidth = 0.025, boundary = 0, position = "identity", alpha = 0.55,
      colour = NA
    ) +
    ggplot2::geom_vline(data = obs, ggplot2::aes(xintercept = .data$A),
                        colour = "grey10", linewidth = 0.7) +
    ggplot2::facet_wrap(~ pair, scales = "free_y") +
    ggplot2::scale_fill_manual(
      values = c("#08306b", .overlay_reverse_colour()),
      name = "simulated mechanism"
    ) +
    ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0.01)) +
    ggplot2::labs(x = "A under the simulated mechanism (vertical line: observed A)",
                  y = "replicates") +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(legend.position = "bottom",
                   panel.grid.minor = ggplot2::element_blank())
}
