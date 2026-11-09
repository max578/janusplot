# plot.R -- The plot() method of a janusplot_fit: the matrix view. Every
# number drawn comes from the fit object; nothing is refitted. The cell
# renderer, the strip and the colour scales live in internal-cell.R, the
# patchwork assembly in internal-assemble.R, the style object in style.R.

#' Draw the matrix of a janusplot fit
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Draws the asymmetric matrix of a [janusplot_fit()] object: one cell per
#' directed pair, the fitted curve with its band over the raw points, the
#' variable names along the top and left borders. Nothing is refitted;
#' every number on the plot is in the object.
#'
#' @details
#' Every off-diagonal cell `[r, c]` shows `vars[r] ~ s(vars[c])`: the
#' variable named left of the row is the response on the vertical axis and
#' the variable named above the column is the predictor on the horizontal
#' axis, as in [graphics::pairs()]. Cells `[r, c]` and `[c, r]` are the two
#' directions of one pair and differ by design. A key in the top-left
#' corner shows the convention with the first two variables
#' (`style$show_key`).
#'
#' The `colour_by` value is painted on the border, a corner tile or the
#' whole cell per `style$colour_channel`, with one colour bar per matrix.
#' The `background_by` correlation tints the panel behind the points, band
#' and curve: white at zero and `style$background_strength` of the way to
#' the negative or positive end of `style$background_palette`
#' at minus or plus one, with its own colour bar over `[-1, 1]`. A strip
#' above each cell carries the `annotations`; the asymmetry index belongs
#' to the pair and is written once, above the cell in the upper triangle.
#' The diagonal shows the kernel density of each variable with a rug of
#' its values, and with `group` one density per level, scaled by the
#' level's share of the rows so the coloured curves sum to the grey
#' pooled density (`style$diagonal`).
#'
#' The default sizes are set for a figure one page wide (170 mm). At one
#' journal column (85 mm), draw at most four variables with
#' `janusplot_style(text_size = 6, show_shape_legend = FALSE,
#' show_glossary = FALSE)`.
#'
#' The colour bars sit in a column to the right of the matrix, which suits
#' a wide screen. For a printed page,
#' `janusplot_style(legend_position = "bottom", label_srt = 0)` puts the
#' bars and the key under the matrix, so the cells take the full width,
#' and `show_glossary = FALSE` leaves the explanation to the figure
#' caption.
#'
#' `colour_by = "edf"` is accepted for one release and mapped to
#' `"nonlinearity"` with a deprecation message.
#'
#' @param x A `janusplot_fit` object.
#' @param colour_by The quantity painted on each cell: `"nonlinearity"`
#'   (the default; EDF minus 1 of the cell's smooth, sequential from 0),
#'   `"asymmetry"` (the pair's index A in `[0, 1]`, the same in both
#'   cells), `"pearson"`, `"spearman"` or `"kendall"` (the pair's
#'   correlation on a diverging scale over `[-1, 1]`), `"deviance_gap"`
#'   (deviance explained by the smooth minus the straight line's) or
#'   `"none"`.
#' @param background_by The correlation that tints each cell's
#'   background: `"pearson"`, `"spearman"`, `"kendall"`, or `"none"` for no
#'   background. Left unset, it is `"pearson"` for a marginal fit and
#'   `"none"` for a fit with `adjust`, whose curves are adjusted while the
#'   correlations are marginal; set it to show the marginal correlation
#'   behind adjusted curves. Independent of `colour_by`. It cannot be
#'   combined with `janusplot_style(colour_channel = "fill")`, which paints
#'   the same area.
#' @param annotations Character vector, a subset of `c("A", "edf",
#'   "signif", "code", "shape", "k_warn", "n", "r", "formula")`, written in
#'   the strip of every cell (or in its corners under
#'   `janusplot_style(annotation_position = "corners")`): the asymmetry
#'   index, the EDF, the significance glyph of the smooth F-test (`***`
#'   p < .001, `**` p < .01, `*` p < .05, `.` p < .1, from the adjusted
#'   p-value when the fit has `p_adjust` other than `"none"`), the
#'   two-letter shape code, the shape glyph, a warning sign on cells
#'   flagged by the k-check or capped at the distinct predictor count, the
#'   rows used, the `background_by` correlation of the pair (Pearson when
#'   `background_by = "none"`), printed `"r -0.03"` (`"marginal r -0.03"`
#'   for a fit with `adjust`), and the cell's formula,
#'   printed `Temp ~ Ozone`. `NULL` (the default) picks by matrix size:
#'   `c("A", "signif")` up to twelve variables, `"signif"` from
#'   thirteen, where 5-point strips of neighbouring cells would touch;
#'   `character()` writes none.
#' @param order Order of the variables in the matrix: `"original"` (the
#'   default, the order of `x$vars`), `"hclust"` (hierarchical clustering
#'   of absolute Pearson correlations) or `"alphabetical"`. Drawing only;
#'   the fit is unchanged.
#' @param display What every off-diagonal cell shows: `"fit"` (the
#'   default), `"d1"` (the first derivative of the smooth, whose zero
#'   crossings are turning points) or `"d2"` (the second derivative, whose
#'   zero crossings are inflections). A derivative view needs the fit to
#'   carry that order in `x$settings$derivatives`.
#' @param group Name of a factor, character or logical column of `x$data`
#'   whose levels colour the raw points, with one legend below the matrix,
#'   or `NULL` (the default). Drawing only; the column never enters the
#'   model. The column must exist in `x$data` and have at most
#'   `style$group_max_levels` levels.
#' @param focus_by `NA` (the default, no filter) or one of `"asymmetry"`,
#'   `"edf"`, `"non_linearity"` (EDF minus 1) and `"k_flag"`. Cells whose
#'   metric falls below `focus_threshold` are washed in grey at
#'   `style$focus_dim_alpha`; the matrix keeps its shape. A visual filter
#'   only; the fit and its table are unchanged.
#' @param focus_threshold A quantile string, `"q90"` by default (taken over
#'   the off-diagonal cells), or a single numeric cutoff. Ignored when
#'   `focus_by` is `NA`.
#' @param axes Scale of the drawn axes: `"original"` (the default),
#'   `"standardised"` (`(x - mean) / sd` per variable, border label
#'   `"var (z)"`), `"centred"` (`x - mean`, label `"var (centred)"`) or
#'   `"rank"` (empirical rank, label `"rank(var)"`). Drawing only; the
#'   same transform is applied to the points, the curve and the band.
#' @param style A [janusplot_style()] object holding every appearance
#'   setting.
#' @param ... Must be empty. An unknown name is an error, so a misspelt
#'   style knob cannot pass silently.
#'
#' @returns A [patchwork][patchwork::patchwork-package] object, which is a
#'   ggplot: the matrix with its border labels and corner key, the colour
#'   bar when `colour_by` is not `"none"`, the background colour bar when
#'   `background_by` is not `"none"`, the group legend when `group` is
#'   given,
#'   the shape-categories legend when `style$show_shape_legend` is `TRUE`,
#'   or `"auto"` and `annotations` include `"code"`,
#'   a title naming the displayed quantity and the glossary caption when
#'   `style$show_glossary` is `TRUE`.
#'
#' @family smooth-associations
#' @seealso [janusplot_fit()] for the object, [janusplot_style()] for the
#'   appearance settings, [janusplot()] for the one-call form.
#'
#' @examples
#' fit <- janusplot_fit(mtcars[, c("mpg", "hp", "wt")], engine = "gam")
#' plot(fit)
#' plot(fit, colour_by = "asymmetry", annotations = c("A", "edf", "signif"))
#' plot(fit, background_by = "none", annotations = c("formula", "r"))
#'
#' \donttest{
#' # Points coloured by a factor column of the data; never in the model.
#' pp <- transform(mtcars[, c("mpg", "hp", "wt", "am")],
#'                 am = factor(am, labels = c("auto", "manual")))
#' plot(janusplot_fit(pp, vars = c("mpg", "hp", "wt"), engine = "gam"),
#'      group = "am")
#'
#' # The first derivative of every smooth, computed at fit time.
#' plot(fit, display = "d1")
#' }
#' @method plot janusplot_fit
#' @export
plot.janusplot_fit <- function(
  x,
  colour_by = c("nonlinearity", "asymmetry", "pearson", "spearman", "kendall",
                "deviance_gap", "none"),
  background_by = c("pearson", "spearman", "kendall", "none"),
  annotations = NULL,
  order = c("original", "hclust", "alphabetical"),
  display = c("fit", "d1", "d2"),
  group = NULL,
  focus_by = NA_character_,
  focus_threshold = "q90",
  axes = c("original", "standardised", "centred", "rank"),
  style = janusplot_style(),
  ...
) {
  .check_plot_dots(...)
  .check_style(style)
  colour_by     <- .resolve_colour_by(colour_by,
                                      user_env = rlang::caller_env())
  if (missing(background_by) || is.null(background_by)) {
    background_by <- if (is.null(x$adjust)) "pearson" else "none"
  }
  background_by <- rlang::arg_match(
    background_by, c("pearson", "spearman", "kendall", "none")
  )
  .check_background_channel(background_by, style$colour_channel)
  annotations   <- .check_annotations(annotations)
  order         <- rlang::arg_match(order)
  display       <- rlang::arg_match(display)
  axes          <- rlang::arg_match(axes)
  .check_display_available(display, x$settings$derivatives)
  focus_by      <- .check_focus_by(focus_by)
  grouping      <- .resolve_group(x, group, style)

  # Variable order and matrix-wide settings --------------------------------
  vars <- switch(order,
    original     = x$vars,
    hclust       = .reorder_hclust(x$data, x$vars),
    alphabetical = sort(x$vars)
  )
  k_n <- length(vars)
  a_in_summary <- is.null(annotations) && k_n >= 13L
  annotations <- annotations %||% .default_annotations(k_n)
  tier <- .compact_tier(
    k_n, compact = style$compact,
    compact_threshold = style$compact_threshold,
    compact_levels = style$compact_levels
  )
  text_sizes <- .cell_text_sizes(k_n, style$text_size)
  border_lw  <- .border_linewidth(k_n, style$border_width)
  axis_transforms <- stats::setNames(
    lapply(vars, function(v) .build_axis_transform(x$data[[v]], mode = axes)),
    vars
  )
  palette <- style$palette %||% .default_palette(colour_by)

  # Directed cells: one face per pair and direction, keyed by position ----
  cell_index <- .cell_index(x$pairs, vars)
  faces <- Map(function(i, d) .pair_face(x$pairs[[i]], d),
               cell_index$pair, cell_index$direction)
  names(faces) <- cell_index$key
  colour_vals   <- vapply(faces, .face_colour_value, numeric(1L),
                          colour_by = colour_by)
  colour_limits <- .colour_limits(colour_vals, colour_by)
  colour_hex    <- .colour_hex(colour_vals, colour_by, colour_limits, palette)
  focus_mask    <- .resolve_focus_mask(faces, focus_by, focus_threshold)
  background_hex <- if (background_by == "none") {
    rep(NA_character_, length(faces))
  } else {
    .background_hex(
      vapply(faces, .face_correlation, numeric(1L),
             background_by = background_by),
      style$background_palette, style$background_strength
    )
  }

  # A belongs to the pair: written above the upper-triangle cell only.
  annotations_lower <- setdiff(annotations, "A")
  in_lower <- .cell_in_lower(cell_index$key)

  cells_by_ij <- vector("list", nrow(cell_index))
  names(cells_by_ij) <- cell_index$key
  for (idx in seq_len(nrow(cell_index))) {
    face <- faces[[idx]]
    cells_by_ij[[idx]] <- .render_cell(
      pair             = x$pairs[[cell_index$pair[idx]]],
      direction        = cell_index$direction[idx],
      points           = .cell_points(x, face$var_x, face$var_y, grouping,
                                      .face_partial(face, style)),
      style            = style,
      text_sizes       = text_sizes,
      annotations      = if (in_lower[[idx]]) {
        annotations_lower
      } else {
        annotations
      },
      display          = display,
      p_adjust         = x$settings$p_adjust,
      colour           = colour_hex[[idx]],
      tier             = tier,
      is_focused       = isTRUE(focus_mask[[idx]]),
      group_colours    = grouping$colours,
      x_transform      = axis_transforms[[face$var_x]],
      y_transform      = axis_transforms[[face$var_y]],
      background       = background_hex[[idx]],
      border_linewidth = border_lw,
      background_by    = background_by,
      adjusted         = !is.null(x$adjust),
      point_scale      = .matrix_point_scale(k_n)
    )
  }

  # Diagonal, legends and assembly -----------------------------------------
  display_var <- function(v) {
    .label_with_suffix(v, axis_transforms[[v]]$suffix, axes)
  }
  diagonal <- if (style$diagonal == "auto") "density" else style$diagonal
  diag_cells <- lapply(vars, function(v) {
    switch(diagonal,
      blank   = .build_blank_diagonal_cell(),
      name    = .build_diagonal_cell(display_var(v), text_sizes = text_sizes,
                                     family = style$base_family),
      density = .build_density_rug_cell(display_var(v), x$data[[v]],
                                        text_sizes = text_sizes,
                                        grouping = grouping)
    )
  })
  shape_legend_plot <- if (.resolve_shape_legend(style$show_shape_legend,
                                                 annotations)) {
    .build_shape_legend_plot(text_pt = text_sizes$pt$legend,
                             family = style$base_family)
  } else {
    NULL
  }
  legend_bottom <- identical(style$legend_position, "bottom")
  group_legend_plot <- if (!is.null(grouping) && !legend_bottom) {
    .build_group_legend_plot(grouping, text_pt = text_sizes$pt$legend,
                             family = style$base_family)
  } else {
    NULL
  }
  background_plot <- if (background_by == "none" || legend_bottom) {
    NULL
  } else {
    .build_background_bar(background_by, style$background_palette,
                          style$background_strength,
                          text_pt = text_sizes$pt$legend,
                          family = style$base_family)
  }
  bottom_bars <- if (legend_bottom) {
    .bottom_bar_specs(colour_by, colour_limits, palette,
                      colour_channel = style$colour_channel,
                      background_by = background_by,
                      background_palette = style$background_palette,
                      background_strength = style$background_strength)
  } else {
    list()
  }
  composite <- .assemble_matrix(
    cells_by_ij, diag_cells, vars,
    colour_by = colour_by, colour_limits = colour_limits,
    palette = palette, shape_legend_plot = shape_legend_plot,
    group_legend_plot = group_legend_plot,
    background_plot = background_plot,
    labels = style$labels, label_srt = style$label_srt,
    text_pt = text_sizes$pt, show_key = style$show_key,
    family = style$base_family,
    axes = axes, axis_transforms = axis_transforms,
    legend_position = style$legend_position,
    bottom_bars = bottom_bars, grouping = grouping
  )
  .finalize_plot(
    composite,
    title   = .display_title(display, style$glyph_style),
    caption = if (isTRUE(style$show_glossary)) {
      .build_glossary_text(
        annotations, colour_by, style$colour_channel, display,
        derivative_ci = x$settings$derivative_ci,
        background_by = background_by,
        adjusted = !is.null(x$adjust),
        partial = .partial_points_shown(x, style),
        a_in_summary = a_in_summary && display == "fit"
      )
    } else {
      NULL
    },
    text_pt = text_sizes$pt,
    family  = style$base_family
  )
}

# ---------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------

# `...` of the plot method must be empty; the error names the offenders.
.check_plot_dots <- function(..., call = rlang::caller_env()) {
  dots <- list(...)
  if (!length(dots)) return(invisible(NULL))
  nms <- names(dots) %||% rep("", length(dots))
  nms[!nzchar(nms)] <- "<unnamed>"
  cli::cli_abort(c(
    "Unknown argument{?s} {.arg {nms}}.",
    i = paste(
      "Appearance knobs belong in {.fn janusplot_style};",
      "model settings in {.fn janusplot_fit}."
    )
  ), call = call)
}

.check_style <- function(style, call = rlang::caller_env()) {
  if (!inherits(style, "janusplot_style")) {
    cli::cli_abort("{.arg style} must be a {.fn janusplot_style} object.",
                   call = call)
  }
  invisible(NULL)
}

# "edf" is accepted for one release and mapped to "nonlinearity".
.resolve_colour_by <- function(colour_by, user_env = rlang::caller_env(2L),
                               call = rlang::caller_env()) {
  if (identical(colour_by, "edf")) {
    lifecycle::deprecate_warn(
      when = "1.0.0",
      what = I('colour_by = "edf"'),
      details = paste(
        'Use colour_by = "nonlinearity" (EDF - 1);',
        '"edf" is mapped to it for one release.'
      ),
      user_env = user_env
    )
    return("nonlinearity")
  }
  rlang::arg_match(colour_by, .colour_choices(), error_call = call)
}

.annotation_choices <- function() {
  c("A", "edf", "signif", "code", "shape", "k_warn", "n", "r", "formula")
}

# A is written once per pair, so its strip fits at the 5-point floor up
# to twelve variables on a 170 mm page; from thirteen the strips of
# neighbouring cells touch, the default keeps the significance glyph
# alone and A stays in summary().
.default_annotations <- function(k) {
  if (k >= 13L) "signif" else c("A", "signif")
}

# The background and the whole-cell colour wash paint the same area.
.check_background_channel <- function(background_by, colour_channel,
                                      call = rlang::caller_env()) {
  if (background_by != "none" && identical(colour_channel, "fill")) {
    cli::cli_abort(c(
      paste("{.arg background_by} = {.val {background_by}} and",
            "{.code janusplot_style(colour_channel = \"fill\")} both paint",
            "the whole cell."),
      i = paste("Set {.code background_by = \"none\"}, or use",
                "{.arg colour_channel} = {.val border} or {.val tile}.")
    ), call = call)
  }
  invisible(NULL)
}

.check_annotations <- function(annotations, call = rlang::caller_env()) {
  if (is.null(annotations)) return(NULL)
  choices <- .annotation_choices()
  if (!is.character(annotations)) {
    cli::cli_abort(
      "{.arg annotations} must be a character vector, a subset of {.val {choices}}.",
      call = call
    )
  }
  bad <- setdiff(annotations, choices)
  if (length(bad)) {
    cli::cli_abort(c(
      "Unknown {.arg annotations} value{?s}: {.val {bad}}.",
      i = "Allowed: {.val {choices}}."
    ), call = call)
  }
  unique(annotations)
}

# A derivative view needs its order in the fit.
.check_display_available <- function(display, derivatives,
                                     call = rlang::caller_env()) {
  if (display == "fit") return(invisible(NULL))
  order <- if (display == "d1") 1L else 2L
  if (!order %in% derivatives) {
    cli::cli_abort(c(
      paste("{.arg display} = {.val {display}} needs derivative order",
            "{order}, which this fit did not compute."),
      i = "Refit with {.code janusplot_fit(..., derivatives = 1:2)}."
    ), call = call)
  }
  invisible(NULL)
}

# The group column as a factor over the rows of fit$data, with one colour
# per level, or NULL when no group is requested.
.resolve_group <- function(fit, group, style, call = rlang::caller_env()) {
  if (is.null(group)) return(NULL)
  if (!is.character(group) || length(group) != 1L || is.na(group)) {
    cli::cli_abort("{.arg group} must be a single column name or NULL.",
                   call = call)
  }
  if (!group %in% names(fit$data)) {
    categorical <- names(fit$data)[vapply(fit$data, function(col) {
      is.factor(col) || is.character(col) || is.logical(col)
    }, logical(1L))]
    cli::cli_abort(c(
      "Column {.val {group}} is not in {.code fit$data}.",
      i = if (length(categorical)) {
        "Grouping columns available: {.val {categorical}}."
      } else {
        "The data carry no factor, character or logical column."
      }
    ), call = call)
  }
  col <- fit$data[[group]]
  if (!(is.factor(col) || is.character(col) || is.logical(col))) {
    cli::cli_abort(
      "{.arg group} column {.val {group}} must be factor, character or logical.",
      call = call
    )
  }
  values <- if (is.factor(col)) droplevels(col) else factor(col)
  n_levels <- nlevels(values)
  if (n_levels > style$group_max_levels) {
    cli::cli_abort(c(
      paste("{.arg group} column {.val {group}} has {n_levels} levels;",
            "the limit is {style$group_max_levels}."),
      i = "Raise {.code janusplot_style(group_max_levels = )} or collapse the levels."
    ), call = call)
  }
  list(
    name    = group,
    values  = values,
    colours = .group_colours(style$group_palette, levels(values), call)
  )
}

# One colour per level from a grDevices palette name or a colour vector.
.group_colours <- function(group_palette, levels, call = rlang::caller_env()) {
  n <- length(levels)
  colours <- if (length(group_palette) == 1L &&
                 group_palette %in% grDevices::palette.pals()) {
    grDevices::palette.colors(palette = group_palette)
  } else {
    group_palette
  }
  n_colours <- length(colours)
  if (n_colours < n) {
    cli::cli_abort(c(
      paste("{.arg group} has {n} levels but {.code style$group_palette}",
            "supplies {n_colours} colour{?s}."),
      i = paste("Give {.code janusplot_style(group_palette = )} a larger",
                "palette or a longer colour vector.")
    ), call = call)
  }
  stats::setNames(unname(colours[seq_len(n)]), levels)
}

# ---------------------------------------------------------------
# Cells and their rows
# ---------------------------------------------------------------

# One row per directed cell: the pair index, the direction and the
# position key "r_c" in the drawn variable order. Every cell is
# row ~ s(column): the `xy` face, var_i ~ s(var_j), sits at (row of
# var_i, column of var_j) and the `yx` face at the mirror.
.cell_index <- function(pairs, vars) {
  rows <- lapply(pairs, function(p) {
    r_i <- match(p$var_i, vars)
    c_j <- match(p$var_j, vars)
    data.frame(
      direction = c("xy", "yx"),
      key = c(sprintf("%d_%d", r_i, c_j), sprintf("%d_%d", c_j, r_i)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$pair <- rep(seq_along(pairs), each = 2L)
  rownames(out) <- NULL
  out[, c("pair", "direction", "key")]
}

# TRUE for the keys "r_c" of cells below the diagonal (r > c).
.cell_in_lower <- function(keys) {
  rc <- do.call(rbind, lapply(strsplit(keys, "_", fixed = TRUE), as.integer))
  rc[, 1L] > rc[, 2L]
}

# Row indices of fit$data complete on x, y and the adjust variables: the
# rows the cell was fitted on, so their count is the cell's n_used under
# na_action = "pairwise"; under "complete" fit$data is already listwise.
.cell_rows <- function(fit, x, y) {
  cols <- .pair_columns(fit$data, x, y, fit$adjust)
  which(stats::complete.cases(fit$data[, cols, drop = FALSE]))
}

# TRUE when the cells of `fit` draw partial residuals: the fit has
# `adjust`, the style asks for partial points, and some cell stored them
# (identity link).
.partial_points_shown <- function(fit, style) {
  if (is.null(fit$adjust) || identical(style$adjusted_points, "raw")) {
    return(FALSE)
  }
  any(vapply(fit$pairs, function(p) {
    !is.null(p$partial_yx) || !is.null(p$partial_xy)
  }, logical(1L)))
}

# The points of a cell, with the group level of each row when given. With
# `partial` (the face's partial residuals, one per fitted row) the
# vertical coordinate is the partial residual instead of the raw value.
.cell_points <- function(fit, x, y, grouping = NULL, partial = NULL) {
  rows <- .cell_rows(fit, x, y)
  y_vals <- fit$data[[y]][rows]
  if (!is.null(partial) && length(partial) == length(rows)) y_vals <- partial
  out <- data.frame(x = fit$data[[x]][rows], y = y_vals)
  if (!is.null(grouping)) out$group <- grouping$values[rows]
  out
}
