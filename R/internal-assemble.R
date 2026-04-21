# Internal helpers — NOT EXPORTED.
# Matrix-assembly layer: stitch cells + diagonals into a k x k patchwork.
# Layout:
#   top row    -> matrix | colour-bar (colour-bar optional)
#   bottom row -> shape-types legend (optional, spans full width)

.assemble_matrix <- function(cells_by_ij, diag_cells, vars, colour_by,
                             colour_limits, palette,
                             shape_legend_plot = NULL) {
  k <- length(vars)
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
  # `heights` is relative: the matrix block stays visually dominant,
  # the shape legend takes ~40 % of the matrix height at default
  # k = 4. For larger matrices the fraction shrinks naturally.
  patchwork::wrap_plots(
    list(top_row, shape_legend_plot),
    ncol    = 1L,
    heights = grid::unit.c(grid::unit(1, "null"),
                           grid::unit(0.42, "null"))
  )
}
