# Internal helpers — NOT EXPORTED.
# Shape-types legend: always shows the full taxonomy as a grid of
# canonical 1-cm thumbnail splines. Font-independent, publication-
# ready. Attached below the matrix at full width.

# Build the complete shape-categories legend plot. Renders all rows of
# .shape_taxonomy() so the plate doubles as a stable reference key
# readers can navigate back to regardless of which categories appear
# in the matrix they are inspecting.
.build_shape_legend_plot <- function(ncol = 6L,
                                     line_colour = "#08306b") {
  tax <- .shape_taxonomy()
  # Build one (x, y, category, label) data frame, with y per-category
  # normalised to [0, 1] for consistent panel scales.
  rows <- lapply(tax$category, function(cat) {
    df <- .shape_thumbnail_df(cat)
    y <- df$y
    if (all(is.na(y))) {
      df$y_norm <- NA_real_
    } else {
      r <- range(y, na.rm = TRUE)
      df$y_norm <- if (diff(r) == 0) 0.5 else (y - r[1]) / diff(r)
    }
    df
  })
  thumbs <- do.call(rbind, rows)
  # Panel strip: `label (code)` — keeps the compact 2-letter code
  # visible next to the long name so readers can cross-reference
  # cells that render the code.
  panel_label <- paste0(
    tax$label, " (", tax$code, ")"
  )
  names(panel_label) <- tax$category
  thumbs$panel <- panel_label[thumbs$category]
  # Preserve taxonomy order in the facet layout.
  level_labels <- panel_label
  thumbs$panel <- factor(thumbs$panel, levels = level_labels)

  # Special-case render: `indeterminate` has no thumbnail curve. We
  # draw a centred "?" annotation on a placeholder panel so the grid
  # stays rectangular.
  indet_panel <- panel_label[["indeterminate"]]
  flat_panel  <- panel_label[["flat"]]

  p <- ggplot2::ggplot(thumbs) +
    ggplot2::geom_line(
      ggplot2::aes(x = .data$x, y = .data$y_norm),
      colour = line_colour, linewidth = 0.8, na.rm = TRUE
    ) +
    # Flat category: dashed horizontal marker so it reads as "flat"
    # rather than empty panel.
    ggplot2::geom_hline(
      data = data.frame(panel = factor(flat_panel, levels = level_labels)),
      ggplot2::aes(yintercept = 0.5),
      colour = line_colour, linewidth = 0.6, linetype = "dashed"
    ) +
    ggplot2::geom_text(
      data = data.frame(
        panel = factor(indet_panel, levels = level_labels),
        x = 0.5, y = 0.5, glyph = "?"
      ),
      ggplot2::aes(x = .data$x, y = .data$y, label = .data$glyph),
      colour = "grey40", size = 5, fontface = "bold"
    ) +
    ggplot2::facet_wrap(~ panel, ncol = as.integer(ncol)) +
    ggplot2::scale_x_continuous(limits = c(-0.02, 1.02), expand = c(0, 0)) +
    ggplot2::scale_y_continuous(limits = c(-0.1, 1.1), expand = c(0, 0)) +
    ggplot2::labs(title = "Shape categories",
                  x = NULL, y = NULL) +
    ggplot2::theme_void(base_size = 8) +
    ggplot2::theme(
      plot.title        = ggplot2::element_text(
        size = 10, face = "bold",
        margin = ggplot2::margin(t = 4, b = 6)
      ),
      strip.text        = ggplot2::element_text(
        size = 8.5, colour = "grey15",
        margin = ggplot2::margin(t = 3, b = 1)
      ),
      strip.background  = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background  = ggplot2::element_rect(fill = "grey98",
                                                colour = NA),
      panel.border      = ggplot2::element_rect(fill = NA,
                                                colour = "grey75",
                                                linewidth = 0.35),
      panel.spacing.x   = grid::unit(4, "pt"),
      panel.spacing.y   = grid::unit(6, "pt"),
      plot.margin       = ggplot2::margin(4, 4, 4, 4)
    )
  p
}

# (Retained helper — still used by the cell renderer when the user
# explicitly opts into cell glyphs via annotations = "shape".)
.present_shape_categories <- function(fits, cutoffs) {
  vapply(fits, function(f) {
    .classify_shape(
      f$shape$M, f$shape$C,
      f$shape$n_turning_points, f$shape$n_inflections,
      f$shape$flat_range_ratio, cutoffs
    )
  }, character(1L))
}
