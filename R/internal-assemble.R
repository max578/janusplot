# Internal helpers -- NOT EXPORTED.
# Matrix-assembly layer: stitch cells + diagonals into a k x k patchwork
# (labels suppressed) or a (k+1) x (k+1) patchwork with a top row + left
# column of border labels (corrplot tl.pos = "lt") and the corner key.
#
# Composite layout (post-matrix), legend_position = "right":
#   top row    -> matrix | colour bar over background bar (optional)
#   middle row -> group legend (optional, spans full width)
#   bottom row -> shape-types legend (optional, spans full width)
# legend_position = "bottom":
#   top row    -> matrix at full width, the corner empty
#   middle row -> key | group legend over horizontal colour bars
#   bottom row -> shape-types legend (optional, spans full width)

.assemble_matrix <- function(cells_by_ij, diag_cells, vars, colour_by,
                             colour_limits, palette,
                             shape_legend_plot = NULL,
                             group_legend_plot = NULL,
                             background_plot = NULL,
                             labels = "border",
                             label_srt = 45,
                             text_pt = .text_size_auto(length(vars)),
                             show_key = TRUE,
                             family = "",
                             axes = "original",
                             axis_transforms = NULL,
                             legend_position = "right",
                             bottom_bars = list(),
                             grouping = NULL) {
  k <- length(vars)
  key_pt <- if (isTRUE(show_key)) text_pt$key else NA_real_
  has_border <- identical(labels, "border")
  legend_bottom <- identical(legend_position, "bottom")
  # Under "bottom" the key leaves the corner for the legend row.
  corner_key_pt <- if (legend_bottom) NA_real_ else key_pt
  strip_w <- 0
  # Per-variable border-label rendering: original label or
  # mode-suffixed ("var (z)" / "var (centred)" / "rank(var)").
  display_label <- function(var_name) {
    if (is.null(axis_transforms) || identical(axes, "original")) {
      return(var_name)
    }
    tf <- axis_transforms[[var_name]]
    if (is.null(tf)) return(var_name)
    .label_with_suffix(var_name, tf$suffix, axes)         # nolint: object_usage_linter.
  }

  if (!has_border) {
    grid <- vector("list", k * k)
    for (i in seq_len(k)) {
      for (j in seq_len(k)) {
        idx <- (i - 1L) * k + j
        if (i == j) {
          grid[[idx]] <- diag_cells[[i]]
        } else {
          key <- sprintf("%d_%d", i, j)
          grid[[idx]] <- cells_by_ij[[key]]
        }
      }
    }
    matrix_grid <- patchwork::wrap_plots(
      grid, nrow = k, ncol = k, byrow = TRUE
    )
  } else {
    # Strip allocations in points. Horizontal: 2.0 cm for the left
    # labels; vertical: taller at 45/90 so rotated text has room. Both
    # grow to hold the corner key.
    cm <- 72.27 / 2.54
    strip_w <- 2.0 * cm
    strip_h <- if (identical(label_srt, 0)) {
      0.6 * cm
    } else if (abs(label_srt) >= 80) {
      2.0 * cm
    } else {
      1.6 * cm
    }
    # The left strip also holds the longest row label, estimated at 0.55
    # em per character.
    if (!is.na(text_pt$labels)) {
      label_chars <- max(nchar(vapply(vars, display_label, character(1L))))
      strip_w <- max(strip_w, label_chars * 0.55 * text_pt$labels + 6)
    }
    if (!is.na(corner_key_pt) && k >= 2L) {
      key <- .key_layout(vars, corner_key_pt)
      strip_w <- max(strip_w, key$width + 6)
      strip_h <- max(strip_h, key$height + 6)
    }
    # patchwork widths and heights size the panels, so the corner panel
    # is exactly strip_w x strip_h points.
    corner <- .build_key_cell(vars, corner_key_pt, panel_w = strip_w,
                              panel_h = strip_h, family = family)

    # (k + 1) x (k + 1) grid:
    #   row 0     -> corner key | top labels (columns)
    #   rows 1..k -> left labels (rows) | matrix cells
    grid <- vector("list", (k + 1L) * (k + 1L))
    for (r in seq_len(k + 1L)) {
      for (c_ in seq_len(k + 1L)) {
        idx <- (r - 1L) * (k + 1L) + c_
        if (r == 1L && c_ == 1L) {
          grid[[idx]] <- corner
        } else if (r == 1L) {
          grid[[idx]] <- .build_top_label_cell(
            display_label(vars[c_ - 1L]), srt = label_srt,
            size_pt = text_pt$labels, family = family
          )
        } else if (c_ == 1L) {
          grid[[idx]] <- .build_left_label_cell(
            display_label(vars[r - 1L]), size_pt = text_pt$labels,
            family = family
          )
        } else {
          i <- r - 1L
          j <- c_ - 1L
          if (i == j) {
            grid[[idx]] <- diag_cells[[i]]
          } else {
            key <- sprintf("%d_%d", i, j)
            grid[[idx]] <- cells_by_ij[[key]]
          }
        }
      }
    }

    matrix_grid <- patchwork::wrap_plots(
      grid,
      nrow    = k + 1L,
      ncol    = k + 1L,
      byrow   = TRUE,
      widths  = grid::unit.c(grid::unit(strip_w, "pt"),
                             rep(grid::unit(1, "null"), k)),
      heights = grid::unit.c(grid::unit(strip_h, "pt"),
                             rep(grid::unit(1, "null"), k))
    )
  }

  has_colourbar <- !(colour_by == "none" || !all(is.finite(colour_limits)))
  has_shape_leg <- !is.null(shape_legend_plot)

  if (legend_bottom) {
    legend_row <- .build_bottom_legend_row(
      vars, key_pt = if (has_border) key_pt else NA_real_, strip_w = strip_w,
      grouping = grouping, bars = bottom_bars, legend_pt = text_pt$legend,
      family = family
    )
    rows    <- list(matrix_grid)
    heights <- list(grid::unit(1, "null"))
    if (!is.null(legend_row)) {
      rows    <- c(rows, list(legend_row$plot))
      heights <- c(heights, list(grid::unit(legend_row$height, "pt")))
    }
    if (has_shape_leg) {
      rows    <- c(rows, list(shape_legend_plot))
      heights <- c(heights, list(grid::unit(0.42, "null")))
    }
    if (length(rows) == 1L) return(matrix_grid)
    return(patchwork::wrap_plots(
      rows,
      nrow    = length(rows),
      heights = do.call(grid::unit.c, heights)
    ))
  }

  # --- Top row: matrix + optional colour bar + optional background bar ---
  side <- list()
  if (has_colourbar) {
    side <- c(side, list(.build_legend_plot(colour_by, colour_limits, palette,
                                            text_pt = text_pt$legend,
                                            family = family)))
  }
  if (!is.null(background_plot)) side <- c(side, list(background_plot))
  # Both bars share one right-hand column, one above the other. With
  # border labels the column starts level with the first row of cells, so
  # the last column label can run past its cell without meeting a title.
  if (length(side) && has_border) {
    side_col <- patchwork::wrap_plots(
      c(list(ggplot2::ggplot() + ggplot2::theme_void() +
               ggplot2::theme(plot.background = ggplot2::element_rect(
                 fill = NA, colour = NA))), side),
      ncol    = 1L,
      heights = grid::unit.c(grid::unit(strip_h, "pt"),
                             rep(grid::unit(1, "null"), length(side)))
    )
  } else if (length(side)) {
    side_col <- patchwork::wrap_plots(side, ncol = 1L)
  }
  top_row <- if (length(side)) {
    # `ncol`, not `nrow = 1`: patchwork's `|` appends into a one-row
    # layout, which these fixed widths cannot take.
    patchwork::wrap_plots(
      list(matrix_grid, side_col),
      ncol   = 2L,
      widths = grid::unit.c(grid::unit(1, "null"), grid::unit(1, "pt"))
    )
  } else {
    matrix_grid
  }

  # --- Rows below the matrix: group legend, then the shape legend ---
  rows    <- list(top_row)
  heights <- list(grid::unit(1, "null"))
  if (!is.null(group_legend_plot)) {
    # The legend sits below the empty panel of its plot, so this height
    # is the gap between the matrix and the legend.
    rows    <- c(rows, list(group_legend_plot))
    heights <- c(heights, list(grid::unit(4, "pt")))
  }
  if (has_shape_leg) {
    rows    <- c(rows, list(shape_legend_plot))
    heights <- c(heights, list(grid::unit(0.42, "null")))
  }
  if (length(rows) == 1L) return(top_row)

  # `nrow`, not `ncol = 1`, so `/` stacks matrices instead of appending.
  patchwork::wrap_plots(
    rows,
    nrow    = length(rows),
    heights = do.call(grid::unit.c, heights)
  )
}

# ---------------------------------------------------------------
# Bottom legends (legend_position = "bottom"). One row under the matrix:
# the key in a column as wide as the row labels, and beside it one panel
# with the group legend over the colour bars. Every vertical position is
# in points and the row is sized to its content, so no space is left
# between the matrix and its legends.
# ---------------------------------------------------------------

# One list per colour scale drawn as a horizontal bar: its title, limits,
# the colours along the bar, the labelled breaks and the tick colour.
.bottom_bar_specs <- function(colour_by, colour_limits, palette,
                              colour_channel = "border",
                              background_by = "none",
                              background_palette = "BuOr",
                              background_strength = 0.35) {
  bars <- list()
  if (colour_by != "none" && all(is.finite(colour_limits))) {
    v <- seq(colour_limits[1L], colour_limits[2L], length.out = 101L)
    breaks <- pretty(colour_limits, n = 4L)
    where <- switch(colour_channel,
      border = "Border", tile = "Corner tile", fill = "Cell colour"
    )
    what <- switch(colour_by,
      nonlinearity = "non-linearity (EDF - 1)",
      asymmetry    = "asymmetry index A",
      deviance_gap = "deviance gap",
      .background_label(colour_by)
    )
    bars <- c(bars, list(list(
      title   = paste0(where, ": ", what),
      limits  = colour_limits,
      colours = .colour_hex(v, colour_by, colour_limits, palette),
      breaks  = breaks[breaks >= colour_limits[1L] &
                         breaks <= colour_limits[2L]],
      tick    = "white"
    )))
  }
  if (background_by != "none") {
    v <- seq(-1, 1, length.out = 101L)
    bars <- c(bars, list(list(
      title   = paste0("Background: ", .background_label(background_by)),
      limits  = c(-1, 1),
      colours = .background_hex(v, background_palette, background_strength),
      breaks  = .background_bar_breaks(),
      tick    = "grey10"
    )))
  }
  bars
}

# Heights in points of the two bands of the legend panel at legend text
# size `legend_pt`: the bars (labels, bar, title) and the group legend.
.bottom_legend_bands <- function(has_group, n_bars, legend_pt) {
  line <- if (is.na(legend_pt)) 0 else legend_pt
  c(bars = if (n_bars) 2 * line + 16 else 0,
    group = if (has_group) line + 12 else 0)
}

# The legend row as list(plot, height in points), or NULL when there is
# neither a key, a group nor a bar to draw. `strip_w` is the width of the
# row-label column, so the key sits under the row labels.
.build_bottom_legend_row <- function(vars, key_pt, strip_w, grouping, bars,
                                     legend_pt = 9, family = "") {
  has_key <- !is.na(key_pt) && length(vars) >= 2L
  bands <- .bottom_legend_bands(!is.null(grouping), length(bars), legend_pt)
  if (!has_key && sum(bands) == 0) return(NULL)
  key <- if (has_key) .key_layout(vars, key_pt)
  # 6 points of air between the matrix and the legends.
  panel_h <- max(sum(bands), key$height %||% 0) + 6
  panel <- .build_bottom_legend_panel(grouping, bars, bands, panel_h,
                                      legend_pt, family)
  if (!has_key) return(list(plot = panel, height = panel_h))
  key_w <- max(strip_w, key$width + 6)
  # The row-label cells carry 3 points of margin on each side.
  key_cell <- .build_key_cell(vars, key_pt, panel_w = key_w,
                              panel_h = panel_h, family = family) +
    ggplot2::theme(plot.margin = ggplot2::margin(0, 3, 0, 3))
  list(
    plot = patchwork::wrap_plots(
      list(key_cell, panel),
      ncol   = 2L,
      widths = grid::unit.c(grid::unit(key_w, "pt"), grid::unit(1, "null"))
    ),
    height = panel_h
  )
}

# The panel of the legend row, `panel_h` points high: the group legend in
# the upper band and the colour bars side by side in the lower one, the
# two bands centred in the height left under the 6 points of air.
.build_bottom_legend_panel <- function(grouping, bars, bands, panel_h,
                                       legend_pt = 9, family = "") {
  y0 <- (panel_h - 6 - sum(bands)) / 2
  line <- if (is.na(legend_pt)) 0 else legend_pt
  p <- ggplot2::ggplot()
  n <- length(bars)
  span <- if (n == 1L) 0.44 else 0.72 / max(n, 1L)
  for (i in seq_len(n)) {
    b <- bars[[i]]
    x_mid <- (i - 0.5) / n
    x_at <- function(v) {
      x_mid + span * ((v - b$limits[1L]) / diff(b$limits) - 0.5)
    }
    y_bar <- y0 + line + c(2, 9)
    inner <- b$breaks[b$breaks > b$limits[1L] & b$breaks < b$limits[2L]]
    # The bar as overlapping opaque slices, so no seam shows between them.
    edges <- x_at(seq(b$limits[1L], b$limits[2L],
                      length.out = length(b$colours) + 1L))
    step <- edges[2L] - edges[1L]
    p <- p +
      ggplot2::annotate(
        "rect", xmin = edges[-length(edges)],
        xmax = pmin(edges[-1L] + step / 2, edges[length(edges)]),
        ymin = y_bar[1L], ymax = y_bar[2L],
        fill = b$colours, colour = NA
      ) +
      ggplot2::annotate(
        "rect", xmin = x_at(b$limits[1L]), xmax = x_at(b$limits[2L]),
        ymin = y_bar[1L], ymax = y_bar[2L],
        fill = NA, colour = "grey50", linewidth = 0.3
      )
    if (length(inner)) {
      p <- p + ggplot2::annotate(
        "segment", x = x_at(inner), xend = x_at(inner),
        y = y_bar[1L], yend = y_bar[2L], colour = b$tick, linewidth = 0.4
      )
    }
    if (!is.na(legend_pt)) {
      p <- p +
        ggplot2::annotate(
          "text", x = x_at(b$breaks), y = y0 + line / 2,
          label = as.character(b$breaks), colour = "grey10",
          size = legend_pt * 8.5 / 9 / ggplot2::.pt, family = family
        ) +
        ggplot2::annotate(
          "text", x = x_mid, y = y_bar[2L] + 3 + line / 2,
          label = b$title, colour = "grey10", fontface = "bold",
          size = legend_pt / ggplot2::.pt, family = family
        )
    }
  }
  if (!is.null(grouping)) {
    levels <- names(grouping$colours)
    df <- data.frame(x = 0.5, y = 0,
                     level = factor(levels, levels = levels))
    p <- p +
      ggplot2::geom_point(
        data = df,
        ggplot2::aes(x = .data$x, y = .data$y, colour = .data$level),
        alpha = 0, size = 0
      ) +
      ggplot2::scale_colour_manual(
        values = grouping$colours,
        name   = grouping$name,
        guide  = ggplot2::guide_legend(
          nrow = 1L, override.aes = list(alpha = 1, size = 2.5)
        )
      )
  }
  p +
    ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
    ggplot2::scale_y_continuous(limits = c(0, panel_h), expand = c(0, 0)) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::theme_void(base_size = 8, base_family = family) +
    ggplot2::theme(
      legend.position        = "inside",
      legend.position.inside = c(
        0.5, (y0 + bands[["bars"]] + bands[["group"]] / 2) / panel_h
      ),
      legend.justification   = c(0.5, 0.5),
      legend.direction       = "horizontal",
      legend.title           = .element_text_or_blank(legend_pt, face = "bold",
                                                      family = family),
      legend.text            = .element_text_or_blank(legend_pt * 8.5 / 9,
                                                      family = family),
      legend.margin          = ggplot2::margin(0, 0, 0, 0),
      legend.key.size        = grid::unit(max(line, 6), "pt"),
      legend.background      = ggplot2::element_rect(fill = NA, colour = NA),
      plot.margin            = ggplot2::margin(0, 0, 0, 0),
      plot.background        = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background       = ggplot2::element_rect(fill = NA, colour = NA)
    )
}
