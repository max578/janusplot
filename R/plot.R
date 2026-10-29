# plot.R -- The plot() method of a janusplot_fit: the matrix view. Every
# number drawn comes from the fit object; nothing is refitted. The cell
# renderer, the strip and the colour scales live in internal-cell.R, the
# patchwork assembly in internal-assemble.R, the style object in style.R.

#' Draw the matrix of a janusplot fit
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Draws the asymmetric matrix of a [janusplot_fit()] object: one cell per
#' directed pair, the fitted curve with its band over the raw points, the
#' variable names along the top and left borders. Nothing is refitted;
#' every number on the plot is in the object.
#'
#' @details
#' Cell `[i, j]` with `i != j` shows `vars[j] ~ s(vars[i])` for `i < j` and
#' `vars[i] ~ s(vars[j])` for `i > j`, so the column variable is the
#' response in the upper triangle and the row variable in the lower one;
#' the two triangles differ by design. The `colour_by` value is painted
#' on the border, a corner tile or the whole cell per
#' `style$colour_channel`, with one colour bar per matrix. A strip above
#' each cell carries the `annotations`.
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
#' @param annotations Character vector, a subset of `c("A", "edf",
#'   "signif", "code", "shape", "k_warn", "n")`, written in the strip of
#'   every cell (or in its corners under `janusplot_style(annotation_position
#'   = "corners")`): the asymmetry index, the EDF, the significance glyph
#'   of the smooth F-test (`***` p < .001, `**` p < .01, `*` p < .05,
#'   `.` p < .1, from the adjusted p-value when the fit has `p_adjust`
#'   other than `"none"`), the two-letter shape code, the shape glyph, a
#'   warning sign on cells flagged by the k-check or capped at the distinct
#'   predictor count, and the rows used. Default `c("A", "signif")`.
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
#' @param focus_threshold A quantile string such as `"q90"` (the default,
#'   taken over the off-diagonal cells) or a single numeric cutoff.
#'   Ignored when `focus_by` is `NA`.
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
#'   ggplot: the matrix with its border labels, the colour bar when
#'   `colour_by` is not `"none"`, the group legend when `group` is given,
#'   the shape-categories legend when `style$show_shape_legend` is `TRUE`,
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
  annotations = c("A", "signif"),
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
  colour_by   <- .resolve_colour_by(colour_by, user_env = rlang::caller_env())
  annotations <- .check_annotations(annotations)
  order       <- rlang::arg_match(order)
  display     <- rlang::arg_match(display)
  axes        <- rlang::arg_match(axes)
  .check_display_available(display, x$settings$derivatives)
  focus_by    <- .check_focus_by(focus_by)
  grouping    <- .resolve_group(x, group, style)

  # Variable order and matrix-wide settings --------------------------------
  vars <- switch(order,
    original     = x$vars,
    hclust       = .reorder_hclust(x$data, x$vars),
    alphabetical = sort(x$vars)
  )
  k_n <- length(vars)
  tier <- .compact_tier(
    k_n, compact = style$compact,
    compact_threshold = style$compact_threshold,
    compact_levels = style$compact_levels
  )
  text_sizes <- .cell_text_sizes(
    k_n,
    text_scale_diag     = style$text_scale_diag,
    text_scale_off_diag = style$text_scale_off_diag
  )
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

  cells_by_ij <- vector("list", nrow(cell_index))
  names(cells_by_ij) <- cell_index$key
  for (idx in seq_len(nrow(cell_index))) {
    face <- faces[[idx]]
    cells_by_ij[[idx]] <- .render_cell(
      pair          = x$pairs[[cell_index$pair[idx]]],
      direction     = cell_index$direction[idx],
      points        = .cell_points(x, face$var_x, face$var_y, grouping),
      style         = style,
      text_sizes    = text_sizes,
      annotations   = annotations,
      display       = display,
      p_adjust      = x$settings$p_adjust,
      colour        = colour_hex[[idx]],
      tier          = tier,
      is_focused    = isTRUE(focus_mask[[idx]]),
      group_colours = grouping$colours,
      x_transform   = axis_transforms[[face$var_x]],
      y_transform   = axis_transforms[[face$var_y]]
    )
  }

  # Diagonal, legends and assembly -----------------------------------------
  display_var <- function(v) {
    .label_with_suffix(v, axis_transforms[[v]]$suffix, axes)
  }
  diagonal <- if (style$diagonal == "auto") "blank" else style$diagonal
  diag_cells <- lapply(vars, function(v) {
    switch(diagonal,
      blank   = .build_blank_diagonal_cell(),
      name    = .build_diagonal_cell(display_var(v), text_sizes = text_sizes),
      density = .build_density_rug_cell(display_var(v), x$data[[v]],
                                        text_sizes = text_sizes)
    )
  })
  shape_legend_plot <- if (isTRUE(style$show_shape_legend)) {
    .build_shape_legend_plot()
  } else {
    NULL
  }
  group_legend_plot <- if (!is.null(grouping)) {
    .build_group_legend_plot(grouping)
  } else {
    NULL
  }
  composite <- .assemble_matrix(
    cells_by_ij, diag_cells, vars,
    colour_by = colour_by, colour_limits = colour_limits,
    palette = palette, shape_legend_plot = shape_legend_plot,
    group_legend_plot = group_legend_plot,
    labels = style$labels, label_srt = style$label_srt,
    label_cex = style$label_cex,
    axes = axes, axis_transforms = axis_transforms
  )
  .finalize_plot(
    composite,
    title   = .display_title(display, style$glyph_style),
    caption = if (isTRUE(style$show_glossary)) {
      .build_glossary_text(
        annotations, colour_by, style$colour_channel, display,
        derivative_ci = x$settings$derivative_ci
      )
    } else {
      NULL
    },
    glossary_scale = style$glossary_scale
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
  c("A", "edf", "signif", "code", "shape", "k_warn", "n")
}

.check_annotations <- function(annotations, call = rlang::caller_env()) {
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
# position key "r_c" in the drawn variable order. The upper face of a
# pair sits at (row of var_i, column of var_j), the lower at the mirror.
.cell_index <- function(pairs, vars) {
  rows <- lapply(pairs, function(p) {
    r_i <- match(p$var_i, vars)
    c_j <- match(p$var_j, vars)
    data.frame(
      direction = c("yx", "xy"),
      key = c(sprintf("%d_%d", r_i, c_j), sprintf("%d_%d", c_j, r_i)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$pair <- rep(seq_along(pairs), each = 2L)
  rownames(out) <- NULL
  out[, c("pair", "direction", "key")]
}

# Row indices of fit$data complete on x, y and the adjust variables: the
# rows the cell was fitted on, so their count is the cell's n_used under
# na_action = "pairwise"; under "complete" fit$data is already listwise.
.cell_rows <- function(fit, x, y) {
  cols <- .pair_columns(fit$data, x, y, fit$adjust)
  which(stats::complete.cases(fit$data[, cols, drop = FALSE]))
}

# The raw points of a cell, with the group level of each row when given.
.cell_points <- function(fit, x, y, grouping = NULL) {
  rows <- .cell_rows(fit, x, y)
  out <- data.frame(x = fit$data[[x]][rows], y = fit$data[[y]][rows])
  if (!is.null(grouping)) out$group <- grouping$values[rows]
  out
}
