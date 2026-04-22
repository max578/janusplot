# Internal helpers — NOT EXPORTED.
# Matrix-assembly layer: stitch cells + diagonals into a k x k patchwork
# (labels on diagonals or suppressed) or a (k+1) x (k+1) patchwork
# with a top row + left column of border labels (corrplot tl.pos = "lt").
#
# Composite layout (post-matrix):
#   top row    -> matrix | colour-bar (colour-bar optional)
#   bottom row -> shape-types legend (optional, spans full width)

.assemble_matrix <- function(cells_by_ij, diag_cells, vars, colour_by,
                             colour_limits, palette,
                             shape_legend_plot = NULL,
                             labels = "border",
                             label_srt = 45,
                             label_cex = 1) {
  k <- length(vars)
  has_border <- identical(labels, "border")

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
    # (k + 1) x (k + 1) grid:
    #   row 0     -> corner | top labels (columns)
    #   rows 1..k -> left labels (rows) | matrix cells
    grid <- vector("list", (k + 1L) * (k + 1L))
    for (r in seq_len(k + 1L)) {
      for (c_ in seq_len(k + 1L)) {
        idx <- (r - 1L) * (k + 1L) + c_
        if (r == 1L && c_ == 1L) {
          grid[[idx]] <- .build_corner_cell()
        } else if (r == 1L) {
          grid[[idx]] <- .build_top_label_cell(
            vars[c_ - 1L], srt = label_srt, cex = label_cex
          )
        } else if (c_ == 1L) {
          grid[[idx]] <- .build_left_label_cell(
            vars[r - 1L], cex = label_cex
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

    # Strip allocations. Horizontal: 2.0 cm absolute for left labels.
    # Vertical: taller at 45/90 so rotated text has room to breathe.
    strip_w <- grid::unit(2.0, "cm")
    strip_h <- if (identical(label_srt, 0)) {
      grid::unit(0.6, "cm")
    } else if (abs(label_srt) >= 80) {
      grid::unit(2.0, "cm")
    } else {
      grid::unit(1.6, "cm")
    }

    matrix_grid <- patchwork::wrap_plots(
      grid,
      nrow    = k + 1L,
      ncol    = k + 1L,
      byrow   = TRUE,
      widths  = grid::unit.c(strip_w, rep(grid::unit(1, "null"), k)),
      heights = grid::unit.c(strip_h, rep(grid::unit(1, "null"), k))
    )
  }

  has_colourbar <- !(colour_by == "none" || !all(is.finite(colour_limits)))
  has_shape_leg <- !is.null(shape_legend_plot)

  # --- Top row: matrix + optional colour-bar ---
  top_row <- if (has_colourbar) {
    patchwork::wrap_plots(
      list(matrix_grid,
           .build_legend_plot(colour_by, colour_limits, palette)),
      nrow   = 1L,
      widths = grid::unit.c(grid::unit(1, "null"),
                            grid::unit(1.8, "cm"))
    )
  } else {
    matrix_grid
  }

  if (!has_shape_leg) return(top_row)

  # --- Bottom row: shape legend spans full width ---
  patchwork::wrap_plots(
    list(top_row, shape_legend_plot),
    ncol    = 1L,
    heights = grid::unit.c(grid::unit(1, "null"),
                           grid::unit(0.42, "null"))
  )
}
