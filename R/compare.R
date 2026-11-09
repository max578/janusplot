# compare.R -- janusplot_compare(): two fits of the same variables matched
# cell by cell, typically a marginal fit against one adjusted for a
# grouping variable. The object holds the per-cell table of differences
# and both fits; print() counts the cells whose shape label changed and
# plot() draws the matrix with both curves in every cell. Nothing is
# refitted. The cell renderer here reuses the strip, theme, points and
# assembly helpers of internal-cell.R and internal-assemble.R.

#' Compare two fits of the same variables cell by cell
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Matches every directed cell of two [janusplot_fit()] objects over the
#' same variables and reports how the EDF, the asymmetry index and the
#' shape labels move from the first fit to the second. The typical use
#' puts a marginal fit against one adjusted for a grouping variable,
#' which shows how sensitive each fitted shape is to that adjustment.
#' Nothing is refitted.
#'
#' @details
#' Cells are matched by variable names, so the two fits may store their
#' variables and pairs in different orders. Differences are the second
#' fit minus the first. A shape or archetype change is `NA` when the fit
#' failed on either side, where the label is `"indeterminate"` or `NA`.
#'
#' The comparison reports sensitivity to adjustment. A changed label says
#' the fitted shape depends on the adjustment; it does not by itself say
#' why.
#'
#' @param fit_a,fit_b `janusplot_fit` objects over the same set of
#'   variables. `fit_a` is the reference (often the marginal fit), `fit_b`
#'   the comparison (often the adjusted fit).
#' @param labels Character vector of length 2 naming `fit_a` and `fit_b`
#'   in printed and plotted output; two different, non-empty strings.
#'   `c("A", "B")` by default.
#' @param x A `janusplot_compare` object.
#' @param ... Ignored by the `print()` method.
#'
#' @returns A list of class `janusplot_compare` with components:
#' \describe{
#'   \item{`table`}{Data frame with one row per directed cell, in the row
#'     order of `summary(fit_a)`: `var_x` (predictor), `var_y`
#'     (response), `position` (`"upper"` or `"lower"` in `fit_a`),
#'     `n_used_a`, `n_used_b`, `edf_a`, `edf_b`, `delta_edf`, `A_a`,
#'     `A_b`, `delta_A` (the pair's asymmetry index), `shape_a`,
#'     `shape_b`, `shape_changed` (logical), `archetype_a`,
#'     `archetype_b`, `archetype_changed` (logical), `trend_a`, `trend_b`
#'     and `trend_changed` (logical). The trend is `"increasing"` or
#'     `"decreasing"` for a monotone shape (by the sign of the
#'     monotonicity index), otherwise `"non_monotone"` or
#'     `"degenerate"`.}
#'   \item{`fit_a`, `fit_b`}{The two fits as given.}
#'   \item{`labels`}{The two labels.}
#' }
#' `print()` returns `x` invisibly.
#'
#' @family smooth-associations
#' @seealso [plot.janusplot_compare()] for the matrix with both curves,
#'   [janusplot_fit()] for the fits.
#'
#' @examples
#' set.seed(2026L)
#' g <- rep(c("g1", "g2", "g3"), each = 40L)
#' mu <- c(g1 = 0, g2 = 2, g3 = 4)[g]
#' d <- data.frame(x = mu + stats::rnorm(120L), g = factor(g))
#' d$y <- -1.5 * mu + 0.8 * (d$x - mu) + stats::rnorm(120L, sd = 0.4)
#' d$z <- sin(d$x) + stats::rnorm(120L, sd = 0.3)
#' vars <- c("x", "y", "z")
#' fit_a <- janusplot_fit(d, vars, engine = "gam", derivatives = integer())
#' fit_b <- janusplot_fit(d, vars, adjust = ~ g, engine = "gam",
#'                        derivatives = integer())
#' cmp <- janusplot_compare(fit_a, fit_b,
#'                          labels = c("marginal", "group-adjusted"))
#' cmp
#' cmp$table[, c("var_x", "var_y", "edf_a", "edf_b", "shape_changed")]
#' @export
janusplot_compare <- function(
  fit_a,
  fit_b,
  labels = c("A", "B")
) {
  .check_compare_fit(fit_a, "fit_a")
  .check_compare_fit(fit_b, "fit_b")
  .check_compare_labels(labels)
  .check_compare_vars(fit_a$vars, fit_b$vars)

  out <- list(
    table  = .compare_table(summary(fit_a), summary(fit_b)),
    fit_a  = fit_a,
    fit_b  = fit_b,
    labels = labels
  )
  structure(out, class = c("janusplot_compare", "list"))
}

# ---------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------

.check_compare_fit <- function(fit, arg_name, call = rlang::caller_env()) {
  if (!inherits(fit, "janusplot_fit")) {
    cli::cli_abort(
      "{.arg {arg_name}} must be a {.fn janusplot_fit} object.",
      call = call
    )
  }
  invisible(NULL)
}

.check_compare_labels <- function(labels, call = rlang::caller_env()) {
  ok <- is.character(labels) && length(labels) == 2L &&
    !anyNA(labels) && all(nzchar(labels))
  if (!ok) {
    cli::cli_abort(
      "{.arg labels} must be a character vector of two non-empty strings.",
      call = call
    )
  }
  if (identical(labels[1L], labels[2L])) {
    cli::cli_abort(
      "{.arg labels} must name the two fits differently, not {.val {labels[1L]}} twice.",
      call = call
    )
  }
  invisible(NULL)
}

# The two fits must cover the same variables; order may differ.
.check_compare_vars <- function(vars_a, vars_b, call = rlang::caller_env()) {
  only_a <- setdiff(vars_a, vars_b)
  only_b <- setdiff(vars_b, vars_a)
  if (!length(only_a) && !length(only_b)) return(invisible(NULL))
  cli::cli_abort(c(
    "{.arg fit_a} and {.arg fit_b} must cover the same variables.",
    i = if (length(only_a)) "Only in {.arg fit_a}: {.val {only_a}}.",
    i = if (length(only_b)) "Only in {.arg fit_b}: {.val {only_b}}."
  ), call = call)
}

# ---------------------------------------------------------------
# The per-cell table of differences
# ---------------------------------------------------------------

# One row per directed cell of `tab_a` (summary(fit_a)), matched by
# (var_x, var_y) to the same cell of `tab_b`; differences are B minus A.
.compare_table <- function(tab_a, tab_b) {
  key_a <- paste(tab_a$var_x, tab_a$var_y, sep = "\r")
  key_b <- paste(tab_b$var_x, tab_b$var_y, sep = "\r")
  b <- tab_b[match(key_a, key_b), , drop = FALSE]
  # A failed fit carries the label "indeterminate"; its change is unknown.
  failed <- !is.na(tab_a$error) | !is.na(b$error)
  changed <- function(a, b) ifelse(failed, NA, a != b)
  out <- data.frame(
    var_x             = tab_a$var_x,
    var_y             = tab_a$var_y,
    position          = tab_a$position,
    n_used_a          = tab_a$n_used,
    n_used_b          = b$n_used,
    edf_a             = tab_a$edf,
    edf_b             = b$edf,
    delta_edf         = b$edf - tab_a$edf,
    A_a               = tab_a$asymmetry_index,
    A_b               = b$asymmetry_index,
    delta_A           = b$asymmetry_index - tab_a$asymmetry_index,
    shape_a           = tab_a$shape_category,
    shape_b           = b$shape_category,
    shape_changed     = changed(tab_a$shape_category, b$shape_category),
    archetype_a       = tab_a$shape_archetype,
    archetype_b       = b$shape_archetype,
    archetype_changed = changed(tab_a$shape_archetype, b$shape_archetype),
    trend_a           = .shape_trend(tab_a),
    trend_b           = .shape_trend(b),
    trend_changed     = changed(.shape_trend(tab_a), .shape_trend(b)),
    stringsAsFactors  = FALSE
  )
  rownames(out) <- NULL
  out
}

# The coarse trend of a cell: a monotone shape rises or falls by the sign
# of its monotonicity index; any other shape keeps its monotonic tier.
.shape_trend <- function(tab) {
  m <- tab$monotonicity_index
  ifelse(tab$shape_monotonic %in% "monotone",
         ifelse(m >= 0, "increasing", "decreasing"),
         tab$shape_monotonic)
}

# ---------------------------------------------------------------
# print()
# ---------------------------------------------------------------

#' @rdname janusplot_compare
#' @export
print.janusplot_compare <- function(x, ...) {
  tab <- x$table
  lab <- x$labels

  # Header -----------------------------------------------------------------
  vars <- x$fit_a$vars
  k_n <- length(vars)
  shown <- if (k_n > 8L) c(vars[seq_len(8L)], "...") else vars
  cli::cat_line(sprintf("janusplot comparison: %s against %s",
                        lab[1L], lab[2L]))
  n_pairs <- length(x$fit_a$pairs)
  cli::cat_line(sprintf("%d variables (%s), %d %s, %d directed cells",
                        k_n, paste(shown, collapse = ", "), n_pairs,
                        if (n_pairs == 1L) "pair" else "pairs", nrow(tab)))
  cli::cat_line(sprintf("adjust: %s = %s, %s = %s",
                        lab[1L], .format_adjust(x$fit_a$adjust),
                        lab[2L], .format_adjust(x$fit_b$adjust)))

  # Counts over directed cells and pairs ---------------------------------
  shape_changed <- which(tab$shape_changed)
  pair_key <- ifelse(tab$var_x < tab$var_y,
                     paste(tab$var_x, tab$var_y, sep = "\r"),
                     paste(tab$var_y, tab$var_x, sep = "\r"))
  n_pairs <- length(unique(pair_key))
  n_pairs_changed <- length(unique(pair_key[shape_changed]))
  n_archetype <- sum(tab$archetype_changed, na.rm = TRUE)
  n_trend <- sum(tab$trend_changed, na.rm = TRUE)
  cli::cat_line(sprintf(
    paste("From %s to %s, the shape changed in %d of %d directed cells",
          "(%d of %d pairs), the archetype in %d and the trend in %d."),
    lab[1L], lab[2L], length(shape_changed), nrow(tab),
    n_pairs_changed, n_pairs, n_archetype, n_trend
  ))
  n_missing <- sum(is.na(tab$shape_changed))
  if (n_missing > 0L) {
    cli::cat_line(sprintf(
      "%d directed cell%s with a failed fit on one side %s not compared.",
      n_missing, if (n_missing == 1L) "" else "s",
      if (n_missing == 1L) "is" else "are"
    ))
  }

  # Changed cells ----------------------------------------------------------
  if (length(shape_changed)) {
    cli::cat_line("Cells whose shape changed:")
    for (line in .format_compare_rows(tab[shape_changed, , drop = FALSE])) {
      cli::cat_line("  ", line)
    }
  } else {
    cli::cat_line("No shape label changed.")
  }

  # Settings other than adjust ---------------------------------------------
  differ <- .compare_settings_differ(x$fit_a$settings, x$fit_b$settings)
  if (length(differ)) {
    cli::cat_line(sprintf(
      paste("The fits also differ in %s, so a changed label may come from",
            "%s as well as from the adjustment."),
      paste(differ, collapse = ", "),
      if (length(differ) == 1L) "that setting" else "those settings"
    ))
  }
  invisible(x)
}

.format_adjust <- function(adjust) {
  if (is.null(adjust)) return("none")
  paste(deparse(adjust, width.cutoff = 500L), collapse = " ")
}

# One line per changed cell: the cell, then shape, EDF and A, A to B.
.format_compare_rows <- function(rows) {
  sprintf(
    "%s ~ s(%s): shape %s -> %s, EDF %.2f -> %.2f, A %.2f -> %.2f",
    rows$var_y, rows$var_x, rows$shape_a, rows$shape_b,
    rows$edf_a, rows$edf_b, rows$A_a, rows$A_b
  )
}

# Names of the fit settings, other than adjust, that differ between the
# two fits and can change a shape label on their own.
.compare_settings_differ <- function(settings_a, settings_b) {
  checked <- c("engine", "method", "k", "bs", "n_grid", "shape_cutoffs",
               "family", "link", "discrete", "nthreads")
  same <- vapply(checked, function(nm) {
    identical(settings_a[[nm]], settings_b[[nm]])
  }, logical(1L))
  checked[!same]
}

# ---------------------------------------------------------------
# plot()
# ---------------------------------------------------------------

#' Draw two fits of the same variables in one matrix
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Draws the matrix of a [janusplot_compare()] object with both fitted
#' curves in every off-diagonal cell: the first fit as a grey dashed
#' curve, the second as the solid curve with its band over the second
#' fit's raw points. A red border marks the cells whose trend changed
#' (rising, falling or non-monotone), and the strip above each cell gives the EDF of both fits.
#' Nothing is refitted.
#'
#' @details
#' The layout follows [plot.janusplot_fit()]: every cell `[r, c]` shows
#' `vars[r] ~ s(vars[c])`, over the variables of the second fit, with the
#' key of that convention in the top-left corner, or under the matrix with
#' `janusplot_style(legend_position = "bottom")`. There is no colour scale
#' and no background. The caption keys the two curves by `x$labels` when
#' `style$show_glossary` is `TRUE`.
#'
#' @param x A `janusplot_compare` object.
#' @param group Name of a factor, character or logical column of
#'   `x$fit_b$data` whose levels colour the raw points, with one legend
#'   below the matrix, or `NULL` (the default). Drawing only. The column
#'   must exist in `x$fit_b$data` and have at most
#'   `style$group_max_levels` levels.
#' @param order Order of the variables in the matrix: `"original"` (the
#'   default, the order of `x$fit_b$vars`), `"hclust"` (hierarchical
#'   clustering of absolute Pearson correlations in `x$fit_b$data`) or
#'   `"alphabetical"`.
#' @param style A [janusplot_style()] object. The second fit's curve and
#'   band take `curve_colour` and `band_alpha`; the points, density
#'   threshold, labels, diagonal, glyph style and compact tiers apply as
#'   in [plot.janusplot_fit()].
#' @param ... Must be empty. An unknown name is an error.
#'
#' @returns A [patchwork][patchwork::patchwork-package] object, which is a
#'   ggplot: the matrix with its border labels, the group legend when
#'   `group` is given, the shape-categories legend when
#'   `style$show_shape_legend` is `TRUE` (`"auto"` leaves it off: the
#'   compare cells carry no shape code), a title naming the two fits and
#'   the key caption when `style$show_glossary` is `TRUE`.
#'
#' @family smooth-associations
#' @seealso [janusplot_compare()] for the object, [plot.janusplot_fit()]
#'   for the matrix of one fit.
#'
#' @examples
#' set.seed(2026L)
#' g <- rep(c("g1", "g2", "g3"), each = 40L)
#' mu <- c(g1 = 0, g2 = 2, g3 = 4)[g]
#' d <- data.frame(x = mu + stats::rnorm(120L), g = factor(g))
#' d$y <- -1.5 * mu + 0.8 * (d$x - mu) + stats::rnorm(120L, sd = 0.4)
#' d$z <- sin(d$x) + stats::rnorm(120L, sd = 0.3)
#' vars <- c("x", "y", "z")
#' fit_a <- janusplot_fit(d, vars, engine = "gam", derivatives = integer())
#' fit_b <- janusplot_fit(d, vars, adjust = ~ g, engine = "gam",
#'                        derivatives = integer())
#' cmp <- janusplot_compare(fit_a, fit_b,
#'                          labels = c("marginal", "group-adjusted"))
#' plot(cmp, group = "g")
#' @method plot janusplot_compare
#' @export
plot.janusplot_compare <- function(
  x,
  group = NULL,
  order = c("original", "hclust", "alphabetical"),
  style = janusplot_style(),
  ...
) {
  .check_plot_dots(...)
  .check_style(style)
  order <- rlang::arg_match(order)
  fit_a <- x$fit_a
  fit_b <- x$fit_b
  grouping <- .resolve_group(fit_b, group, style)

  # Variable order and matrix-wide settings --------------------------------
  vars <- switch(order,
    original     = fit_b$vars,
    hclust       = .reorder_hclust(fit_b$data, fit_b$vars),
    alphabetical = sort(fit_b$vars)
  )
  k_n <- length(vars)
  tier <- .compact_tier(
    k_n, compact = style$compact,
    compact_threshold = style$compact_threshold,
    compact_levels = style$compact_levels
  )
  text_sizes <- .cell_text_sizes(k_n, style$text_size)
  border_lw  <- .border_linewidth(k_n, style$border_width)

  # Directed cells: B placed by position, A matched by variable names ------
  cell_index <- .cell_index(fit_b$pairs, vars)
  faces_b <- Map(function(i, d) .pair_face(fit_b$pairs[[i]], d),
                 cell_index$pair, cell_index$direction)
  lookup_a <- .compare_face_lookup(fit_a$pairs)
  key_a <- paste(lookup_a$var_x, lookup_a$var_y, sep = "\r")
  key_tab <- paste(x$table$var_x, x$table$var_y, sep = "\r")

  cells_by_ij <- vector("list", nrow(cell_index))
  names(cells_by_ij) <- cell_index$key
  for (idx in seq_len(nrow(cell_index))) {
    face_b <- faces_b[[idx]]
    key <- paste(face_b$var_x, face_b$var_y, sep = "\r")
    row_a <- match(key, key_a)
    cells_by_ij[[idx]] <- .render_compare_cell(
      face_a        = .pair_face(fit_a$pairs[[lookup_a$pair[row_a]]],
                                 lookup_a$direction[row_a]),
      face_b        = face_b,
      points        = .cell_points(fit_b, face_b$var_x, face_b$var_y,
                                   grouping, .face_partial(face_b, style)),
      trend_changed = x$table$trend_changed[match(key, key_tab)],
      style         = style,
      text_sizes    = text_sizes,
      tier          = tier,
      group_colours = grouping$colours,
      border_linewidth = border_lw,
      point_scale   = .matrix_point_scale(k_n)
    )
  }

  # Diagonal, legends and assembly -----------------------------------------
  diagonal <- if (style$diagonal == "auto") "density" else style$diagonal
  diag_cells <- lapply(vars, function(v) {
    switch(diagonal,
      blank   = .build_blank_diagonal_cell(),
      name    = .build_diagonal_cell(v, text_sizes = text_sizes,
                                     family = style$base_family),
      density = .build_density_rug_cell(v, fit_b$data[[v]],
                                        text_sizes = text_sizes,
                                        grouping = grouping)
    )
  })
  shape_legend_plot <- if (.resolve_shape_legend(style$show_shape_legend,
                                                 character())) {
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
  composite <- .assemble_matrix(
    cells_by_ij, diag_cells, vars,
    colour_by = "none", colour_limits = c(NA_real_, NA_real_),
    palette = NULL, shape_legend_plot = shape_legend_plot,
    group_legend_plot = group_legend_plot,
    labels = style$labels, label_srt = style$label_srt,
    text_pt = text_sizes$pt, show_key = style$show_key,
    family = style$base_family,
    legend_position = style$legend_position, grouping = grouping
  )
  .finalize_plot(
    composite,
    title   = sprintf("Fitted curves: %s against %s",
                      x$labels[1L], x$labels[2L]),
    caption = if (isTRUE(style$show_glossary)) {
      .compare_caption(x$labels, style,
                       partial = .partial_points_shown(x$fit_b, style))
    } else {
      NULL
    },
    text_pt = text_sizes$pt,
    family  = style$base_family
  )
}

# Pair index and direction of every directed cell of a fit, keyed by its
# predictor and response.
.compare_face_lookup <- function(pairs) {
  data.frame(
    pair      = rep(seq_along(pairs), each = 2L),
    direction = rep(c("yx", "xy"), times = length(pairs)),
    var_x     = as.vector(rbind(
      vapply(pairs, function(p) p$var_i, character(1L)),
      vapply(pairs, function(p) p$var_j, character(1L))
    )),
    var_y     = as.vector(rbind(
      vapply(pairs, function(p) p$var_j, character(1L)),
      vapply(pairs, function(p) p$var_i, character(1L))
    )),
    stringsAsFactors = FALSE
  )
}

# The arrow between the two values in the strip and the caption.
.compare_arrow <- function(glyph_style = "ascii") {
  if (identical(glyph_style, "unicode")) intToUtf8(8594L) else "->"
}

# The strip of a compare cell, "EDF 1.2 -> 2.8" ("E 1.2 -> 2.8" compact).
.compare_strip_text <- function(face_a, face_b, glyph_style = "ascii",
                                compact = FALSE) {
  sprintf(if (compact) "E %s %s %s" else "EDF %s %s %s",
          .format_edf(face_a$edf), .compare_arrow(glyph_style),
          .format_edf(face_b$edf))
}

.format_edf <- function(edf) {
  if (is.null(edf) || is.na(edf)) "NA" else sprintf("%.1f", edf)
}

# The caption keying the two curves and the red border.
.compare_caption <- function(labels, style, partial = FALSE) {
  solid <- if (identical(style$curve_colour, janusplot_style()$curve_colour)) {
    "solid blue"
  } else {
    "solid"
  }
  if (isTRUE(style$show_ci)) solid <- paste(solid, "with band")
  paste(
    sprintf("grey dashed: %s; %s: %s", labels[1L], solid, labels[2L]),
    "red border: trend changed (rising, falling or non-monotone)",
    if (partial) {
      sprintf("points: %s, partial residuals (adjustment replaced by its average)",
              labels[2L])
    } else {
      sprintf("points: %s", labels[2L])
    },
    sprintf("EDF = effective degrees of freedom of the smooth, %s %s %s",
            labels[1L], .compare_arrow(style$glyph_style), labels[2L]),
    sep = "\n"
  )
}

# ---------------------------------------------------------------
# Compare cell. One ggplot for one directed cell: B's points, B's band,
# A's grey dashed curve, B's solid curve, the EDF strip and a red border
# when the trend changed. Compact tiers drop detail as in
# .render_cell().
# ---------------------------------------------------------------

.render_compare_cell <- function(
  face_a,
  face_b,
  points,
  trend_changed,
  style,
  text_sizes,
  tier = 0L,
  group_colours = NULL,
  border_linewidth = 1.2,
  point_scale = NULL
) {
  tier <- as.integer(tier)
  show_data   <- isTRUE(style$show_data) && tier < 1L
  show_ci     <- isTRUE(style$show_ci) && tier < 2L
  show_spline <- tier < 3L
  changed <- isTRUE(trend_changed)

  # Panel, strip and border ------------------------------------------------
  strip <- if (tier < 3L) {
    .compare_strip_text(face_a, face_b, style$glyph_style,
                        compact = tier >= 1L)
  } else {
    NULL
  }
  p <- ggplot2::ggplot() +
    .cell_theme(
      strip_pt = text_sizes$pt$strip,
      border_colour = if (changed) "#b2182b" else "grey55",
      border_linewidth = if (changed) border_linewidth else 0.35,
      family = style$base_family
    ) +
    ggplot2::labs(subtitle = strip)

  # Empty cell: neither fit has a curve -----------------------------------
  has_a <- nrow(face_a$pred) > 0L
  has_b <- nrow(face_b$pred) > 0L
  if (!has_a && !has_b) {
    label <- if (!is.na(face_b$error)) "no fit" else "n < 5"
    return(.empty_cell_text(p, label, text_sizes, style$base_family))
  }

  # Data, B's band, A's curve, B's curve -----------------------------------
  if (show_data && nrow(points) > 0L) {
    p <- p + .cell_points_layer(points, style, group_colours,
                                n_used = face_b$n_used,
                                point_scale = point_scale)
  }
  if (show_ci && has_b) {
    p <- p + ggplot2::geom_ribbon(
      data = face_b$pred,
      ggplot2::aes(x = .data$x, ymin = .data$lo, ymax = .data$hi),
      fill = style$curve_colour, alpha = style$band_alpha,
      inherit.aes = FALSE
    )
  }
  if (show_spline && has_a) {
    p <- p + ggplot2::geom_line(
      data = face_a$pred,
      ggplot2::aes(x = .data$x, y = .data$fit),
      colour = "grey45", linetype = "dashed", linewidth = 0.6,
      inherit.aes = FALSE
    )
  }
  if (show_spline && has_b) {
    p <- p + ggplot2::geom_line(
      data = face_b$pred,
      ggplot2::aes(x = .data$x, y = .data$fit),
      colour = style$curve_colour,
      linewidth = style$curve_width / ggplot2::.pt,
      inherit.aes = FALSE
    )
  }
  if (!show_spline) {
    # Tier 3: B's shape glyph in the cell centre stands for the curves.
    glyph <- .shape_glyph(face_b$shape, style = style$glyph_style)
    if (!is.na(glyph) && nzchar(glyph) && !is.na(text_sizes$shape)) {
      p <- p + ggplot2::annotate(
        "text", x = 0.5, y = 0.5,
        label = glyph, size = text_sizes$shape * 1.2,
        colour = "grey20", fontface = "bold", family = style$base_family
      ) + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
    }
  }
  p
}
