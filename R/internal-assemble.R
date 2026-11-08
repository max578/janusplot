# Internal helpers -- NOT EXPORTED.
# Matrix-assembly layer: stitch cells + diagonals into a k x k patchwork
# (labels suppressed) or a (k+1) x (k+1) patchwork with a top row + left
# column of border labels (corrplot tl.pos = "lt") and the corner key.
#
# Composite layout (post-matrix):
#   top row    -> matrix | colour bar over background bar (optional)
#   middle row -> group legend (optional, spans full width)
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
                             axis_transforms = NULL) {
  k <- length(vars)
  key_pt <- if (isTRUE(show_key)) text_pt$key else NA_real_
  has_border <- identical(labels, "border")
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
    if (!is.na(key_pt) && k >= 2L) {
      key <- .key_layout(vars, key_pt)
      strip_w <- max(strip_w, key$width + 6)
      strip_h <- max(strip_h, key$height + 6)
    }
    # patchwork widths and heights size the panels, so the corner panel
    # is exactly strip_w x strip_h points.
    corner <- .build_key_cell(vars, key_pt, panel_w = strip_w,
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
    rows    <- c(rows, list(group_legend_plot))
    heights <- c(heights, list(grid::unit(0.9, "cm")))
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
