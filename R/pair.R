# pair.R -- janusplot_pair(): the two directions of one pair of a
# janusplot_fit, drawn side by side with axes, or overlaid in one z-score
# panel. Every number drawn comes from the fit object; nothing is
# refitted. Panels are built by .render_cell() in internal-cell.R; the
# overlay panel is .render_overlay_cell() below.

#' Draw both directions of one pair of a janusplot fit
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Draws the two directional fits of one pair of a [janusplot_fit()]
#' object side by side: `y ~ s(x)` on the left and `x ~ s(y)` on the
#' right, each with its raw points, band, curve, the model formula as the
#' title and a strip giving the pair's asymmetry index `A`, the EDF of
#' that direction, its significance glyph and the rows used. Nothing is
#' refitted.
#'
#' @details
#' The left panel always shows `y ~ s(x)`, whichever order the fit stored
#' the pair in. Titles name the model in the column names of the data,
#' with the fit's `adjust` terms appended, for example
#' `Ozone ~ s(Temp) + s(Month, bs = "re")`; the curve and band are then
#' population-level, as in [janusplot_fit()]. The significance glyph is
#' read from the adjusted p-value when the fit has `p_adjust` other than
#' `"none"`.
#'
#' `display = "both"` draws one panel in the z-score plane of the pair's
#' rows: `x` standardised on the horizontal axis and `y` on the vertical.
#' `y ~ s(x)` is drawn in `style$curve_colour` and `x ~ s(y)` in orange,
#' with its axes swapped into the same plane, so the two curves can be
#' compared directly. A key below the panel names each colour by its
#' formula.
#'
#' Points are drawn in grey, coloured by `group`, or as a light grey
#' binned density when the pair has more rows than
#' `style$density_threshold` and no `group` is given.
#'
#' @param fit A `janusplot_fit` object from [janusplot_fit()].
#' @param x Name of the predictor of the left panel, one of `fit$vars`.
#' @param y Name of the response of the left panel, one of `fit$vars`
#'   and different from `x`.
#' @param display What the panels show: `"fit"` (the default) the fitted
#'   curves over the data, `"d1"` or `"d2"` the first or second
#'   derivative of each smooth, which need that order in
#'   `fit$settings$derivatives`, and `"both"` the two curves overlaid in
#'   one z-score panel.
#' @param group Name of a factor, character or logical column of
#'   `fit$data` whose levels colour the raw points, with a legend below
#'   the panels, or `NULL` (the default). Drawing only; the column never
#'   enters the model.
#' @param style A [janusplot_style()] object holding every appearance
#'   setting.
#'
#' @returns A [patchwork][patchwork::patchwork-package] object, which is a
#'   ggplot: the two panels side by side, or the overlay panel with its
#'   key, and the group legend underneath when `group` is given.
#'
#' @family smooth-associations
#' @seealso [janusplot_fit()] for the object, [plot.janusplot_fit()] for
#'   the matrix, [janusplot_direction()] for the residual-independence
#'   test of the pair.
#'
#' @examples
#' fit <- janusplot_fit(airquality[, c("Ozone", "Temp", "Wind")],
#'                      engine = "gam")
#' janusplot_pair(fit, "Temp", "Ozone")
#' janusplot_pair(fit, "Temp", "Ozone", display = "both")
#'
#' \donttest{
#' # The first derivative of each direction, computed at fit time.
#' janusplot_pair(fit, "Temp", "Ozone", display = "d1")
#' }
#' @export
janusplot_pair <- function(
  fit,
  x,
  y,
  display = c("fit", "d1", "d2", "both"),
  group = NULL,
  style = janusplot_style()
) {
  .check_fit_pair(fit, x, y)
  display <- rlang::arg_match(display)
  .check_style(style)
  grouping <- .resolve_group(fit, group, style)
  if (display %in% c("d1", "d2")) {
    .check_display_available(display, fit$settings$derivatives)
  }

  # The pair and its two faces ---------------------------------------------
  pair <- fit$pairs[[.find_pair(fit, x, y)]]
  dir_left  <- if (identical(x, pair$var_i)) "yx" else "xy"
  dir_right <- if (dir_left == "yx") "xy" else "yx"
  text_sizes <- .cell_text_sizes(
    3L, text_scale_off_diag = style$text_scale_off_diag
  )
  group_legend <- if (is.null(grouping)) {
    NULL
  } else {
    .build_group_legend_plot(grouping)
  }

  # One overlay panel ------------------------------------------------------
  if (display == "both") {
    panel <- .render_overlay_cell(
      fit, pair, x, y,
      points     = .cell_points(fit, x, y, grouping),
      style      = style,
      text_sizes = text_sizes,
      grouping   = grouping
    )
    key <- .overlay_key_plot(
      c(.pair_formula(y, x, NULL), .pair_formula(x, y, NULL)),
      c(style$curve_colour, .overlay_reverse_colour())
    )
    rows <- list(panel, key, group_legend)
    heights <- list(grid::unit(1, "null"), grid::unit(0.7, "cm"),
                    grid::unit(0.9, "cm"))
    keep <- !vapply(rows, is.null, logical(1L))
    return(patchwork::wrap_plots(
      rows[keep], ncol = 1L, heights = do.call(grid::unit.c, heights[keep])
    ))
  }

  # Two directional panels -------------------------------------------------
  panels <- lapply(c(dir_left, dir_right), function(direction) {
    face <- .pair_face(pair, direction)
    p <- .render_cell(
      pair          = pair,
      direction     = direction,
      points        = .cell_points(fit, face$var_x, face$var_y, grouping),
      style         = style,
      text_sizes    = text_sizes,
      annotations   = c("A", "edf", "signif", "n"),
      display       = display,
      p_adjust      = fit$settings$p_adjust,
      colour        = NA_character_,
      tier          = 0L,
      group_colours = grouping$colours,
      title         = .pair_formula(face$var_y, face$var_x, fit$adjust)
    )
    .add_pair_axes(p, face, display, text_sizes)
  })
  row <- patchwork::wrap_plots(panels, nrow = 1L)
  if (is.null(group_legend)) return(row)
  patchwork::wrap_plots(
    list(row, group_legend), ncol = 1L,
    heights = grid::unit.c(grid::unit(1, "null"), grid::unit(0.9, "cm"))
  )
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

# "y ~ s(x)" with the adjust terms appended, in the user's names.
.pair_formula <- function(response, predictor, adjust) {
  out <- sprintf("%s ~ s(%s)", response, predictor)
  if (is.null(adjust)) return(out)
  rhs <- paste(deparse(adjust[[2L]], width.cutoff = 500L), collapse = " ")
  paste(out, "+", rhs)
}

# ---------------------------------------------------------------
# Axis titles and tick labels on a pair panel. .render_cell() draws a
# void panel for the matrix; the pair view adds the axes on top.
# ---------------------------------------------------------------

.pair_axis_theme <- function(text_sizes) {
  axis_pt <- 2 * text_sizes$n_edf
  ggplot2::theme(
    axis.title        = ggplot2::element_text(size = axis_pt + 0.5,
                                              colour = "grey15"),
    axis.title.x      = ggplot2::element_text(
      margin = ggplot2::margin(t = 3)
    ),
    axis.title.y      = ggplot2::element_text(
      angle = 90, margin = ggplot2::margin(r = 3)
    ),
    axis.text         = ggplot2::element_text(size = axis_pt - 0.5,
                                              colour = "grey30"),
    axis.text.x       = ggplot2::element_text(
      margin = ggplot2::margin(t = 1.5)
    ),
    axis.text.y       = ggplot2::element_text(
      hjust = 1, margin = ggplot2::margin(r = 1.5)
    ),
    axis.ticks        = ggplot2::element_line(colour = "grey55",
                                              linewidth = 0.3),
    axis.ticks.length = grid::unit(2, "pt"),
    plot.margin       = ggplot2::margin(4, 8, 4, 4)
  )
}

.add_pair_axes <- function(p, face, display, text_sizes) {
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
    .pair_axis_theme(text_sizes)
}

# ---------------------------------------------------------------
# The overlay panel: both directional curves in the z-score plane of
# the pair's rows, x standardised across, y standardised up. The reverse
# fit has y on its own predictor axis, so its axes swap into the plane
# and its band is drawn with orientation = "y".
# ---------------------------------------------------------------

.overlay_reverse_colour <- function() "#d95f02"

# Mean and standard deviation of a column, with sd = 1 for a constant.
.z_scale <- function(v) {
  v <- v[is.finite(v)]
  mu <- if (length(v)) mean(v) else 0
  s  <- if (length(v) > 1L) stats::sd(v) else 1
  if (!is.finite(s) || s <= 0) s <- 1
  list(mean = mu, sd = s)
}

.render_overlay_cell <- function(fit, pair, x, y, points, style, text_sizes,
                                 grouping = NULL) {
  dir_forward <- if (identical(x, pair$var_i)) "yx" else "xy"
  dir_reverse <- if (dir_forward == "yx") "xy" else "yx"
  face_f <- .pair_face(pair, dir_forward)
  face_r <- .pair_face(pair, dir_reverse)
  zx <- .z_scale(points$x)
  zy <- .z_scale(points$y)
  to_zx <- function(v) (v - zx$mean) / zx$sd
  to_zy <- function(v) (v - zy$mean) / zy$sd
  rev_colour <- .overlay_reverse_colour()

  # Strip and panel --------------------------------------------------------
  glyph <- function(face) .face_signif(face, fit$settings$p_adjust)
  edf_part <- function(face) {
    if (is.na(face$edf)) return(sprintf("%s ~ %s: no fit", face$var_y,
                                        face$var_x))
    trimws(sprintf("%s ~ %s: EDF %.1f %s", face$var_y, face$var_x,
                   face$edf, glyph(face)))
  }
  strip <- paste(
    c(if (!is.na(pair$asymmetry_index)) {
      sprintf("A %.2f", pair$asymmetry_index)
    }, edf_part(face_f), edf_part(face_r)),
    collapse = "   "
  )
  title <- sprintf("%s and %s, both directions in z-scores", x, y)
  if (!is.null(fit$adjust)) {
    title <- paste0(title, ", adjusted for ",
                    paste(deparse(fit$adjust[[2L]], width.cutoff = 500L),
                          collapse = " "))
  }
  p <- ggplot2::ggplot() +
    .cell_theme(strip_pt = 2 * text_sizes$n_edf) +
    ggplot2::labs(title = title, subtitle = strip,
                  x = paste0(x, " (z-score)"), y = paste0(y, " (z-score)")) +
    .pair_axis_theme(text_sizes)
  if (nrow(face_f$pred) == 0L && nrow(face_r$pred) == 0L) {
    return(p + ggplot2::annotate(
      "text", x = 0.5, y = 0.5, label = "no fit",
      size = text_sizes$empty, colour = "grey40"
    ) + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1))
  }

  # Points -----------------------------------------------------------------
  if (isTRUE(style$show_data) && nrow(points) > 0L) {
    points$x <- to_zx(points$x)
    points$y <- to_zy(points$y)
    p <- p + .cell_points_layer(points, style, grouping$colours,
                                n_used = face_f$n_used)
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
      colour = style$curve_colour, linewidth = 0.7, inherit.aes = FALSE
    )
  }
  if (nrow(pred_r) > 0L) {
    p <- p + ggplot2::geom_path(
      data = pred_r, ggplot2::aes(x = .data$fit, y = .data$y),
      colour = rev_colour, linewidth = 0.7, inherit.aes = FALSE
    )
  }
  p
}

# A one-line key naming each curve colour by its formula.
.overlay_key_plot <- function(labels, colours) {
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
        nrow = 1L, override.aes = list(alpha = 1, linewidth = 1)
      )
    ) +
    ggplot2::theme_void() +
    ggplot2::theme(
      legend.position   = "bottom",
      legend.text       = ggplot2::element_text(size = 8.5),
      legend.key.width  = grid::unit(0.8, "cm"),
      legend.margin     = ggplot2::margin(0, 0, 0, 0),
      legend.box.margin = ggplot2::margin(0, 0, 0, 0),
      plot.margin       = ggplot2::margin(2, 0, 2, 0)
    )
}
