#' Asymmetric smoothed-association matrix
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Render a pairwise, asymmetric matrix of smoothed associations between
#' numeric variables. Each cell \[i, j\] where `i != j` shows the fitted
#' spline from [mgcv::gam()]:
#' * Upper triangle (`i < j`): `gam(x_j ~ s(x_i) + <adjust>)`.
#' * Lower triangle (`i > j`): `gam(x_i ~ s(x_j) + <adjust>)`.
#' * Diagonal: blank panel when labels live on the border (default),
#'   or a variable-name label when `labels = "diagonal"`.
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
#'   points (low alpha) behind each spline. Only applies when
#'   `display = "fit"`; derivative panels never overlay raw data.
#' @param show_ci Logical. If `TRUE` (default), overlay the 95%
#'   confidence envelope from `predict(gam, se.fit = TRUE)` on the
#'   fit panel (i.e. when `display = "fit"`). CI rendering on
#'   derivative panels is controlled separately by `derivative_ci`.
#' @param display One of `"fit"` (default), `"d1"`, or `"d2"`.
#'   Selects which single quantity is rendered in every
#'   off-diagonal cell of the matrix.
#'   * `"fit"` — the fitted smooth \eqn{\hat f(x)}; default,
#'     behaviour identical to the pre-derivative release.
#'   * `"d1"` — the first derivative \eqn{\hat f'(x)} of the
#'     fitted smooth. Zero crossings localise turning points of
#'     \eqn{\hat f}.
#'   * `"d2"` — the second derivative \eqn{\hat f''(x)}. Zero
#'     crossings localise inflection points of \eqn{\hat f}.
#'
#'   A single matrix shows a single quantity by design: stacked
#'   multi-panel cells crowd the matrix at any realistic variable
#'   count. To compare fit against derivative, render two or three
#'   `janusplot()` calls side-by-side; each call keeps its own
#'   `with_data = TRUE` summary table tagged with the `display`
#'   column.
#'
#'   Orders \eqn{k \ge 3} are not exposed — higher-order derivatives
#'   of penalised regression splines amplify noise and rarely carry
#'   usable signal at realistic sample sizes. See
#'   `vignette("janusplot")` for the theoretical justification and
#'   applied use-cases.
#' @param derivative_ci One of `"none"` (default), `"pointwise"`, or
#'   `"simultaneous"`. Controls whether — and how — a 95%
#'   confidence ribbon is drawn underneath the derivative curve when
#'   `display %in% c("d1", "d2")`. Ignored when `display = "fit"`.
#'   * `"none"` — no ribbon. The curve and the zero reference line
#'     are all you see. Default, because pointwise ribbons overshoot
#'     nominal coverage as a joint region and can invite
#'     over-reading of local features.
#'   * `"pointwise"` — 95% pointwise ribbon from
#'     \eqn{\sqrt{\mathrm{diag}(D V_p D^\top)}} (Wood 2017 §7.2.4).
#'     Valid marginally; not a simultaneous statement.
#'   * `"simultaneous"` — 95% simultaneous band via the Monte Carlo
#'     construction of Ruppert, Wand & Carroll (2003) popularised for
#'     GAMs by Simpson (2018, *Frontiers Ecol. Evol.* 6:149): draw
#'     \eqn{B} samples \eqn{\tilde{\boldsymbol\beta} \sim
#'     \mathcal{N}(\hat{\boldsymbol\beta}, V_p)}, compute
#'     \eqn{\max_x |D_i(\tilde{\boldsymbol\beta} -
#'     \hat{\boldsymbol\beta})| / \mathrm{se}_i}, and use the
#'     \eqn{(1-\alpha)} quantile as a critical multiplier on the
#'     pointwise SE. Valid for feature localisation ("where is
#'     \eqn{\hat f'(x)} significantly non-zero").
#' @param derivative_ci_nsim Integer. Number of Monte Carlo samples
#'   used when `derivative_ci = "simultaneous"`. Default `1000L` —
#'   a compromise between coverage accuracy (Simpson 2018 uses
#'   10000) and CPU budget across every pair in a medium-sized
#'   matrix. Ignored for any other `derivative_ci`.
#' @param n_grid Integer or `NULL`. Number of equally-spaced points
#'   used to evaluate each fitted smooth (and its derivatives).
#'   Default `NULL` resolves to `100` when `display = "fit"` and
#'   `200` otherwise, because finite-difference second derivatives
#'   visibly degrade below \eqn{\sim 150} points on moderate-`k`
#'   smooths. Supplying `n_grid` directly overrides both defaults.
#'   Larger grids shift the numerical shape-metric values
#'   (\eqn{M}, \eqn{C}, turning / inflection counts) slightly
#'   because they are computed on this same grid. Shapes and
#'   asymmetry are the primary reading; `M`, `C` and the counts are
#'   secondary diagnostics and the grid-induced drift is tolerable.
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
#' @param labels One of `"border"` (default), `"diagonal"`, or
#'   `"none"`. Controls where variable names are rendered:
#'   * `"border"` — names along the top (rotated per `label_srt`) and
#'     left margins of the matrix; diagonal cells are left blank.
#'     Mirrors `corrplot`'s `tl.pos = "lt"` convention.
#'   * `"diagonal"` — names centred on the diagonal cells (the
#'     pre-0.1 layout).
#'   * `"none"` — labels suppressed entirely; diagonal cells blank.
#' @param diagonal One of `"auto"` (default), `"blank"`, `"name"`,
#'   or `"density"`. Controls what is rendered in the diagonal
#'   cells of the matrix.
#'   * `"auto"` — preserves the historical behaviour: variable name
#'     when `labels = "diagonal"`, blank otherwise.
#'   * `"blank"` — empty bordered panel (uniform grid reading).
#'   * `"name"` — variable name centred in the cell, bold.
#'   * `"density"` — kernel density of the variable filled in
#'     translucent grey, with a rug of raw values along the bottom
#'     edge. Mirrors the `GGally::ggpairs` convention; surfaces
#'     tail weight, bimodality, and support clipping that the
#'     pairwise smooths alone cannot reveal. Variable names should
#'     come from the border (`labels = "border"`, the default) when
#'     this mode is on.
#' @param label_srt Numeric. Rotation (degrees) of top labels when
#'   `labels = "border"`. Default `45`; set to `0` for horizontal or
#'   `90` for vertical. Ignored when `labels != "border"`.
#' @param label_cex Positive numeric multiplier on the border-label
#'   font size. Default `1`. Ignored when `labels = "none"`.
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
#'   The `data` element is always a plain `data.frame` (base R — no
#'   `data.table` dependency). Default `FALSE` — in which case only
#'   the ggplot is returned.
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
#'   (via [patchwork::wrap_plots()]) carrying a top-of-matrix title
#'   that names the displayed quantity (`"Direct fit"`,
#'   `"First derivative f'"`, or `"Second derivative f''"`). If
#'   `with_data = TRUE`, a list with two elements: `plot` (the
#'   ggplot) and `data` (a tidy table with columns `var_x`, `var_y`,
#'   `position`, `n_used`, `edf`, `pvalue`, `signif`, `dev_exp`,
#'   `asymmetry_index`, `cor_pearson`, `cor_spearman`,
#'   `cor_kendall`, `tie_ratio`, `monotonicity_index`,
#'   `convexity_index`, `n_turning_points`, `n_inflections`,
#'   `flat_range_ratio`, `shape_category`, `colour_value`,
#'   `display`, one row per off-diagonal cell). The `display`
#'   column tags which quantity the call rendered, so separate
#'   calls for fit / d1 / d2 yield comparable, stackable tables.
#'   Derivative *curves* themselves (grid of \eqn{x}, fitted
#'   \eqn{\hat f^{(k)}}, SE) live on `janusplot_data()` — see there.
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
#' janusplot(data.frame(x1 = x1, x2 = x2, x3 = stats::rnorm(n)))
#'
#' # A single matrix renders a single quantity. To compare the fit
#' # against its derivatives, render three calls and place them
#' # side-by-side; each call's title makes the quantity explicit.
#' set.seed(2026L)
#' xs <- stats::runif(300L, -3, 3)
#' df <- data.frame(
#'   x  = xs,
#'   y1 = sin(xs)  + stats::rnorm(300L, sd = 0.3),
#'   y2 = xs^2     + stats::rnorm(300L, sd = 0.6)
#' )
#' janusplot(df, display = "fit")
#' janusplot(df, display = "d1")
#' janusplot(df, display = "d2")
#'
#' # Simultaneous CI bands on a derivative panel, per Simpson (2018).
#' janusplot(df, display = "d1", derivative_ci = "simultaneous")
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
    display = c("fit", "d1", "d2"),
    derivative_ci = c("none", "pointwise", "simultaneous"),
    derivative_ci_nsim = 1000L,
    n_grid = NULL,
    colour_by = c("pearson", "spearman", "kendall",
                  "edf", "deviance_gap", "none"),
    fill_by = NULL,
    palette = NULL,
    annotations = c("edf", "A"),
    shape_cutoffs = janusplot_shape_cutoffs(),
    show_shape_legend = TRUE,
    glyph_style = c("ascii", "unicode"),
    labels = c("border", "diagonal", "none"),
    diagonal = c("auto", "blank", "name", "density"),
    label_srt = 45,
    label_cex = 1,
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
  order         <- rlang::arg_match(order)
  na_action     <- rlang::arg_match(na_action)
  glyph_style   <- rlang::arg_match(glyph_style)
  labels        <- rlang::arg_match(labels)
  diagonal      <- rlang::arg_match(diagonal)
  display       <- rlang::arg_match(display)
  derivative_ci <- rlang::arg_match(derivative_ci)
  # `diagonal = "auto"` resolves to the historical behaviour: name
  # in the diagonal cell when labels == "diagonal", blank otherwise.
  diagonal_eff <- if (diagonal == "auto") {
    if (labels == "diagonal") "name" else "blank"
  } else {
    diagonal
  }

  if (!is.numeric(derivative_ci_nsim) ||
      length(derivative_ci_nsim) != 1L ||
      !is.finite(derivative_ci_nsim) ||
      derivative_ci_nsim < 100) {
    cli::cli_abort(
      "{.arg derivative_ci_nsim} must be a single integer >= 100."
    )
  }
  derivative_ci_nsim <- as.integer(derivative_ci_nsim)

  if (!is.numeric(label_srt) || length(label_srt) != 1L ||
      is.na(label_srt)) {
    cli::cli_abort("{.arg label_srt} must be a single numeric value.")
  }
  .check_scalar_positive(label_cex, "label_cex")

  # Dual-alias: fill_by -> colour_by (soft deprecation).
  if (!is.null(fill_by)) {
    lifecycle::deprecate_warn(
      when = "0.0.0.9000",
      what = "janusplot(fill_by = )",
      with = "janusplot(colour_by = )",
      details = paste0("Forwarding \"", fill_by, "\" to colour_by.")
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

  # Resolve a single integer derivative order from scalar display.
  # "fit" → no derivatives computed; "d1" / "d2" → the matching order.
  derivative_orders <- switch(display,
    fit = integer(),
    d1  = 1L,
    d2  = 2L
  )

  # Validate and resolve n_grid. NULL means "100 if no derivatives,
  # 200 otherwise"; a user value overrides both defaults. Flag very
  # large grids — fit time scales as O(n_grid) and derivative SE as
  # O(n_grid) via the D %*% Vp %*% t(D) product.
  if (!is.null(n_grid)) {
    if (!is.numeric(n_grid) || length(n_grid) != 1L ||
        !is.finite(n_grid) || n_grid < 10) {
      cli::cli_abort(
        "{.arg n_grid} must be a single finite number >= 10 or NULL."
      )
    }
    n_grid <- as.integer(n_grid)
    if (n_grid > 500L) {
      cli::cli_inform(c(
        "!" = paste0(
          "{.arg n_grid} = {n_grid} is unusually large \u2014 ",
          "each pair pays an O(n_grid) predict cost."
        ),
        i = "Grids above ~300 rarely improve readability."
      ))
    }
  } else {
    n_grid <- if (length(derivative_orders)) 200L else 100L
  }

  # Dual-alias: show_asymmetry -> annotations (soft deprecation).
  if (!is.null(show_asymmetry)) {
    lifecycle::deprecate_warn(
      when = "0.0.0.9000",
      what = "janusplot(show_asymmetry = )",
      with = "janusplot(annotations = )"
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
    na_action = na_action, parallel = parallel,
    n_grid = n_grid, derivatives = derivative_orders,
    derivative_ci = derivative_ci,
    derivative_ci_nsim = derivative_ci_nsim, ...
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
      text_sizes = text_sizes,
      display = display,
      derivative_ci = derivative_ci
    )
  }

  diag_cells <- lapply(vars, function(v) {
    switch(diagonal_eff,
      blank   = .build_blank_diagonal_cell(),
      name    = .build_diagonal_cell(v, text_sizes = text_sizes),
      density = .build_density_rug_cell(v, data[[v]],
                                        text_sizes = text_sizes)
    )
  })

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
    palette = palette, shape_legend_plot = shape_legend_plot,
    labels = labels, label_srt = label_srt, label_cex = label_cex
  )
  plot_out <- .finalize_plot(
    composite,
    title   = .display_title(display, glyph_style),
    caption = if (isTRUE(show_glossary)) {
      .build_glossary_text(signif_glyph, annotations, colour_by, display,
                           derivative_ci)
    } else {
      NULL
    },
    glossary_scale = glossary_scale
  )

  if (!isTRUE(with_data)) {
    return(plot_out)
  }

  list(
    plot = plot_out,
    data = .build_summary_table(fits, vars, colour_by, asym_tbl,
                                shape_cutoffs, display = display)
  )
}

# ---------------------------------------------------------------
# Flat per-cell summary table — mirrors what the plot displays.
# ---------------------------------------------------------------

.build_summary_table <- function(fits, vars, colour_by, asym_tbl,
                                 shape_cutoffs, display = "fit") {
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
      display            = display,
      stringsAsFactors   = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# ---------------------------------------------------------------
# Display-mode title: the label at the top of the assembled matrix
# naming what is rendered in every cell. Unicode primes by default,
# ASCII fallback when glyph_style = "ascii".
# ---------------------------------------------------------------

.display_title <- function(display, glyph_style = c("ascii", "unicode")) {
  glyph_style <- rlang::arg_match(glyph_style)
  if (glyph_style == "unicode") {
    switch(display,
      fit = "Direct fit",
      d1  = "First derivative  f\u2032(x)",
      d2  = "Second derivative  f\u2033(x)",
      display
    )
  } else {
    switch(display,
      fit = "Direct fit",
      d1  = "First derivative  df/dx",
      d2  = "Second derivative  d^2 f / dx^2",
      display
    )
  }
}

# ---------------------------------------------------------------
# Glossary caption body — only lists keys actually shown on the
# plot. Extended to mention the derivative CI mode when a
# derivative is displayed.
# ---------------------------------------------------------------

.build_glossary_text <- function(signif_glyph, annotations, colour_by,
                                 display = "fit", derivative_ci = "none") {
  parts <- character()
  if (display == "fit" && "A" %in% annotations) {
    parts <- c(parts,
      "A = asymmetry index |EDF_yx - EDF_xy| / (EDF_yx + EDF_xy), in [0, 1]")
  }
  if (display == "fit" && "edf" %in% annotations) {
    parts <- c(parts,
      "EDF = effective degrees of freedom of the smooth")
  }
  if (display == "fit" && "shape" %in% annotations) {
    parts <- c(parts,
      "Shape glyph = objective shape category (see shape-types legend below)")
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
  if (display == "fit" && signif_glyph) {
    parts <- c(parts,
      "Signif. of smooth F-test: *** p<.001, ** p<.01, * p<.05, \u00b7 p<.1")
  }
  if (display %in% c("d1", "d2")) {
    parts <- c(parts, sprintf(
      "Derivative panel: curve from D %%*%% coef(gam), dashed line at zero; CI mode = %s",
      derivative_ci
    ))
  }
  paste(parts, collapse = "\n")
}

# ---------------------------------------------------------------
# Finalise composite plot — add title + optional caption in a
# single plot_annotation call so patchwork lays them out cleanly.
# ---------------------------------------------------------------

.finalize_plot <- function(composite, title, caption = NULL,
                           glossary_scale = 1) {
  composite +
    patchwork::plot_annotation(
      title   = title,
      caption = caption,
      theme = ggplot2::theme(
        plot.title   = ggplot2::element_text(
          size       = 13,
          face       = "bold",
          hjust      = 0,
          colour     = "grey10",
          margin     = ggplot2::margin(t = 2, b = 6)
        ),
        plot.caption = ggplot2::element_text(
          size       = 9 * glossary_scale,
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
#' `r lifecycle::badge("experimental")`
#'
#' Companion to [janusplot()] returning the raw list of GAM fits plus
#' per-cell metrics (EDF, F-test p-value, deviance explained, asymmetry
#' index, pairwise correlations, shape descriptors) without constructing
#' the ggplot. Useful for custom rendering or downstream analysis.
#'
#' @inheritParams janusplot
#' @param keep_fits Logical. If `TRUE`, retain full [mgcv::gam()] model
#'   objects in the return (large memory footprint for `k` above ~15).
#'   Default `FALSE` — retains summary metrics and prediction grids only.
#' @param derivatives Integer vector of derivative orders to compute
#'   on every pair (subset of `1:2`). Default `integer()` — no
#'   derivatives. Unlike `janusplot()`, the data companion can
#'   return multiple orders from a single call for programmatic
#'   analysis; pass `c(1L, 2L)` to surface both.
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
#'     When `derivatives` is non-empty, each pair additionally
#'     carries `deriv_yx` and `deriv_xy`, each a named list keyed by
#'     order (`"1"`, `"2"`) whose entries are data frames with
#'     columns `x`, `fit`, `se`, `lo`, `hi`, `ci_type` matching the
#'     schema of `pred_yx` / `pred_xy`. The `ci_type` column records
#'     whether the `lo` / `hi` columns are `"pointwise"` (default),
#'     `"simultaneous"` (Ruppert--Wand--Carroll / Simpson 2018
#'     critical-multiplier bands), or `"none"`. When
#'     `derivative_ci = "simultaneous"`, each derivative frame also
#'     carries a `"crit_multiplier"` attribute giving the MC-derived
#'     critical multiplier used.
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
    derivatives = integer(),
    derivative_ci = c("pointwise", "none", "simultaneous"),
    derivative_ci_nsim = 1000L,
    n_grid = NULL,
    shape_cutoffs = janusplot_shape_cutoffs(),
    ...) {
  na_action     <- rlang::arg_match(na_action)
  derivative_ci <- rlang::arg_match(derivative_ci)
  .validate_inputs(data, vars, adjust, na_action)
  vars <- .resolve_vars(data, vars)

  if (length(derivatives)) {
    if (!is.numeric(derivatives) || anyNA(derivatives)) {
      cli::cli_abort(
        "{.arg derivatives} must be an integer vector of orders in 1:2."
      )
    }
    derivatives <- as.integer(derivatives)
    if (any(derivatives < 1L | derivatives > 2L)) {
      cli::cli_abort(
        "{.arg derivatives} entries must be in 1:2 \u2014 higher orders are not supported."
      )
    }
    if (anyDuplicated(derivatives)) {
      cli::cli_abort("{.arg derivatives} must not contain duplicates.")
    }
  }

  if (!is.numeric(derivative_ci_nsim) ||
      length(derivative_ci_nsim) != 1L ||
      !is.finite(derivative_ci_nsim) ||
      derivative_ci_nsim < 100) {
    cli::cli_abort(
      "{.arg derivative_ci_nsim} must be a single integer >= 100."
    )
  }
  derivative_ci_nsim <- as.integer(derivative_ci_nsim)

  if (!is.null(n_grid)) {
    if (!is.numeric(n_grid) || length(n_grid) != 1L ||
        !is.finite(n_grid) || n_grid < 10) {
      cli::cli_abort(
        "{.arg n_grid} must be a single finite number >= 10 or NULL."
      )
    }
    n_grid <- as.integer(n_grid)
  } else {
    n_grid <- if (length(derivatives)) 200L else 100L
  }

  fits <- .fit_all_pairs(
    data = data, vars = vars, adjust = adjust,
    method = method, k = k, bs = bs,
    na_action = na_action, parallel = parallel,
    n_grid = n_grid, derivatives = derivatives,
    derivative_ci = derivative_ci,
    derivative_ci_nsim = derivative_ci_nsim, ...
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
        shape_linear_xy    = .shape_lookup(shape_xy, "linear"),
        deriv_yx           = f_yx$deriv,
        deriv_xy           = f_xy$deriv
      )
    }
  }
  list(vars = vars, pairs = pairs_out, call = match.call())
}
