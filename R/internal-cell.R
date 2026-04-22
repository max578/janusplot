# Internal helpers — NOT EXPORTED.
# Cell-layer logic: build one ggplot per matrix cell.

# ---------------------------------------------------------------
# Colour encodings.
#  * "spearman" / "pearson" / "kendall" — symmetric correlation
#     coefficient, diverging palette, limits c(-1, 1).
#  * "edf" / "deviance_gap" — non-linearity index, sequential palette.
#  * "none" — no fill.
# Supported values for colour_by:
.colour_choices <- function() {
  c("spearman", "pearson", "kendall", "edf", "deviance_gap", "none")
}

.is_correlation_colour <- function(colour_by) {
  colour_by %in% c("spearman", "pearson", "kendall")
}

.colour_value <- function(fit_obj, colour_by) {
  if (colour_by == "none") return(NA_real_)
  if (colour_by == "edf") return(fit_obj$edf)
  if (colour_by == "deviance_gap") return(fit_obj$dev_exp)
  corr <- fit_obj$corr
  if (is.null(corr)) return(NA_real_)
  switch(colour_by,
    spearman = corr$cor_spearman,
    pearson  = corr$cor_pearson,
    kendall  = corr$cor_kendall,
    NA_real_
  )
}

.colour_label <- function(colour_by) {
  switch(colour_by,
    edf           = "EDF",
    deviance_gap  = "Dev. expl.",
    spearman      = "corr",
    pearson       = "corr",
    kendall       = "corr",
    none          = NULL,
    NULL
  )
}

# Defaults that depend on the chosen colour_by.
.default_palette <- function(colour_by) {
  if (.is_correlation_colour(colour_by)) "RdBu" else "viridis"
}

# ---------------------------------------------------------------
# Supported palettes.
# Colour-blind safe by design:
#   - viridis family (viridis/magma/plasma/inferno/cividis/mako/rocket)
#   - ColorBrewer sequential CB-safe: YlOrRd, YlGnBu, Blues, Greens
#   - ColorBrewer diverging CB-safe: RdYlBu, RdBu, PuOr
# NOT colour-blind safe (kept for visual impact): turbo, Spectral
# ---------------------------------------------------------------

.palettes_viridis <- c(
  viridis = "D", magma = "A", inferno = "B", plasma = "C",
  cividis = "E", mako = "F", rocket = "G", turbo = "H"
)

.palettes_brewer <- c(
  "RdYlBu", "RdBu", "PuOr", "Spectral",
  "YlOrRd", "YlGnBu", "Blues", "Greens"
)

.palettes_diverging <- c("RdYlBu", "RdBu", "PuOr", "Spectral")

.palette_is_cb_safe <- function(palette) {
  cb_safe <- c(
    "viridis", "magma", "inferno", "plasma", "cividis", "mako", "rocket",
    "RdYlBu", "RdBu", "PuOr", "YlOrRd", "YlGnBu", "Blues", "Greens"
  )
  palette %in% cb_safe
}

.palette_choices <- function() {
  c(names(.palettes_viridis), .palettes_brewer)
}

# Endpoint colours for a diverging ColorBrewer palette, extracted via
# grDevices::colorRampPalette to avoid a hard dep on RColorBrewer.
.brewer_divergent_endpoints <- function(palette) {
  # Hand-picked 3-colour anchors for the 4 supported diverging palettes.
  # Values sourced from ColorBrewer 2.0 sequential levels; kept static
  # so we avoid runtime dependence on RColorBrewer.
  switch(palette,
    RdBu    = c(low = "#2166AC", mid = "#F7F7F7", high = "#B2182B"),
    RdYlBu  = c(low = "#313695", mid = "#FFFFBF", high = "#A50026"),
    PuOr    = c(low = "#542788", mid = "#F7F7F7", high = "#B35806"),
    Spectral = c(low = "#3288BD", mid = "#FFFFBF", high = "#D53E4F"),
    c(low = "#2166AC", mid = "#F7F7F7", high = "#B2182B")
  )
}

# Diverging symmetric scale for correlation colouring. RdBu (and peers)
# is reversed relative to brewer's default so negative = blue, positive
# = red, matching corrplot conventions.
.palette_scale_diverging <- function(palette, label, show_guide = FALSE) {
  g <- if (show_guide) {
    ggplot2::guide_colourbar(
      barheight      = grid::unit(0.6, "npc"),
      barwidth       = grid::unit(0.9, "lines"),
      title.position = "top",
      title.hjust    = 0.5
    )
  } else {
    "none"
  }
  eps <- .brewer_divergent_endpoints(palette)
  ggplot2::scale_fill_gradient2(
    low      = eps[["low"]],
    mid      = eps[["mid"]],
    high     = eps[["high"]],
    midpoint = 0,
    limits   = c(-1, 1),
    name     = label,
    na.value = "grey95",
    guide    = g
  )
}

.palette_scale <- function(palette, limits, label, colour_by,
                           show_guide = FALSE) {
  if (.is_correlation_colour(colour_by)) {
    # If user picked a sequential palette while colouring by correlation,
    # silently upgrade to the default diverging palette.
    if (!palette %in% .palettes_diverging) palette <- "RdBu"
    return(.palette_scale_diverging(palette, label, show_guide))
  }
  g <- if (show_guide) {
    ggplot2::guide_colourbar(
      barheight      = grid::unit(0.6, "npc"),
      barwidth       = grid::unit(0.9, "lines"),
      title.position = "top",
      title.hjust    = 0.5
    )
  } else {
    "none"
  }
  if (palette %in% names(.palettes_viridis)) {
    ggplot2::scale_fill_viridis_c(
      option   = .palettes_viridis[[palette]],
      limits   = limits,
      name     = label,
      na.value = "grey95",
      guide    = g
    )
  } else if (palette %in% .palettes_brewer) {
    ggplot2::scale_fill_distiller(
      palette   = palette,
      direction = 1,
      limits    = limits,
      name      = label,
      na.value  = "grey95",
      guide     = g
    )
  } else {
    cli::cli_abort(c(
      "Unknown {.arg palette}: {.val {palette}}.",
      i = "Choices: {.val {.palette_choices()}}"
    ))
  }
}

# ---------------------------------------------------------------
# Stand-alone colour-bar legend plot placed to the right of the matrix.
# ---------------------------------------------------------------

.build_legend_plot <- function(colour_by, limits, palette) {
  label <- .colour_label(colour_by)
  df <- data.frame(x = 1, v = limits)
  ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$v)) +
    ggplot2::geom_point(
      ggplot2::aes(fill = .data$v),
      shape = 22, size = 0, stroke = 0, alpha = 0
    ) +
    .palette_scale(palette, limits, label, colour_by, show_guide = TRUE) +
    ggplot2::theme_void() +
    ggplot2::theme(
      legend.position        = "left",
      legend.title           = ggplot2::element_text(
        size = 10, face = "bold",
        margin = ggplot2::margin(b = 4)
      ),
      legend.text            = ggplot2::element_text(size = 9),
      legend.margin          = ggplot2::margin(0, 0, 0, 0),
      legend.box.margin      = ggplot2::margin(0, 0, 0, 0),
      legend.box.spacing     = grid::unit(0, "pt"),
      plot.margin            = ggplot2::margin(0, 0, 0, 4)
    )
}

# ---------------------------------------------------------------
# Off-diagonal cell: raw points + CI ribbon + fitted line.
# ---------------------------------------------------------------

.cell_text_sizes <- function(k,
                              text_scale_diag     = 1,
                              text_scale_off_diag = 1) {
  auto       <- max(0.35, (3 / max(k, 2L))^0.55)
  off_scale  <- auto * text_scale_off_diag
  diag_scale <- auto * text_scale_diag
  list(
    n_edf  = 4.0 * off_scale,
    glyph  = 4.6 * off_scale,
    asym   = 3.8 * off_scale,
    shape  = 6.0 * off_scale,
    empty  = 3.2 * off_scale,
    diag   = 5.2 * diag_scale
  )
}

.build_cell <- function(fit_obj, show_data, show_ci, colour_by, palette,
                        signif_glyph, annotations, shape_cutoffs,
                        glyph_style, asym_val,
                        colour_limits, is_upper,
                        text_sizes = .cell_text_sizes(3L)) {
  colour_val   <- .colour_value(fit_obj, colour_by)
  colour_label <- .colour_label(colour_by)

  p <- ggplot2::ggplot() +
    ggplot2::theme_void(base_size = 8) +
    ggplot2::theme(
      aspect.ratio     = 1,
      plot.margin      = ggplot2::margin(3, 3, 3, 3),
      plot.background  = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background = ggplot2::element_rect(fill = NA, colour = NA),
      panel.border     = ggplot2::element_rect(fill = NA,
                                               colour = "grey55",
                                               linewidth = 0.35)
    )

  if (colour_by != "none" && !is.na(colour_val) &&
      all(is.finite(colour_limits))) {
    fill_df <- data.frame(fill_val = colour_val)
    p <- p +
      ggplot2::geom_rect(
        data    = fill_df,
        mapping = ggplot2::aes(xmin = -Inf, xmax = Inf,
                               ymin = -Inf, ymax = Inf,
                               fill = .data$fill_val),
        alpha   = 0.45,
        inherit.aes = FALSE
      ) +
      .palette_scale(palette, colour_limits, colour_label, colour_by)
  }

  if (nrow(fit_obj$pred) == 0L) {
    return(p + ggplot2::annotate(
      "text", x = 0.5, y = 0.5, label = "n < 5",
      size = text_sizes$empty, colour = "grey40"
    ) + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1))
  }

  if (show_data && nrow(fit_obj$raw) > 0L) {
    raw <- fit_obj$raw
    names(raw) <- c("x", "y")
    p <- p + ggplot2::geom_point(
      data = raw,
      ggplot2::aes(x = .data$x, y = .data$y),
      colour = "grey25", size = 0.4, alpha = 0.25,
      inherit.aes = FALSE
    )
  }
  if (show_ci) {
    p <- p + ggplot2::geom_ribbon(
      data = fit_obj$pred,
      ggplot2::aes(x = .data$x, ymin = .data$lo, ymax = .data$hi),
      fill = "#08306b", alpha = 0.20,
      inherit.aes = FALSE
    )
  }
  p <- p + ggplot2::geom_line(
    data = fit_obj$pred,
    ggplot2::aes(x = .data$x, y = .data$fit),
    colour = "#08306b", linewidth = 0.7,
    inherit.aes = FALSE
  )

  # Top-right: significance glyph
  if (signif_glyph) {
    glyph <- .pvalue_to_glyph(fit_obj$pvalue)
    if (nzchar(glyph)) {
      p <- p + ggplot2::annotate(
        "text", x = Inf, y = Inf, hjust = 1.25, vjust = 1.4,
        label = glyph, size = text_sizes$glyph, fontface = "bold"
      )
    }
  }

  # Bottom-left stack: A (top line) + EDF (bottom line), in whichever
  # combination the user asked for via annotations.
  bl_lines <- character()
  if ("A" %in% annotations && !is.na(asym_val)) {
    bl_lines <- c(bl_lines, sprintf("A = %.2f", asym_val))
  }
  if ("edf" %in% annotations && !is.na(fit_obj$edf)) {
    bl_lines <- c(bl_lines, sprintf("EDF = %.2f", fit_obj$edf))
  }
  if (length(bl_lines)) {
    p <- p + ggplot2::annotate(
      "text", x = -Inf, y = -Inf,
      hjust = -0.07, vjust = -0.15,
      label = paste(bl_lines, collapse = "\n"),
      size = text_sizes$n_edf, lineheight = 0.95,
      colour = "grey15", fontface = "plain"
    )
  }

  # Compute shape category once if either code (top-left) or shape
  # (bottom-right) is requested — they occupy distinct corners and
  # no longer compete.
  want_code  <- "code"  %in% annotations
  want_glyph <- "shape" %in% annotations
  shape_cat <- if (want_code || want_glyph) {
    .classify_shape(
      fit_obj$shape$monotonicity_index,
      fit_obj$shape$convexity_index,
      fit_obj$shape$n_turning_points, fit_obj$shape$n_inflections,
      fit_obj$shape$flat_range_ratio, shape_cutoffs
    )
  } else {
    NA_character_
  }

  # Top-left: 2-letter shape code. ASCII, font-safe, lightweight.
  if (want_code) {
    code_txt <- .shape_lookup(shape_cat, "code")
    if (!is.na(code_txt) && nzchar(code_txt)) {
      p <- p + ggplot2::annotate(
        "text", x = -Inf, y = Inf,
        hjust = -0.20, vjust = 1.4,
        label = code_txt,
        size = text_sizes$n_edf,
        colour = "grey20", fontface = "bold"
      )
    }
  }

  # Bottom-right: shape glyph. Unicode or ASCII per glyph_style.
  if (want_glyph) {
    g <- .shape_glyph(shape_cat, style = glyph_style)
    if (!is.na(g) && nzchar(g)) {
      p <- p + ggplot2::annotate(
        "text", x = Inf, y = -Inf,
        hjust = 1.15, vjust = -0.25,
        label = g,
        size = text_sizes$shape,
        colour = "grey25", fontface = "bold"
      )
    }
  }
  p
}

# ---------------------------------------------------------------
# Blank diagonal cell — used when labels live on the border (or are
# suppressed entirely). Same panel geometry as an off-diagonal cell
# (no fill, thin grey border) so the matrix grid reads uniformly.
# ---------------------------------------------------------------

.build_blank_diagonal_cell <- function() {
  ggplot2::ggplot() +
    ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1) +
    ggplot2::theme_void(base_size = 8) +
    ggplot2::theme(
      aspect.ratio     = 1,
      plot.margin      = ggplot2::margin(3, 3, 3, 3),
      plot.background  = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background = ggplot2::element_rect(fill = NA, colour = NA),
      panel.border     = ggplot2::element_rect(fill = NA,
                                               colour = "grey55",
                                               linewidth = 0.35)
    )
}

# ---------------------------------------------------------------
# Border-label cells — variable names in the top strip (rotated)
# and left strip (horizontal, right-aligned). Mirrors corrplot's
# tl.pos = "lt" convention. No panel border, no aspect ratio;
# widths / heights are set by the assembly layer.
# ---------------------------------------------------------------

.build_top_label_cell <- function(label, srt = 45, cex = 1) {
  hj <- if (identical(srt, 0)) 0.5 else 0
  vj <- if (identical(srt, 0)) 0 else 0.5
  ggplot2::ggplot() +
    ggplot2::annotate(
      "text", x = 0.5, y = 0,
      label = label, angle = srt,
      hjust = hj, vjust = vj,
      size = 3.5 * cex, colour = "grey10"
    ) +
    ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::theme_void(base_size = 8) +
    ggplot2::theme(
      plot.margin      = ggplot2::margin(3, 3, 3, 3),
      plot.background  = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background = ggplot2::element_rect(fill = NA, colour = NA)
    )
}

.build_left_label_cell <- function(label, cex = 1) {
  ggplot2::ggplot() +
    ggplot2::annotate(
      "text", x = 1, y = 0.5,
      label = label,
      hjust = 1, vjust = 0.5,
      size = 3.5 * cex, colour = "grey10"
    ) +
    ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::theme_void(base_size = 8) +
    ggplot2::theme(
      plot.margin      = ggplot2::margin(3, 3, 3, 3),
      plot.background  = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background = ggplot2::element_rect(fill = NA, colour = NA)
    )
}

.build_corner_cell <- function() {
  ggplot2::ggplot() +
    ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1) +
    ggplot2::theme_void(base_size = 8) +
    ggplot2::theme(
      plot.margin      = ggplot2::margin(0, 0, 0, 0),
      plot.background  = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background = ggplot2::element_rect(fill = NA, colour = NA)
    )
}

# ---------------------------------------------------------------
# Diagonal cell — the variable name, bold, neutral grey background.
# Used only when labels = "diagonal" (legacy layout).
# ---------------------------------------------------------------

.build_diagonal_cell <- function(var_name,
                                 text_sizes = .cell_text_sizes(3L)) {
  char_scale <- min(1, 10 / max(1L, nchar(var_name)))
  label_size <- text_sizes$diag * char_scale
  ggplot2::ggplot() +
    ggplot2::annotate(
      "text", x = 0.5, y = 0.5, label = var_name,
      size = label_size, fontface = "bold", colour = "grey10"
    ) +
    ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1) +
    ggplot2::theme_void(base_size = 8) +
    ggplot2::theme(
      aspect.ratio     = 1,
      plot.margin      = ggplot2::margin(3, 3, 3, 3),
      plot.background  = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background = ggplot2::element_rect(fill = "grey92",
                                               colour = NA),
      panel.border     = ggplot2::element_rect(fill = NA,
                                               colour = "grey55",
                                               linewidth = 0.35)
    )
}
