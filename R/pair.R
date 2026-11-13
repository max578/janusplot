# pair.R -- janusplot_pair(): the two directions of one or more pairs of a
# janusplot_fit, drawn side by side with axes, or overlaid in one z-score
# panel, with many pairs stacked in columns. Every number drawn comes from
# the fit object; nothing is refitted. Panels are built by .render_cell()
# in internal-cell.R; the overlay panel is .render_overlay_cell() below.

#' Draw both directions of pairs of a janusplot fit
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Draws the two directional fits of one or more pairs of a
#' [janusplot_fit()] object. Each pair is a block of two panels side by
#' side: `y ~ s(x)` on the left and `x ~ s(y)` on the right, each with its
#' raw points, band, curve, the model formula as the title and a strip
#' giving the pair's asymmetry index `A`, the EDF of that direction, the
#' pair's Pearson correlation `r`, its significance glyph and the rows
#' used (`annotations` picks among them). Nothing is refitted.
#'
#' @details
#' The left panel of a block always shows `y ~ s(x)`, whichever order the
#' fit stored the pair in. Titles name the model in the column names of
#' the data, with the fit's `adjust` terms appended, for example
#' `Ozone ~ s(Temp) + s(Month, bs = "re")`; the curve and band are then
#' population-level, as in [janusplot_fit()]. The significance glyph is
#' read from the adjusted p-value when the fit has `p_adjust` other than
#' `"none"`. With `style$pair_background = TRUE` the panels are tinted by
#' the pair's Pearson correlation as the matrix background is, with the
#' same `background_palette` and `background_strength`; the default leaves
#' them plain, since no colour bar is drawn. A fit
#' with `adjust` draws no background: its curves are adjusted, while the
#' correlation is marginal.
#'
#' Many pairs are laid out as blocks stacked top to bottom, with the
#' stacks side by side: `nrow` is the number of blocks per stack and
#' `ncol` the number of stacks. Give one and the other follows from the
#' number of pairs; give neither and up to five pairs form one stack, more
#' pairs `ceiling(n / 5)` stacks. Fourteen pairs with `nrow = 5L` give
#' stacks of five, five and four blocks; stacks that would stay empty are
#' dropped. One pair is a single row of two
#' panels. Every panel shares the text sizes of `style$text_size`.
#'
#' `arrange = "stacked"` turns each block on its side: `y ~ s(x)` above
#' `x ~ s(y)`. Several pairs then sit side by side, with every forward
#' panel in one row and every reverse panel in the row below, which is the
#' layout for comparing the same direction across pairs. Here `ncol` is
#' the number of blocks per row and `nrow` the number of rows of blocks;
#' give neither and up to five pairs form one row.
#'
#' `display = "both"` draws one panel per pair in the z-score plane of the
#' pair's rows: `x` standardised on the horizontal axis and `y` on the
#' vertical. `y ~ s(x)` is drawn in `style$curve_colour` and `x ~ s(y)` in
#' orange, with its axes swapped into the same plane, so the two curves
#' can be compared directly. One key below the panels names each colour:
#' by its formula for one pair, as vertical on horizontal and horizontal
#' on vertical for several. `style$identity_line = TRUE` adds the line
#' `y = x`, which in this plane is the standard-deviation line: when both
#' curves are flatter than it along their own predictor axis, each
#' variable regresses towards the mean of the other. The overlay draws the
#' observed points, also under `adjust`, because the partial residuals of
#' the two directions differ.
#'
#' Under `adjust` with the identity link, the side-by-side panels draw
#' partial residuals (see `adjusted_points` in [janusplot_style()]).
#'
#' Points are drawn in grey, coloured by `group` with one legend below the
#' panels, or as a light grey binned density when the pair has more rows
#' than `style$density_threshold` and no `group` is given.
#'
#' @param fit A `janusplot_fit` object from [janusplot_fit()].
#' @param x Character vector of the predictors of the left panels, each
#'   one of `fit$vars`; or a data frame or character matrix with two
#'   columns, predictor then response, one row per pair, with `y` missing.
#' @param y Character vector of the responses of the left panels, the same
#'   length as `x`, element `i` paired with `x[i]` and different from it.
#' @param display What the panels show: `"fit"` (the default) the fitted
#'   curves over the data, `"d1"` or `"d2"` the first or second
#'   derivative of each smooth, which need that order in
#'   `fit$settings$derivatives`, and `"both"` the two curves overlaid in
#'   one z-score panel.
#' @param group Name of a factor, character or logical column of
#'   `fit$data` whose levels colour the raw points, with a legend below
#'   the panels, or `NULL` (the default). Drawing only; the column never
#'   enters the model.
#' @param annotations Character vector choosing what the strip of each
#'   panel shows under `display = "fit"`, a subset of the `annotations` of
#'   [plot.janusplot_fit()]. `NULL` (the default) is `c("A", "edf", "r",
#'   "signif", "n")`; `character()` writes no strip. The derivative and
#'   overlay displays keep their own strips.
#' @param arrange How the two panels of a pair sit: `"beside"` (the
#'   default) puts `y ~ s(x)` left of `x ~ s(y)`, `"stacked"` puts it
#'   above; see Details. The overlay of `display = "both"` has one panel
#'   per pair and ignores it.
#' @param nrow,ncol Number of pair blocks per stack and number of stacks,
#'   or `NULL` (the default) to derive them as described in Details. When
#'   both are given, `nrow * ncol` must cover every pair.
#' @param style A [janusplot_style()] object holding every appearance
#'   setting.
#'
#' @returns A [patchwork][patchwork::patchwork-package] object, which is a
#'   ggplot: the blocks of panels in their stacks, the key of the overlay
#'   colours for `display = "both"` and the group legend underneath when
#'   `group` is given.
#'
#' @family smooth-associations
#' @seealso [janusplot_fit()] for the object, [plot.janusplot_fit()] for
#'   the matrix, [janusplot_direction()] for the residual-independence
#'   test of a pair.
#'
#' @examples
#' fit <- janusplot_fit(airquality[, c("Ozone", "Temp", "Wind")],
#'                      engine = "gam")
#' janusplot_pair(fit, "Temp", "Ozone")
#'
#' # Several pairs at once take vectors of x and y, or a two-column data
#' # frame; vignette("janusplot") shows one such call and display = "both".
#' @export
janusplot_pair <- function(
  fit,
  x,
  y,
  display = c("fit", "d1", "d2", "both"),
  group = NULL,
  annotations = NULL,
  arrange = c("beside", "stacked"),
  nrow = NULL,
  ncol = NULL,
  style = janusplot_style()
) {
  .check_fit_object(fit)
  pairs <- .resolve_pairs(fit, x, if (missing(y)) NULL else y)
  display <- rlang::arg_match(display)
  arrange <- rlang::arg_match(arrange)
  annotations <- .check_annotations(annotations) %||%
    c("A", "edf", "r", "signif", "n")
  .check_style(style)
  grouping <- .resolve_group(fit, group, style)
  if (display %in% c("d1", "d2")) {
    .check_display_available(display, fit$settings$derivatives)
  }
  stacked <- arrange == "stacked" && display != "both"
  stacks <- .pair_stack_layout(nrow(pairs), nrow, ncol, by_row = stacked)

  # Shared sizes and legends -----------------------------------------------
  # Text scales with the panels across the page as the matrix text does
  # with its columns; titles wrap after "~" once there are more than two.
  across <- stacks$ncol * (if (display == "both" || stacked) 1L else 2L)
  text_sizes <- .cell_text_sizes(max(3L, across), style$text_size)
  # Titles and strips also wrap when the longest model formula would run
  # into the neighbouring panel at two panels across.
  longest <- max(nchar(c(.pair_formula(pairs$y, pairs$x, fit$adjust),
                         .pair_formula(pairs$x, pairs$y, fit$adjust))))
  # A stacked block is drawn for a column a third of the page wide, as its
  # text sizes are, so its titles wrap sooner.
  wrap_titles <- across > 2L || longest > (if (stacked) 22L else 32L)
  family <- style$base_family
  group_legend <- if (is.null(grouping)) {
    NULL
  } else {
    .build_group_legend_plot(grouping, text_pt = text_sizes$pt$legend,
                             family = family)
  }
  overlay_key <- NULL
  if (display == "both") {
    labels <- if (nrow(pairs) == 1L) {
      c(.pair_formula(pairs$y, pairs$x, NULL),
        .pair_formula(pairs$x, pairs$y, NULL))
    } else {
      c("vertical ~ s(horizontal)", "horizontal ~ s(vertical)")
    }
    overlay_key <- .overlay_key_plot(
      labels, c(style$curve_colour, .overlay_reverse_colour()),
      text_pt = text_sizes$pt$legend, family = family
    )
  }

  # One block per pair -----------------------------------------------------
  blocks <- lapply(seq_len(nrow(pairs)), function(i) {
    .pair_block(fit, pairs$x[i], pairs$y[i], display, grouping, style,
                text_sizes, wrap_titles, annotations)
  })
  body <- .stack_blocks(blocks, stacks, stacked)

  # Legends below ----------------------------------------------------------
  rows <- list(body, overlay_key, group_legend)
  # A legend sits below the empty panel of its plot, so these heights are
  # the gap between the panels and each legend.
  heights <- list(grid::unit(1, "null"), grid::unit(4, "pt"),
                  grid::unit(4, "pt"))
  keep <- !vapply(rows, is.null, logical(1L))
  if (sum(keep) == 1L) return(body)
  # `nrow`, not `ncol = 1`: patchwork's `/` appends into a one-column
  # stack, so `pair / pair` would hit this stack's fixed row heights.
  patchwork::wrap_plots(
    rows[keep], nrow = sum(keep),
    heights = do.call(grid::unit.c, heights[keep])
  )
}

# ---------------------------------------------------------------
# Pairs, layout and blocks
# ---------------------------------------------------------------

.check_fit_object <- function(fit, call = rlang::caller_env()) {
  if (!inherits(fit, "janusplot_fit")) {
    cli::cli_abort(
      "{.arg fit} must be a {.cls janusplot_fit} object from {.fn janusplot_fit}.",
      call = call
    )
  }
  invisible(NULL)
}

# The pairs to draw as a data frame with character columns x and y, from
# two equal-length vectors or a two-column data frame or matrix in `x`.
# The errors name every pair with an unknown variable, every pair of a
# variable with itself and every pair given twice in either order.
.resolve_pairs <- function(fit, x, y = NULL, call = rlang::caller_env()) {
  if (is.null(y)) {
    if (!(is.data.frame(x) || is.matrix(x)) || NCOL(x) != 2L) {
      cli::cli_abort(c(
        "{.arg y} is missing, so {.arg x} must be a data frame or matrix with two columns.",
        i = "Give the predictors in {.arg x} and the responses in {.arg y} otherwise."
      ), call = call)
    }
    cols <- if (is.data.frame(x)) list(x[[1L]], x[[2L]]) else list(x[, 1L], x[, 2L])
    cols <- lapply(cols, function(v) if (is.factor(v)) as.character(v) else v)
    x <- cols[[1L]]
    y <- cols[[2L]]
  }
  for (nm in c("x", "y")) {
    value <- if (identical(nm, "x")) x else y
    if (!is.character(value) || !length(value) || anyNA(value)) {
      cli::cli_abort(
        "{.arg {nm}} must give variable names: a character vector without NA.",
        call = call
      )
    }
  }
  if (length(x) != length(y)) {
    cli::cli_abort(c(
      "{.arg x} and {.arg y} must have the same length.",
      i = "{.arg x} has {length(x)} name{?s}, {.arg y} has {length(y)}."
    ), call = call)
  }
  label <- sprintf("%s ~ %s", y, x) # nolint: object_usage_linter.

  unknown <- !(x %in% fit$vars & y %in% fit$vars)
  if (any(unknown)) {
    cli::cli_abort(c(
      "Pair{?s} with a variable not fitted in {.arg fit}: {.val {label[unknown]}}.",
      i = "Fitted variables: {.val {fit$vars}}."
    ), call = call)
  }
  same <- x == y
  if (any(same)) {
    cli::cli_abort(
      "Pair{?s} of a variable with itself: {.val {label[same]}}.",
      call = call
    )
  }
  key <- ifelse(x < y, paste(x, y, sep = "\r"), paste(y, x, sep = "\r"))
  dup <- duplicated(key) | duplicated(key, fromLast = TRUE)
  if (any(dup)) {
    cli::cli_abort(c(
      "Pair{?s} given more than once: {.val {label[dup]}}.",
      i = "Each block draws both directions, so give each pair once."
    ), call = call)
  }
  data.frame(x = x, y = y, stringsAsFactors = FALSE)
}

# Blocks per stack (nrow) and number of stacks (ncol) for n pairs. With
# `by_row` the blocks fill rows instead: ncol blocks per row, nrow rows.
.pair_stack_layout <- function(n, nrow = NULL, ncol = NULL, by_row = FALSE,
                               call = rlang::caller_env()) {
  for (nm in c("nrow", "ncol")) {
    value <- if (identical(nm, "nrow")) nrow else ncol
    if (!is.null(value) &&
        (!is.numeric(value) || length(value) != 1L || !is.finite(value) ||
         value < 1 || value != round(value))) {
      cli::cli_abort("{.arg {nm}} must be a single positive integer or NULL.",
                     call = call)
    }
  }
  if (is.null(nrow) && is.null(ncol)) {
    lines <- if (n <= 5L) 1L else ceiling(n / 5L)
    if (by_row) nrow <- lines else ncol <- lines
  }
  if (is.null(nrow)) nrow <- ceiling(n / ncol)
  if (is.null(ncol)) ncol <- ceiling(n / nrow)
  if (nrow * ncol < n) {
    cli::cli_abort(c(
      paste("{.arg nrow} = {nrow} and {.arg ncol} = {ncol} hold",
            "{nrow * ncol} pair{?s}, fewer than the {n} given."),
      i = "Give one of them and the other follows."
    ), call = call)
  }
  if (by_row) nrow <- ceiling(n / ncol) else ncol <- ceiling(n / nrow)
  list(nrow = as.integer(nrow), ncol = as.integer(ncol))
}

# The blocks in stacks of stacks$nrow, top to bottom, the stacks side by
# side, laid out as one grid of panels so that patchwork aligns every
# panel, axis and title across the stacks. Cells past the last block are
# spacers. One block is returned as it is. The two panels of a block sit
# close and the space goes between blocks, so each pair reads as a unit.
# With `stacked` each block is a column of two panels and the blocks fill
# rows, so every forward panel of a row of blocks shares one row of panels.
.stack_blocks <- function(blocks, stacks, stacked = FALSE) {
  n <- length(blocks)
  per <- length(blocks[[1L]])
  if (stacked && per == 2L) {
    blocks <- lapply(blocks, function(block) {
      list(block[[1L]] +
             ggplot2::theme(plot.margin = ggplot2::margin(4, 6, 2, 6)),
           block[[2L]] +
             ggplot2::theme(plot.margin = ggplot2::margin(2, 6, 8, 6)))
    })
    cells <- list()
    for (r in seq_len(stacks$nrow)) {
      for (face in seq_len(per)) {
        for (s in seq_len(stacks$ncol)) {
          i <- (r - 1L) * stacks$ncol + s
          cells <- c(cells, list(if (i <= n) {
            blocks[[i]][[face]]
          } else {
            patchwork::plot_spacer()
          }))
        }
      }
    }
    return(patchwork::wrap_plots(cells, ncol = stacks$ncol, byrow = TRUE))
  }
  if (per == 2L) {
    blocks <- lapply(blocks, function(block) {
      list(block[[1L]] +
             ggplot2::theme(plot.margin = ggplot2::margin(4, 1, 4, 11)),
           block[[2L]] +
             ggplot2::theme(plot.margin = ggplot2::margin(4, 11, 4, 1)))
    })
  }
  if (n == 1L) {
    if (per == 1L) return(blocks[[1L]][[1L]])
    return(patchwork::wrap_plots(blocks[[1L]], nrow = 1L))
  }
  n_stacks <- ceiling(n / stacks$nrow)
  cells <- list()
  for (r in seq_len(stacks$nrow)) {
    for (s in seq_len(n_stacks)) {
      i <- (s - 1L) * stacks$nrow + r
      cells <- c(cells, if (i <= n) {
        blocks[[i]]
      } else {
        rep(list(patchwork::plot_spacer()), per)
      })
    }
  }
  patchwork::wrap_plots(cells, ncol = n_stacks * per, byrow = TRUE)
}

# The block of one pair as a list of panels: the two directional panels,
# left to right, or the overlay panel for display = "both".
.pair_block <- function(fit, x, y, display, grouping, style, text_sizes,
                        wrap_title = FALSE,
                        annotations = c("A", "edf", "r", "signif", "n")) {
  pair <- fit$pairs[[.find_pair(fit, x, y)]]
  background <- if (isTRUE(style$pair_background) && is.null(fit$adjust)) {
    .background_hex(pair$cor_pearson, style$background_palette,
                    style$background_strength)
  } else {
    NA_character_
  }
  if (display == "both") {
    return(list(.render_overlay_cell(
      fit, pair, x, y,
      points     = .cell_points(fit, x, y, grouping),
      style      = style,
      text_sizes = text_sizes,
      grouping   = grouping,
      background = background
    )))
  }
  dir_left  <- if (identical(x, pair$var_i)) "yx" else "xy"
  dir_right <- if (dir_left == "yx") "xy" else "yx"
  panels <- lapply(c(dir_left, dir_right), function(direction) {
    face <- .pair_face(pair, direction)
    p <- .render_cell(
      pair          = pair,
      direction     = direction,
      points        = .cell_points(fit, face$var_x, face$var_y, grouping,
                                   .face_partial(face, style)),
      style         = style,
      text_sizes    = text_sizes,
      annotations   = annotations,
      display       = display,
      p_adjust      = fit$settings$p_adjust,
      colour        = NA_character_,
      tier          = 0L,
      group_colours = grouping$colours,
      title         = .pair_formula(face$var_y, face$var_x, fit$adjust,
                                    wrap = wrap_title),
      # "marginal r" lengthens an adjusted strip past a half-page panel.
      wrap_strip    = wrap_title || !is.null(fit$adjust),
      background    = background,
      adjusted      = !is.null(fit$adjust)
    )
    .add_pair_axes(p, face, display, text_sizes, style$base_family)
  })
  panels
}

# ---------------------------------------------------------------
# Validation and lookup shared with janusplot_direction()
# ---------------------------------------------------------------

# `fit` is a janusplot_fit; `x` and `y` are two different names in
# fit$vars.
.check_fit_pair <- function(fit, x, y, call = rlang::caller_env()) {
  if (!inherits(fit, "janusplot_fit")) {
    cli::cli_abort(
      "{.arg fit} must be a {.cls janusplot_fit} object from {.fn janusplot_fit}.",
      call = call
    )
  }
  for (nm in c("x", "y")) {
    value <- if (identical(nm, "x")) x else y
    if (!is.character(value) || length(value) != 1L || is.na(value)) {
      cli::cli_abort("{.arg {nm}} must be a single variable name.",
                     call = call)
    }
  }
  if (identical(x, y)) {
    cli::cli_abort("{.arg x} and {.arg y} must name two different variables.",
                   call = call)
  }
  for (nm in c("x", "y")) {
    value <- if (identical(nm, "x")) x else y
    if (!value %in% fit$vars) {
      cli::cli_abort(c(
        "{.arg {nm}} = {.val {value}} is not a fitted variable of {.arg fit}.",
        i = "Fitted variables: {.val {fit$vars}}."
      ), call = call)
    }
  }
  invisible(NULL)
}

# Index into fit$pairs of the unordered pair {x, y}.
.find_pair <- function(fit, x, y) {
  hit <- vapply(fit$pairs, function(p) {
    setequal(c(p$var_i, p$var_j), c(x, y))
  }, logical(1L))
  which(hit)[1L]
}

# "y ~ s(x)" with the adjust terms appended, in the user's names; with
# `wrap`, a line break after "~".
.pair_formula <- function(response, predictor, adjust, wrap = FALSE) {
  out <- sprintf(if (wrap) "%s ~\ns(%s)" else "%s ~ s(%s)", response,
                 predictor)
  if (is.null(adjust)) return(out)
  rhs <- paste(deparse(adjust[[2L]], width.cutoff = 500L), collapse = " ")
  paste(out, "+", rhs)
}

# ---------------------------------------------------------------
# Axis titles and tick labels on a pair panel. .render_cell() draws a
# void panel for the matrix; the pair view adds the axes on top.
# ---------------------------------------------------------------

.pair_axis_theme <- function(text_sizes, family = "") {
  axis_pt <- text_sizes$pt$axis
  ggplot2::theme(
    axis.title.x      = .element_text_or_blank(
      axis_pt + 0.5, colour = "grey15", family = family,
      margin = ggplot2::margin(t = 3)
    ),
    axis.title.y      = .element_text_or_blank(
      axis_pt + 0.5, colour = "grey15", family = family,
      angle = 90, margin = ggplot2::margin(r = 3)
    ),
    axis.text.x       = .element_text_or_blank(
      axis_pt - 0.5, colour = "grey30", family = family,
      margin = ggplot2::margin(t = 1.5)
    ),
    axis.text.y       = .element_text_or_blank(
      axis_pt - 0.5, colour = "grey30", family = family,
      hjust = 1, margin = ggplot2::margin(r = 1.5)
    ),
    axis.ticks        = ggplot2::element_line(colour = "grey55",
                                              linewidth = 0.3),
    axis.ticks.length = grid::unit(2, "pt"),
    plot.margin       = ggplot2::margin(4, 8, 4, 4)
  )
}

.add_pair_axes <- function(p, face, display, text_sizes, family = "") {
  drawn <- if (display == "fit") {
    nrow(face$pred) > 0L
  } else {
    deriv_df <- face$deriv[[if (display == "d1") "1" else "2"]]
    !is.null(deriv_df) && nrow(deriv_df) > 0L
  }
  if (!drawn) return(p)
  y_title <- switch(display,
    fit = face$var_y,
    d1  = sprintf("d %s / d %s", face$var_y, face$var_x),
    d2  = sprintf("d2 %s / d %s2", face$var_y, face$var_x)
  )
  p + ggplot2::labs(x = face$var_x, y = y_title) +
    .pair_axis_theme(text_sizes, family)
}

# ---------------------------------------------------------------
# The overlay panel: both directional curves in the z-score plane of
# the pair's rows, x standardised across, y standardised up. The reverse
# fit has y on its own predictor axis, so its axes swap into the plane
# and its band is drawn with orientation = "y".
# ---------------------------------------------------------------

.overlay_reverse_colour <- function() "#d95f02"

.render_overlay_cell <- function(fit, pair, x, y, points, style, text_sizes,
                                 grouping = NULL, background = NA_character_) {
  dir_forward <- if (identical(x, pair$var_i)) "yx" else "xy"
  dir_reverse <- if (dir_forward == "yx") "xy" else "yx"
  face_f <- .pair_face(pair, dir_forward)
  face_r <- .pair_face(pair, dir_reverse)
  to_zx <- .build_axis_transform(points$x, mode = "standardised")$fn
  to_zy <- .build_axis_transform(points$y, mode = "standardised")$fn
  rev_colour <- .overlay_reverse_colour()

  # Strip and panel --------------------------------------------------------
  glyph <- function(face) .face_signif(face, fit$settings$p_adjust)
  edf_part <- function(face) {
    if (is.na(face$edf)) return(sprintf("%s ~ %s: no fit", face$var_y,
                                        face$var_x))
    trimws(sprintf("%s ~ %s: EDF %.1f %s", face$var_y, face$var_x,
                   face$edf, glyph(face)))
  }
  # One line per direction, so the strip stays inside its panel when
  # panels are placed side by side with `|`.
  strip <- paste(
    paste(c(if (!is.na(pair$asymmetry_index)) {
      if (.pair_not_significant(pair)) {
        paste("A", .a_dash(style$glyph_style))
      } else {
        sprintf("A %.2f", pair$asymmetry_index)
      }
    }, edf_part(face_f)), collapse = "   "),
    edf_part(face_r),
    sep = "\n"
  )
  # Two lines, so the title stays inside its panel when overlay panels
  # are placed side by side with `|`.
  title <- sprintf("%s and %s,\nboth directions in z-scores", x, y)
  if (!is.null(fit$adjust)) {
    title <- paste0(title, ",\nadjusted for ",
                    paste(deparse(fit$adjust[[2L]], width.cutoff = 500L),
                          collapse = " "))
  }
  p <- ggplot2::ggplot() +
    .cell_theme(strip_pt = text_sizes$pt$strip, background = background,
                family = style$base_family) +
    ggplot2::labs(title = title, subtitle = strip,
                  x = paste0(x, " (z-score)"), y = paste0(y, " (z-score)")) +
    .pair_axis_theme(text_sizes, style$base_family)
  if (nrow(face_f$pred) == 0L && nrow(face_r$pred) == 0L) {
    return(.empty_cell_text(p, "no fit", text_sizes, style$base_family))
  }

  # Points -----------------------------------------------------------------
  if (isTRUE(style$show_data) && nrow(points) > 0L) {
    points$x <- to_zx(points$x)
    points$y <- to_zy(points$y)
    p <- p + .cell_points_layer(points, style, grouping$colours,
                                n_used = face_f$n_used)
  }

  # In the z-score plane y = x is the SD line: a curve flatter than it on
  # its own axis regresses towards the mean.
  if (isTRUE(style$identity_line)) {
    p <- p + ggplot2::geom_abline(intercept = 0, slope = 1,
                                  colour = "grey45", linewidth = 0.4,
                                  linetype = "22")
  }

  # Bands, then curves -----------------------------------------------------
  pred_f <- face_f$pred
  pred_f <- data.frame(x = to_zx(pred_f$x), fit = to_zy(pred_f$fit),
                       lo = to_zy(pred_f$lo), hi = to_zy(pred_f$hi))
  pred_r <- face_r$pred
  pred_r <- data.frame(y = to_zy(pred_r$x), fit = to_zx(pred_r$fit),
                       lo = to_zx(pred_r$lo), hi = to_zx(pred_r$hi))
  if (isTRUE(style$show_ci)) {
    if (nrow(pred_f) > 0L) {
      p <- p + ggplot2::geom_ribbon(
        data = pred_f,
        ggplot2::aes(x = .data$x, ymin = .data$lo, ymax = .data$hi),
        fill = style$curve_colour, alpha = style$band_alpha,
        inherit.aes = FALSE
      )
    }
    if (nrow(pred_r) > 0L) {
      p <- p + ggplot2::geom_ribbon(
        data = pred_r,
        ggplot2::aes(y = .data$y, xmin = .data$lo, xmax = .data$hi),
        orientation = "y",
        fill = rev_colour, alpha = style$band_alpha,
        inherit.aes = FALSE
      )
    }
  }
  if (nrow(pred_f) > 0L) {
    p <- p + ggplot2::geom_line(
      data = pred_f, ggplot2::aes(x = .data$x, y = .data$fit),
      colour = style$curve_colour,
      linewidth = style$curve_width / ggplot2::.pt, inherit.aes = FALSE
    )
  }
  if (nrow(pred_r) > 0L) {
    p <- p + ggplot2::geom_path(
      data = pred_r, ggplot2::aes(x = .data$fit, y = .data$y),
      colour = rev_colour,
      linewidth = style$curve_width / ggplot2::.pt, inherit.aes = FALSE
    )
  }
  p
}

# A key naming each curve colour by its formula, one entry per line so
# it fits under a half-page panel.
.overlay_key_plot <- function(labels, colours, text_pt = 8.5, family = "") {
  df <- data.frame(
    x = c(0, 1, 0, 1), y = 0,
    curve = factor(rep(labels, each = 2L), levels = labels)
  )
  ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y,
                                   colour = .data$curve)) +
    ggplot2::geom_line(alpha = 0) +
    ggplot2::scale_colour_manual(
      values = stats::setNames(colours, labels),
      name   = NULL,
      guide  = ggplot2::guide_legend(
        ncol = 1L, override.aes = list(alpha = 1, linewidth = 1)
      )
    ) +
    ggplot2::theme_void(base_family = family) +
    ggplot2::theme(
      legend.position   = "bottom",
      legend.text       = .element_text_or_blank(text_pt, family = family),
      legend.key.width  = grid::unit(0.8, "cm"),
      legend.margin     = ggplot2::margin(0, 0, 0, 0),
      legend.box.margin = ggplot2::margin(0, 0, 0, 0),
      plot.margin       = ggplot2::margin(2, 0, 2, 0)
    )
}
