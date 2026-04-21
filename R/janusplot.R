#' Asymmetric smoothed-association matrix
#'
#' @description
#' Render a pairwise, asymmetric matrix of smoothed associations between
#' numeric variables. Each cell \[i, j\] where `i != j` shows the fitted
#' spline from [mgcv::gam()]:
#' * Upper triangle (`i < j`): `gam(x_j ~ s(x_i) + <adjust>)`.
#' * Lower triangle (`i > j`): `gam(x_i ~ s(x_j) + <adjust>)`.
#' * Diagonal: variable name label.
#'
#' The two triangles intentionally differ — the asymmetry reveals
#' heteroscedasticity, leverage, and directional non-linearity that a
#' single scalar correlation hides.
#'
#' @param data A data frame with numeric columns to include.
#' @param vars Character vector of column names to use. `NULL` (default)
#'   uses all numeric columns in `data`. Non-numeric columns trigger an
#'   error listing offenders.
#' @param adjust A one-sided formula RHS giving additional covariates
#'   and/or random effects to include in every pairwise GAM. For example,
#'   `adjust = ~ s(age) + s(site, bs = "re")` fits
#'   `gam(y ~ s(x) + s(age) + s(site, bs = "re"))` for each pair.
#'   Default `NULL` fits unadjusted pairwise smooths.
#' @param method Smoothing-parameter estimation method passed to
#'   [mgcv::gam()]. Default `"REML"` per mgcv recommendation.
#' @param k Integer, or named list mapping variable names to integers.
#'   Basis dimension for `s()`. Default `-1L` (mgcv's automatic choice).
#' @param bs Basis type for `s()`. Default `"tp"` (thin plate).
#' @param order One of `"original"` (default), `"hclust"` (reorder by
#'   hierarchical clustering of Pearson correlations), or `"alphabetical"`.
#' @param show_data Logical. If `TRUE` (default), overlay raw data
#'   points (low alpha) behind each spline.
#' @param show_ci Logical. If `TRUE` (default), overlay the 95%
#'   confidence envelope from `predict(gam, se.fit = TRUE)`.
#' @param colour_by One of `"pearson"` (default), `"spearman"`,
#'   `"kendall"`, `"edf"`, `"deviance_gap"`, or `"none"`. Encodes the
#'   per-cell fill colour by the chosen scalar. Correlation choices use
#'   a diverging palette with limits `c(-1, 1)` and a shared `corr`
#'   colour-bar title; `"edf"` and `"deviance_gap"` use a sequential
#'   palette labelled by the metric.
#' @param fill_by Deprecated alias for `colour_by`. If supplied emits a
#'   single soft deprecation warning and is forwarded to `colour_by`.
#' @param palette Character. Colour palette for the cell fill scale.
#'   Defaults to `"RdBu"` when `colour_by` is a correlation and
#'   `"viridis"` otherwise. Sequential choices: `"viridis"`, `"magma"`,
#'   `"inferno"`, `"plasma"`, `"cividis"`, `"mako"`, `"rocket"`,
#'   `"turbo"` (not CB-safe), `"YlOrRd"`, `"YlGnBu"`, `"Blues"`,
#'   `"Greens"`. Diverging choices: `"RdYlBu"`, `"RdBu"`, `"PuOr"`,
#'   `"Spectral"` (not CB-safe). Passing a sequential palette while
#'   `colour_by` is a correlation silently upgrades to the default
#'   diverging palette.
#' @param annotations Character vector, a subset of
#'   `c("edf", "A", "shape", "code")`. Controls which corner
#'   annotations appear on each off-diagonal cell:
#'   * `"code"` — 2-letter ASCII shape code, **top-left** corner.
#'   * `"A"` and `"edf"` — asymmetry index and effective degrees of
#'     freedom, stacked **bottom-left**.
#'   * `"shape"` — shape glyph (Unicode or ASCII per `glyph_style`),
#'     **bottom-right** corner.
#'
#'   Default `c("edf", "A")`. `"code"` and `"shape"` occupy distinct
#'   corners so both can be requested together. See
#'   [janusplot_shape_hierarchy()] for the full code list.
#' @param shape_cutoffs Named list of classification thresholds used to
#'   map the continuous shape indices into discrete `shape_category`
#'   labels; see [janusplot_shape_cutoffs()].
#' @param show_shape_legend Logical. If `TRUE` (default), attach a
#'   standing shape-types legend plate below the matrix that
#'   illustrates every category in the taxonomy as a canonical
#'   thumbnail spline. Independent of `annotations`.
#' @param glyph_style One of `"ascii"` (default) or `"unicode"`.
#'   Controls how cell shape glyphs render when `"shape"` is included
#'   in `annotations`. Default is `"ascii"` for maximum portability
#'   across typesetting pipelines; switch to `"unicode"` only when
#'   the target font is known to cover the curve glyph set.
#' @param signif_glyph Logical. If `TRUE` (default), annotate cells
#'   with `·` / `*` / `**` reflecting the smooth's F-test p-value.
#' @param show_asymmetry Deprecated. Use `annotations` instead
#'   (`"A" %in% annotations`). When supplied, a soft deprecation
#'   warning fires and the argument is merged into `annotations`.
#' @param na_action One of `"pairwise"` (default; per-cell complete
#'   observations) or `"complete"` (listwise; all cells use the same
#'   rows).
#' @param parallel Logical. If `TRUE`, use `future.apply::future_mapply()`
#'   to fit pairs in parallel. Requires the `future.apply` package and a
#'   user-configured `future::plan()`. Default `FALSE`.
#' @param with_data Logical. If `TRUE`, return a two-element list
#'   `list(plot, data)` where `data` is a flat per-cell summary
#'   (one row per off-diagonal cell) of everything the plot displays.
#'   If the `data.table` package is installed, `data` is returned as a
#'   `data.table`; otherwise as a `data.frame`. Default `FALSE` — in
#'   which case only the ggplot is returned.
#' @param text_scale_diag Positive numeric multiplier applied to the
#'   diagonal variable-name labels. Default `1`. Diagonal labels
#'   additionally auto-shrink for long variable names
#'   (`nchar(var) > 10`) so they fit the cell regardless of this value.
#' @param text_scale_off_diag Positive numeric multiplier applied to
#'   all off-diagonal annotations (`n` / `EDF` readouts, significance
#'   glyphs, asymmetry-index labels). Default `1`. Use `< 1` when
#'   cells are small and the annotations crowd the fit line; use
#'   `> 1` for presentation plots.
#' @param show_glossary Logical. If `TRUE` (default), attach a
#'   multi-line caption below the matrix describing the on-plot
#'   abbreviations (`n`, `EDF`, `A`, fill encoding, significance
#'   glyphs). Only keys actually displayed are listed.
#' @param glossary_scale Positive numeric multiplier on the glossary
#'   caption font size. Default `1`.
#' @param ... Additional arguments passed to [mgcv::gam()].
#'
#' @returns If `with_data = FALSE` (default), a [ggplot2::ggplot] object
#'   (via [patchwork::wrap_plots()]). If `with_data = TRUE`, a list
#'   with two elements: `plot` (the ggplot) and `data` (a tidy table
#'   with columns `var_x`, `var_y`, `position`, `n_used`, `edf`,
#'   `pvalue`, `signif`, `dev_exp`, `asymmetry_index`, `cor_pearson`,
#'   `cor_spearman`, `cor_kendall`, `tie_ratio`,
#'   `monotonicity_index`, `convexity_index`,
#'   `n_turning_points`, `n_inflections`, `flat_range_ratio`,
#'   `shape_category`, `colour_value`, one row per off-diagonal cell).
#'
#' @family smooth-associations
#' @seealso [janusplot_data()] for the raw per-cell fits + metrics.
#'
#' @examples
#' # Small numeric data frame — runs in under a second
#' janusplot(mtcars[, c("mpg", "hp", "wt", "qsec")])
#'
#' \donttest{
#' # Heteroscedastic DGP: Pearson r is ~ 0.9 but the inverse fit is
#' # clearly non-linear, yielding asymmetry index > 0.5.
#' set.seed(2026L)
#' n  <- 200L
#' x1 <- stats::runif(n, 0, 10)
#' x2 <- x1 + stats::rnorm(n, sd = 0.2 * x1)
#' janusplot(data.frame(x1 = x1, x2 = x2, x3 = stats::rnorm(n)),
#'           show_asymmetry = TRUE)
#' }
#' @export
janusplot <- function(
    data,
    vars = NULL,
    adjust = NULL,
    method = "REML",
    k = -1L,
    bs = "tp",
    order = c("original", "hclust", "alphabetical"),
    show_data = TRUE,
    show_ci = TRUE,
    colour_by = c("pearson", "spearman", "kendall",
                  "edf", "deviance_gap", "none"),
    fill_by = NULL,
    palette = NULL,
    annotations = c("edf", "A"),
    shape_cutoffs = janusplot_shape_cutoffs(),
    show_shape_legend = TRUE,
    glyph_style = c("ascii", "unicode"),
    signif_glyph = TRUE,
    show_asymmetry = NULL,
    na_action = c("pairwise", "complete"),
    parallel = FALSE,
    with_data = FALSE,
    text_scale_diag     = 1,
    text_scale_off_diag = 1,
    show_glossary       = TRUE,
    glossary_scale      = 1,
    ...) {
  order       <- rlang::arg_match(order)
  na_action   <- rlang::arg_match(na_action)
  glyph_style <- rlang::arg_match(glyph_style)

  # Dual-alias: fill_by -> colour_by (one-warning deprecation).
  if (!is.null(fill_by)) {
    cli::cli_warn(
      c(
        "!" = "{.arg fill_by} is deprecated; use {.arg colour_by} instead.",
        i  = "Forwarding {.val {fill_by}} to {.arg colour_by}."
      ),
      .frequency    = "regularly",
      .frequency_id = "janusplot_fill_by_deprecated"
    )
    colour_by <- fill_by
  }
  colour_by <- rlang::arg_match(colour_by, .colour_choices())

  if (is.null(palette)) palette <- .default_palette(colour_by)
  palette <- rlang::arg_match(palette, .palette_choices())

  if (!is.character(annotations)) {
    cli::cli_abort(
      "{.arg annotations} must be a character vector (subset of edf/A/shape/code)."
    )
  }
  valid_annot <- c("edf", "A", "shape", "code")
  bad <- setdiff(annotations, valid_annot)
  if (length(bad)) {
    cli::cli_abort(c(
      "Unknown {.arg annotations} value{?s}: {.val {bad}}.",
      i = "Allowed: {.val {valid_annot}}."
    ))
  }

  # Dual-alias: show_asymmetry -> annotations.
  if (!is.null(show_asymmetry)) {
    cli::cli_warn(
      c(
        "!" = paste(
          "{.arg show_asymmetry} is deprecated; pass",
          "{.code annotations = c(\"A\", ...)} instead."
        )
      ),
      .frequency    = "regularly",
      .frequency_id = "janusplot_show_asymmetry_deprecated"
    )
    if (isTRUE(show_asymmetry)) {
      annotations <- union(annotations, "A")
    } else if (isFALSE(show_asymmetry)) {
      annotations <- setdiff(annotations, "A")
    }
  }

  .check_scalar_positive(text_scale_diag,     "text_scale_diag")
  .check_scalar_positive(text_scale_off_diag, "text_scale_off_diag")
  .check_scalar_positive(glossary_scale,      "glossary_scale")
  if (!is.logical(show_glossary) || length(show_glossary) != 1L ||
      is.na(show_glossary)) {
    cli::cli_abort("{.arg show_glossary} must be TRUE or FALSE.")
  }
  if (!is.logical(show_shape_legend) || length(show_shape_legend) != 1L ||
      is.na(show_shape_legend)) {
    cli::cli_abort("{.arg show_shape_legend} must be TRUE or FALSE.")
  }

  .validate_inputs(data, vars, adjust, na_action)
  vars <- .resolve_vars(data, vars)

  if (order == "hclust") {
    vars <- .reorder_hclust(data, vars)
  } else if (order == "alphabetical") {
    vars <- sort(vars)
  }

  fits <- .fit_all_pairs(
    data = data, vars = vars, adjust = adjust,
    method = method, k = k, bs = bs,
    na_action = na_action, parallel = parallel, ...
  )

  # Colour-scale limits pooled across off-diagonal cells. Correlation
  # encodings use fixed symmetric [-1, 1]; non-linearity indices use
  # the observed data range so we get full use of the palette.
  colour_vals <- vapply(
    fits, function(f) .colour_value(f, colour_by), numeric(1L)
  )
  colour_limits <- if (colour_by == "none" || all(is.na(colour_vals))) {
    c(NA_real_, NA_real_)
  } else if (.is_correlation_colour(colour_by)) {
    c(-1, 1)
  } else {
    range(colour_vals, na.rm = TRUE)
  }

  asym_tbl <- .asymmetry_table(fits, vars)

  k_n <- length(vars)
  text_sizes <- .cell_text_sizes(
    k_n,
    text_scale_diag     = text_scale_diag,
    text_scale_off_diag = text_scale_off_diag
  )
  cells_by_ij <- vector("list", length(fits))
  names(cells_by_ij) <- names(fits)
  for (key in names(fits)) {
    f <- fits[[key]]
    ij <- as.integer(strsplit(key, "_", fixed = TRUE)[[1L]])
    is_upper <- ij[1L] < ij[2L]
    asym_key <- paste(sort(ij), collapse = "_")
    cells_by_ij[[key]] <- .build_cell(
      fit_obj = f,
      show_data = show_data, show_ci = show_ci,
      colour_by = colour_by, palette = palette,
      signif_glyph = signif_glyph,
      annotations = annotations,
      shape_cutoffs = shape_cutoffs,
      glyph_style = glyph_style,
      asym_val = asym_tbl[[asym_key]] %||% NA_real_,
      colour_limits = colour_limits,
      is_upper = is_upper,
      text_sizes = text_sizes
    )
  }

  diag_cells <- lapply(vars, .build_diagonal_cell,
                       text_sizes = text_sizes)

  # Shape legend is a standing reference: it now renders the full
  # taxonomy regardless of which categories are present in the
  # matrix or whether the user opted into cell-level shape glyphs.
  shape_legend_plot <- if (isTRUE(show_shape_legend)) {
    .build_shape_legend_plot()
  } else {
    NULL
  }

  composite <- .assemble_matrix(
    cells_by_ij, diag_cells, vars,
    colour_by = colour_by, colour_limits = colour_limits,
    palette = palette, shape_legend_plot = shape_legend_plot
  )
  plot_out <- if (isTRUE(show_glossary)) {
    .add_glossary(composite, signif_glyph, annotations, colour_by,
                  scale = glossary_scale)
  } else {
    composite
  }

  if (!isTRUE(with_data)) {
    return(plot_out)
  }

  list(
    plot = plot_out,
    data = .build_summary_table(fits, vars, colour_by, asym_tbl,
                                shape_cutoffs)
  )
}

# ---------------------------------------------------------------
# Flat per-cell summary table — mirrors what the plot displays.
# ---------------------------------------------------------------

.build_summary_table <- function(fits, vars, colour_by, asym_tbl,
                                 shape_cutoffs) {
  rows <- lapply(names(fits), function(key) {
    f <- fits[[key]]
    ij <- as.integer(strsplit(key, "_", fixed = TRUE)[[1L]])
    position <- if (ij[1L] < ij[2L]) "upper" else "lower"
    asym_key <- paste(sort(ij), collapse = "_")
    shape_cat <- .classify_shape(
      f$shape$monotonicity_index, f$shape$convexity_index,
      f$shape$n_turning_points, f$shape$n_inflections,
      f$shape$flat_range_ratio, shape_cutoffs
    )
    data.frame(
      var_x              = f$x_name,
      var_y              = f$y_name,
      position           = position,
      n_used             = f$n_used,
      edf                = f$edf,
      pvalue             = f$pvalue,
      signif             = .pvalue_to_glyph(f$pvalue),
      dev_exp            = f$dev_exp,
      asymmetry_index    = asym_tbl[[asym_key]] %||% NA_real_,
      cor_pearson        = f$corr$cor_pearson,
      cor_spearman       = f$corr$cor_spearman,
      cor_kendall        = f$corr$cor_kendall,
      tie_ratio          = f$corr$tie_ratio,
      monotonicity_index = f$shape$monotonicity_index,
      convexity_index    = f$shape$convexity_index,
      n_turning_points   = f$shape$n_turning_points,
      n_inflections      = f$shape$n_inflections,
      flat_range_ratio   = f$shape$flat_range_ratio,
      shape_category     = shape_cat,
      shape_code         = .shape_lookup(shape_cat, "code"),
      shape_archetype    = .shape_lookup(shape_cat, "archetype"),
      shape_monotonic    = .shape_lookup(shape_cat, "monotonic"),
      shape_linear       = .shape_lookup(shape_cat, "linear"),
      colour_value       = .colour_value(f, colour_by),
      stringsAsFactors   = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  if (rlang::is_installed("data.table")) {
    return(data.table::as.data.table(out))
  }
  out
}

# ---------------------------------------------------------------
# Glossary caption — only lists keys actually shown on the plot.
# ---------------------------------------------------------------

.add_glossary <- function(composite, signif_glyph, annotations,
                          colour_by, scale = 1) {
  parts <- character()
  if ("A" %in% annotations) {
    parts <- c(parts,
      "A = asymmetry index |EDF_yx - EDF_xy| / (EDF_yx + EDF_xy), in [0, 1]")
  }
  if ("edf" %in% annotations) {
    parts <- c(parts,
      "EDF = effective degrees of freedom of the smooth"
    )
  }
  if ("shape" %in% annotations) {
    parts <- c(parts,
      "Shape glyph = objective shape category (see shape-types legend below)"
    )
  }
  colour_msg <- switch(colour_by,
    spearman     = "Cell colour encodes Spearman rank correlation (corr)",
    pearson      = "Cell colour encodes Pearson correlation (corr)",
    kendall      = "Cell colour encodes Kendall correlation (corr)",
    edf          = "Cell colour encodes EDF (see right-margin legend)",
    deviance_gap = "Cell colour encodes deviance explained",
    none         = NULL
  )
  if (!is.null(colour_msg)) parts <- c(parts, colour_msg)
  if (signif_glyph) {
    parts <- c(parts,
      "Signif. of smooth F-test: *** p<.001, ** p<.01, * p<.05, \u00b7 p<.1")
  }
  caption <- paste(parts, collapse = "\n")
  composite +
    patchwork::plot_annotation(
      caption = caption,
      theme = ggplot2::theme(
        plot.caption = ggplot2::element_text(
          size       = 9 * scale,
          hjust      = 0,
          colour     = "grey25",
          lineheight = 1.1,
          margin     = ggplot2::margin(t = 8, b = 2)
        )
      )
    )
}

# Helper used only by janusplot(): asymmetry index lookup by unordered pair
.asymmetry_table <- function(fits, vars) {
  k <- length(vars)
  tbl <- list()
  for (i in seq_len(k - 1L)) {
    for (j in (i + 1L):k) {
      f_ij <- fits[[sprintf("%d_%d", i, j)]]
      f_ji <- fits[[sprintf("%d_%d", j, i)]]
      if (is.null(f_ij) || is.null(f_ji)) next
      tbl[[paste(i, j, sep = "_")]] <- .compute_asymmetry_index(
        f_ij$edf, f_ji$edf
      )
    }
  }
  tbl
}


#' Raw GAM fits and per-cell metrics for a smoothed-association matrix
#'
#' @description
#' Companion to [janusplot()] returning the raw list of GAM fits plus
#' per-cell metrics (EDF, F-test p-value, deviance explained, asymmetry
#' index, pairwise correlations, shape descriptors) without constructing
#' the ggplot. Useful for custom rendering or downstream analysis.
#'
#' @inheritParams janusplot
#' @param keep_fits Logical. If `TRUE`, retain full [mgcv::gam()] model
#'   objects in the return (large memory footprint for `k` above ~15).
#'   Default `FALSE` — retains summary metrics and prediction grids only.
#' @param shape_cutoffs Named list of classification thresholds used to
#'   map the continuous shape indices (`monotonicity_index`,
#'   `convexity_index`) into discrete
#'   `shape_category` labels. Defaults from [janusplot_shape_cutoffs()].
#'
#' @returns A list with components:
#' \describe{
#'   \item{`vars`}{Character vector of variables used, in plotted order.}
#'   \item{`pairs`}{List of per-pair results. Each element has `i`, `j`,
#'     `var_i`, `var_j`, `fit_yx`, `fit_xy` (NULL if `keep_fits = FALSE`),
#'     `pred_yx`, `pred_xy` (data frames with `x`, `fit`, `se`, `lo`,
#'     `hi`), `edf_yx`, `edf_xy`, `pvalue_yx`, `pvalue_xy`, `dev_exp_yx`,
#'     `dev_exp_xy`, `n_used`, `asymmetry_index`, plus Pearson /
#'     Spearman / Kendall correlations (`cor_pearson`, `cor_spearman`,
#'     `cor_kendall`), the maximum tie ratio across `x` and `y`
#'     (`tie_ratio`), and per-direction shape descriptors
#'     (`monotonicity_index_yx`, `convexity_index_yx`,
#'     `monotonicity_index_xy`, `convexity_index_xy`,
#'     `n_turning_yx`, `n_inflect_yx`, `n_turning_xy`,
#'     `n_inflect_xy`, `shape_yx`, `shape_xy`).
#'     See [janusplot_shape_metrics()] for the definition of the
#'     monotonicity and convexity indices.}
#'   \item{`call`}{Match call.}
#' }
#'
#' @family smooth-associations
#' @seealso [janusplot()] for the ggplot front-end,
#'   [janusplot_shape_metrics()] for the shape-metric primitives.
#'
#' @examples
#' # Per-pair fits + metrics on a small mtcars slice
#' out <- janusplot_data(mtcars[, c("mpg", "hp", "wt")])
#' out$pairs[[1L]]$asymmetry_index
#' out$pairs[[1L]]$cor_spearman
#' out$pairs[[1L]]$shape_yx
#' @export
janusplot_data <- function(
    data,
    vars = NULL,
    adjust = NULL,
    method = "REML",
    k = -1L,
    bs = "tp",
    na_action = c("pairwise", "complete"),
    parallel = FALSE,
    keep_fits = FALSE,
    shape_cutoffs = janusplot_shape_cutoffs(),
    ...) {
  na_action <- rlang::arg_match(na_action)
  .validate_inputs(data, vars, adjust, na_action)
  vars <- .resolve_vars(data, vars)

  fits <- .fit_all_pairs(
    data = data, vars = vars, adjust = adjust,
    method = method, k = k, bs = bs,
    na_action = na_action, parallel = parallel, ...
  )

  k_n <- length(vars)
  pairs_out <- list()
  for (i in seq_len(k_n - 1L)) {
    for (j in (i + 1L):k_n) {
      f_yx <- fits[[sprintf("%d_%d", i, j)]]   # y = vars[j] ~ s(vars[i])
      f_xy <- fits[[sprintf("%d_%d", j, i)]]   # y = vars[i] ~ s(vars[j])
      shape_yx <- .classify_shape(
        f_yx$shape$monotonicity_index, f_yx$shape$convexity_index,
        f_yx$shape$n_turning_points, f_yx$shape$n_inflections,
        f_yx$shape$flat_range_ratio, shape_cutoffs
      )
      shape_xy <- .classify_shape(
        f_xy$shape$monotonicity_index, f_xy$shape$convexity_index,
        f_xy$shape$n_turning_points, f_xy$shape$n_inflections,
        f_xy$shape$flat_range_ratio, shape_cutoffs
      )
      corr <- f_yx$corr %||% f_xy$corr
      pairs_out[[length(pairs_out) + 1L]] <- list(
        i                      = i,
        j                      = j,
        var_i                  = vars[i],
        var_j                  = vars[j],
        fit_yx                 = if (keep_fits) f_yx$fit else NULL,
        fit_xy                 = if (keep_fits) f_xy$fit else NULL,
        pred_yx                = f_yx$pred,
        pred_xy                = f_xy$pred,
        edf_yx                 = f_yx$edf,
        edf_xy                 = f_xy$edf,
        pvalue_yx              = f_yx$pvalue,
        pvalue_xy              = f_xy$pvalue,
        dev_exp_yx             = f_yx$dev_exp,
        dev_exp_xy             = f_xy$dev_exp,
        n_used                 = min(f_yx$n_used, f_xy$n_used),
        asymmetry_index        = .compute_asymmetry_index(f_yx$edf, f_xy$edf),
        cor_pearson            = corr$cor_pearson,
        cor_spearman           = corr$cor_spearman,
        cor_kendall            = corr$cor_kendall,
        tie_ratio              = corr$tie_ratio,
        monotonicity_index_yx  = f_yx$shape$monotonicity_index,
        convexity_index_yx     = f_yx$shape$convexity_index,
        monotonicity_index_xy  = f_xy$shape$monotonicity_index,
        convexity_index_xy     = f_xy$shape$convexity_index,
        n_turning_yx           = f_yx$shape$n_turning_points,
        n_inflect_yx           = f_yx$shape$n_inflections,
        n_turning_xy           = f_xy$shape$n_turning_points,
        n_inflect_xy           = f_xy$shape$n_inflections,
        shape_yx           = shape_yx,
        shape_xy           = shape_xy,
        shape_code_yx      = .shape_lookup(shape_yx, "code"),
        shape_code_xy      = .shape_lookup(shape_xy, "code"),
        shape_archetype_yx = .shape_lookup(shape_yx, "archetype"),
        shape_archetype_xy = .shape_lookup(shape_xy, "archetype"),
        shape_monotonic_yx = .shape_lookup(shape_yx, "monotonic"),
        shape_monotonic_xy = .shape_lookup(shape_xy, "monotonic"),
        shape_linear_yx    = .shape_lookup(shape_yx, "linear"),
        shape_linear_xy    = .shape_lookup(shape_xy, "linear")
      )
    }
  }
  list(vars = vars, pairs = pairs_out, call = match.call())
}
