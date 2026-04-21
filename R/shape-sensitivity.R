# Shape-recognition sensitivity study (package-native).
# Public API:
#   janusplot_shape_sensitivity_shapes()   - list canonical truths
#   janusplot_shape_sensitivity()          - run the sweep
#   janusplot_shape_sensitivity_summary()  - aggregate raw results
#   janusplot_shape_sensitivity_plot()     - confusion / accuracy /
#                                            recovery-curve plots
#
# Ground-truth generators live on x in [0, 1] with y normalised to
# [0, 1] so sigma parameterises noise consistently across shapes
# (sigma is a fraction of the y-range).

# ---------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------

.norm01 <- function(y) {
  r <- range(y, na.rm = TRUE)
  if (diff(r) == 0) return(rep(0.5, length(y)))
  (y - r[1L]) / diff(r)
}

.shape_sensitivity_generators <- function() {
  list(
    linear_up    = function(x) x,
    linear_down  = function(x) 1 - x,
    convex_up    = function(x) x^2,
    concave_up   = function(x) sqrt(x),
    convex_down  = function(x) (1 - x)^2,
    concave_down = function(x) sqrt(1 - x),
    s_shape      = function(x) 1 / (1 + exp(-10 * (x - 0.5))),
    u_shape      = function(x) .norm01(4 * (x - 0.5)^2),
    inverted_u   = function(x) .norm01(1 - 4 * (x - 0.5)^2),
    skewed_peak  = function(x) .norm01(x * exp(-3 * x)),
    broad_peak   = function(x) .norm01(exp(-((x - 0.5) * 3)^4)),
    wave         = function(x) 0.5 + 0.5 * sin(2 * pi * (x - 0.25)),
    bimodal      = function(x) .norm01(
      exp(-((x - 0.25) * 6)^2) + exp(-((x - 0.75) * 6)^2)
    ),
    bi_wave      = function(x) 0.5 + 0.5 * sin(4 * pi * (x - 0.125))
  )
}

# Expected archetype per truth — pulled from the live taxonomy so the
# sensitivity study cannot drift from the classifier code.
.shape_sensitivity_archetypes <- function() {
  gens  <- .shape_sensitivity_generators()
  stats::setNames(.shape_lookup(names(gens), "archetype"), names(gens))
}

.sens_simulate_one <- function(truth, n, sigma, seed, cutoffs,
                               generators, archetype_truth) {
  set.seed(seed, kind = "default")
  x <- sort(stats::runif(n, 0, 1))
  gen   <- generators[[truth]]
  y_tru <- gen(x)
  y     <- y_tru + stats::rnorm(n, sd = sigma)
  d     <- data.frame(x = x, y = y)

  fit <- tryCatch(
    suppressWarnings(mgcv::gam(y ~ s(x), data = d, method = "REML")),
    error = function(e) NULL
  )
  if (is.null(fit)) {
    return(data.frame(
      truth             = truth,
      n                 = n,
      sigma             = sigma,
      seed              = seed,
      predicted         = NA_character_,
      correct           = NA,
      archetype_truth   = unname(archetype_truth[truth]),
      archetype_pred    = NA_character_,
      archetype_correct = NA,
      M                 = NA_real_,
      C                 = NA_real_,
      n_turn            = NA_integer_,
      n_inflect         = NA_integer_,
      error             = "gam_fit_failed",
      stringsAsFactors  = FALSE
    ))
  }
  m <- janusplot_shape_metrics(fit, x_name = "x", newdata = d,
                               cutoffs = cutoffs)
  arche_pred <- .shape_lookup(m$shape_category, "archetype")
  arche_true <- unname(archetype_truth[truth])
  data.frame(
    truth             = truth,
    n                 = n,
    sigma             = sigma,
    seed              = seed,
    predicted         = m$shape_category,
    correct           = isTRUE(m$shape_category == truth),
    archetype_truth   = arche_true,
    archetype_pred    = arche_pred,
    archetype_correct = isTRUE(arche_pred == arche_true),
    M                 = m$M,
    C                 = m$C,
    n_turn            = m$n_turning_points,
    n_inflect         = m$n_inflections,
    error             = NA_character_,
    stringsAsFactors  = FALSE
  )
}

# ---------------------------------------------------------------
# Public API
# ---------------------------------------------------------------

#' Canonical ground-truth shapes for the sensitivity study
#'
#' @description
#' Return the names of every canonical ground-truth shape that
#' [janusplot_shape_sensitivity()] can simulate from. Fourteen shapes
#' spanning five archetypes (`monotone_linear`, `monotone_curved`,
#' `unimodal`, `wave`, `multimodal`). The `chaotic` and `degenerate`
#' archetypes are out of scope (no realistic deterministic generator).
#'
#' @returns Character vector of length 14 — the generator names.
#'
#' @seealso [janusplot_shape_sensitivity()], [janusplot_shape_hierarchy()].
#'
#' @examples
#' janusplot_shape_sensitivity_shapes()
#' @export
janusplot_shape_sensitivity_shapes <- function() {
  names(.shape_sensitivity_generators())
}

#' Shape-recognition sensitivity study
#'
#' @description
#' Run a full-factorial sensitivity sweep for the janusplot 24-category
#' shape classifier. For each combination of ground-truth shape, sample
#' size `n`, noise level `sigma`, and replicate, the sweep:
#' \enumerate{
#'   \item Generates `n` points from the noiseless canonical curve on
#'     `[0, 1]` + Gaussian noise with SD = `sigma` (fraction of the
#'     y-range, so signal-to-noise is comparable across shapes).
#'   \item Fits `mgcv::gam(y ~ s(x), method = "REML")`.
#'   \item Runs [janusplot_shape_metrics()] to classify the fitted smooth.
#'   \item Records correctness at both the fine (24-category) and
#'     archetype (7-family) levels.
#' }
#'
#' The function is the package-native implementation of
#' `simulation/scripts/scenario_4_shape_recognition.R`. A small
#' precomputed dataset is shipped as [shape_sensitivity_demo] for
#' downstream examples without requiring users to re-run the sweep.
#'
#' @param shapes Character vector of ground-truth names from
#'   [janusplot_shape_sensitivity_shapes()]. Default `NULL` → all 14.
#' @param n_grid Integer vector of sample sizes. Default
#'   `c(50L, 100L, 200L, 500L)`.
#' @param sigma_grid Numeric vector of noise levels (fraction of the
#'   y-range). Default `c(0.02, 0.05, 0.10, 0.20, 0.40)`.
#' @param n_rep Integer. Replicates per cell. Default `200L`.
#' @param cutoffs Named list of classification thresholds; see
#'   [janusplot_shape_cutoffs()].
#' @param parallel Logical. If `TRUE` and `future.apply` is installed,
#'   dispatch replicates in parallel. The caller is responsible for
#'   configuring `future::plan()` (e.g. `future::plan(future::multisession)`).
#' @param seed Integer. Base seed — each fit uses `seed + row_index`
#'   so results are reproducible and cell-permutation-invariant.
#' @param verbose Logical. Print progress messages to the console.
#'   Default is `interactive()`.
#'
#' @returns A data frame with one row per fit. Columns:
#' \describe{
#'   \item{`truth`}{Ground-truth shape name.}
#'   \item{`n`}{Sample size for this fit.}
#'   \item{`sigma`}{Noise level for this fit.}
#'   \item{`seed`}{RNG seed used.}
#'   \item{`predicted`}{Classifier output at the fine (24-category) level.}
#'   \item{`correct`}{Logical — does `predicted == truth`?}
#'   \item{`archetype_truth`}{Expected archetype for `truth`.}
#'   \item{`archetype_pred`}{Archetype of `predicted`.}
#'   \item{`archetype_correct`}{Logical — archetype-level correctness.}
#'   \item{`M`, `C`}{Raw monotonicity / convexity indices for the fit.}
#'   \item{`n_turn`, `n_inflect`}{Recovered turning-point and
#'     inflection counts.}
#'   \item{`error`}{`"gam_fit_failed"` when `mgcv::gam()` errored;
#'     `NA` otherwise.}
#' }
#'
#' @seealso [janusplot_shape_sensitivity_summary()],
#'   [janusplot_shape_sensitivity_plot()],
#'   [janusplot_shape_sensitivity_shapes()], [shape_sensitivity_demo].
#'
#' @examples
#' # Tiny-run smoke test (< 2 seconds): 3 shapes x 2 n x 2 sigma x 5 reps.
#' res <- janusplot_shape_sensitivity(
#'   shapes     = c("linear_up", "u_shape", "wave"),
#'   n_grid     = c(100L, 200L),
#'   sigma_grid = c(0.05, 0.20),
#'   n_rep      = 5L,
#'   verbose    = FALSE
#' )
#' head(res)
#' janusplot_shape_sensitivity_summary(res, level = "archetype")
#' @export
janusplot_shape_sensitivity <- function(
    shapes     = NULL,
    n_grid     = c(50L, 100L, 200L, 500L),
    sigma_grid = c(0.02, 0.05, 0.10, 0.20, 0.40),
    n_rep      = 200L,
    cutoffs    = janusplot_shape_cutoffs(),
    parallel   = FALSE,
    seed       = 2026L,
    verbose    = interactive()
) {
  generators <- .shape_sensitivity_generators()
  all_shapes <- names(generators)
  if (is.null(shapes)) shapes <- all_shapes
  if (!is.character(shapes) || !length(shapes)) {
    cli::cli_abort("{.arg shapes} must be a non-empty character vector.")
  }
  bad <- setdiff(shapes, all_shapes)
  if (length(bad)) {
    cli::cli_abort(c(
      "Unknown {.arg shapes} value{?s}: {.val {bad}}.",
      i = "Allowed: {.val {all_shapes}}."
    ))
  }
  if (!is.numeric(n_grid)     || !length(n_grid)     || any(n_grid < 5L)) {
    cli::cli_abort("{.arg n_grid} must be a numeric vector with every value >= 5.")
  }
  if (!is.numeric(sigma_grid) || !length(sigma_grid) || any(sigma_grid < 0)) {
    cli::cli_abort("{.arg sigma_grid} must be a non-negative numeric vector.")
  }
  if (!is.numeric(n_rep) || length(n_rep) != 1L || n_rep < 1L) {
    cli::cli_abort("{.arg n_rep} must be a single positive integer.")
  }

  archetype_truth <- .shape_sensitivity_archetypes()
  grid <- expand.grid(
    truth = shapes, n = as.integer(n_grid), sigma = sigma_grid,
    rep = seq_len(as.integer(n_rep)),
    stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE
  )
  grid$seed <- as.integer(seed) + seq_len(nrow(grid))

  total <- nrow(grid)
  if (isTRUE(verbose)) {
    cli::cli_inform(c(
      i = paste0(
        "Running {total} fits: {length(shapes)} shape{?s} x ",
        "{length(n_grid)} n x {length(sigma_grid)} sigma x {n_rep} rep{?s}",
        if (parallel) " (parallel)" else " (serial)", "."
      )
    ))
  }

  use_parallel <- isTRUE(parallel) &&
    rlang::is_installed("future.apply")
  if (isTRUE(parallel) && !use_parallel) {
    cli::cli_warn(
      "{.arg parallel = TRUE} but {.pkg future.apply} is not installed; running serially."
    )
  }

  worker <- function(i) {
    .sens_simulate_one(
      truth           = grid$truth[i],
      n               = grid$n[i],
      sigma           = grid$sigma[i],
      seed            = grid$seed[i],
      cutoffs         = cutoffs,
      generators      = generators,
      archetype_truth = archetype_truth
    )
  }

  rows <- if (use_parallel) {
    future.apply::future_lapply(
      seq_len(total), worker,
      future.seed     = TRUE,
      future.packages = c("janusplot", "mgcv")
    )
  } else {
    lapply(seq_len(total), worker)
  }
  do.call(rbind, rows)
}

#' Summarise a shape-sensitivity sweep
#'
#' @description
#' Aggregate the raw output of [janusplot_shape_sensitivity()] into a
#' per-cell mean-accuracy table at either the fine (24-category) or
#' archetype (7-family) level.
#'
#' @param results Data frame returned by [janusplot_shape_sensitivity()].
#' @param level One of `"fine"` (default) or `"archetype"`.
#'
#' @returns A data frame with columns `truth`, `n`, `sigma`, `accuracy`.
#'
#' @examples
#' data("shape_sensitivity_demo", package = "janusplot")
#' head(janusplot_shape_sensitivity_summary(shape_sensitivity_demo,
#'                                          level = "archetype"))
#' @export
janusplot_shape_sensitivity_summary <- function(
    results, level = c("fine", "archetype")
) {
  level <- rlang::arg_match(level)
  col <- if (level == "fine") "correct" else "archetype_correct"
  if (!all(c("truth", "n", "sigma", col) %in% names(results))) {
    cli::cli_abort(
      "{.arg results} must come from {.fn janusplot_shape_sensitivity}."
    )
  }
  agg <- stats::aggregate(
    as.integer(results[[col]]),
    by  = list(truth = results$truth, n = results$n, sigma = results$sigma),
    FUN = mean, na.rm = TRUE
  )
  names(agg)[ncol(agg)] <- "accuracy"
  agg
}

# ---------------------------------------------------------------
# Plot helpers
# ---------------------------------------------------------------

.sens_plot_confusion_fine <- function(results) {
  tax <- .shape_taxonomy()
  lvls_truth <- intersect(tax$category, unique(results$truth))
  lvls_pred  <- tax$category
  tbl <- as.data.frame(table(
    truth     = factor(results$truth,     levels = lvls_truth),
    predicted = factor(results$predicted, levels = lvls_pred)
  ))
  tbl$proportion <- with(tbl, Freq / ave(Freq, truth, FUN = sum))
  ggplot2::ggplot(tbl, ggplot2::aes(x = .data$predicted, y = .data$truth,
                                    fill = .data$proportion)) +
    ggplot2::geom_tile(colour = "grey80") +
    ggplot2::geom_text(ggplot2::aes(
      label = ifelse(.data$Freq == 0, "",
                     sprintf("%.2f", .data$proportion))),
      size = 2.2, colour = "white") +
    ggplot2::scale_fill_viridis_c(name = "P(pred | truth)",
                                  limits = c(0, 1), na.value = "grey95") +
    ggplot2::scale_x_discrete(drop = FALSE) +
    ggplot2::scale_y_discrete(limits = rev) +
    ggplot2::labs(title = "Fine-grained confusion",
                  x = "Predicted category",
                  y = "Ground-truth category") +
    ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      panel.grid  = ggplot2::element_blank(),
      plot.title  = ggplot2::element_text(face = "bold")
    )
}

.sens_plot_confusion_archetype <- function(results) {
  lvls <- c("monotone_linear", "monotone_curved", "unimodal",
            "wave", "multimodal", "chaotic", "degenerate")
  tbl <- as.data.frame(table(
    truth     = factor(results$archetype_truth, levels = lvls),
    predicted = factor(results$archetype_pred,  levels = lvls)
  ))
  tbl$proportion <- with(tbl, Freq / ave(Freq, truth, FUN = sum))
  ggplot2::ggplot(tbl, ggplot2::aes(x = .data$predicted, y = .data$truth,
                                    fill = .data$proportion)) +
    ggplot2::geom_tile(colour = "grey80") +
    ggplot2::geom_text(ggplot2::aes(
      label = ifelse(.data$Freq == 0, "",
                     sprintf("%.2f", .data$proportion))),
      size = 3, colour = "white") +
    ggplot2::scale_fill_viridis_c(name = "P(pred | truth)",
                                  limits = c(0, 1), na.value = "grey95") +
    ggplot2::scale_x_discrete(drop = FALSE) +
    ggplot2::scale_y_discrete(limits = rev) +
    ggplot2::labs(title = "Archetype confusion",
                  x = "Predicted archetype",
                  y = "Ground-truth archetype") +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 30, hjust = 1),
      panel.grid  = ggplot2::element_blank(),
      plot.title  = ggplot2::element_text(face = "bold")
    )
}

.sens_plot_accuracy_grid <- function(results) {
  agg <- janusplot_shape_sensitivity_summary(results, "archetype")
  ggplot2::ggplot(agg, ggplot2::aes(x = factor(.data$sigma),
                                    y = factor(.data$n),
                                    fill = .data$accuracy)) +
    ggplot2::geom_tile(colour = "white") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", .data$accuracy)),
                       colour = "white", size = 3) +
    ggplot2::facet_wrap(~ truth, ncol = 4) +
    ggplot2::scale_fill_viridis_c(name = "P(correct)", limits = c(0, 1)) +
    ggplot2::labs(x = expression(sigma), y = "n",
                  title = "Archetype-level recovery accuracy") +
    ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      strip.text = ggplot2::element_text(face = "bold")
    )
}

.sens_plot_recovery_curves <- function(results) {
  agg <- janusplot_shape_sensitivity_summary(results, "archetype")
  ggplot2::ggplot(agg, ggplot2::aes(x = .data$sigma, y = .data$accuracy,
                                    colour = factor(.data$n))) +
    ggplot2::geom_line(linewidth = 0.6) +
    ggplot2::geom_point(size = 1.6) +
    ggplot2::facet_wrap(~ truth, ncol = 4) +
    ggplot2::scale_y_continuous(limits = c(0, 1)) +
    ggplot2::scale_colour_viridis_d(name = "n") +
    ggplot2::labs(
      x = expression("Noise " ~ sigma ~ " (fraction of y-range)"),
      y = "P(archetype correct)",
      title = "Archetype recovery curves"
    ) +
    ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      strip.text = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(face = "bold")
    )
}

#' Visualise a shape-sensitivity sweep
#'
#' @description
#' Produce one of four diagnostic plots from the raw data frame returned
#' by [janusplot_shape_sensitivity()]:
#' \describe{
#'   \item{`"confusion_fine"`}{24 x (|shapes|) confusion matrix at the
#'     fine category level — rows = ground truth, columns = predicted,
#'     cells coloured by `P(pred | truth)`.}
#'   \item{`"confusion_archetype"`}{7 x 7 confusion matrix at the
#'     archetype level.}
#'   \item{`"accuracy_grid"`}{per-shape heatmap of archetype-level
#'     accuracy across the `(n, sigma)` design.}
#'   \item{`"recovery_curves"`}{accuracy as a function of sigma,
#'     one line per sample size, faceted by shape.}
#' }
#'
#' @param results Data frame from [janusplot_shape_sensitivity()] or the
#'   precomputed [shape_sensitivity_demo].
#' @param type One of `"confusion_fine"`, `"confusion_archetype"`,
#'   `"accuracy_grid"`, or `"recovery_curves"`.
#'
#' @returns A [ggplot2::ggplot] object.
#'
#' @examples
#' data("shape_sensitivity_demo", package = "janusplot")
#' janusplot_shape_sensitivity_plot(shape_sensitivity_demo,
#'                                  "recovery_curves")
#' @export
janusplot_shape_sensitivity_plot <- function(
    results,
    type = c("confusion_fine", "confusion_archetype",
             "accuracy_grid", "recovery_curves")
) {
  type <- rlang::arg_match(type)
  switch(type,
    confusion_fine      = .sens_plot_confusion_fine(results),
    confusion_archetype = .sens_plot_confusion_archetype(results),
    accuracy_grid       = .sens_plot_accuracy_grid(results),
    recovery_curves     = .sens_plot_recovery_curves(results)
  )
}
