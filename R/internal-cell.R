# Internal helpers -- NOT EXPORTED.
# Cell layer: the colour vocabulary and scales, the colour-bar and group
# legends, text sizes, axis transforms, compact tiers, the focus mask, and
# one ggplot per matrix cell drawn from a pair element of a janusplot_fit
# plus the raw points of that cell.

# ---------------------------------------------------------------
# Colour encodings
# ---------------------------------------------------------------
# colour_by names the quantity; style$colour_channel names where it is
# painted (border, tile or fill).
#  * "nonlinearity" -- EDF minus 1 of the cell's smooth; sequential from 0.
#  * "asymmetry"    -- the pair's A in [0, 1], the same in both cells.
#  * "pearson" / "spearman" / "kendall" -- symmetric correlation of the
#     pair, diverging palette, limits c(-1, 1).
#  * "deviance_gap" -- deviance explained by the smooth minus the straight
#     line's, in [0, 1], over the observed range.
#  * "none"         -- nothing painted.

.colour_choices <- function() {
  c("nonlinearity", "asymmetry", "pearson", "spearman", "kendall",
    "deviance_gap", "none")
}

.is_correlation_colour <- function(colour_by) {
  colour_by %in% c("spearman", "pearson", "kendall")
}

# The colour_by quantity of one directed cell (a face, see .pair_face()).
.face_colour_value <- function(face, colour_by) {
  switch(colour_by,
    nonlinearity = if (is.na(face$edf)) NA_real_ else face$edf - 1,
    asymmetry    = face$asymmetry_index,
    pearson      = face$cor_pearson,
    spearman     = face$cor_spearman,
    kendall      = face$cor_kendall,
    deviance_gap = face$deviance_gap,
    NA_real_
  )
}

.colour_label <- function(colour_by) {
  switch(colour_by,
    nonlinearity = "Non-linearity\n(EDF - 1)",
    asymmetry    = "Asymmetry\n(A)",
    deviance_gap = "Dev. gap",
    spearman     = "corr",
    pearson      = "corr",
    kendall      = "corr",
    NULL
  )
}

# Shared limits of the colour scale over the off-diagonal cells: fixed for
# correlations and A; from 0 to the observed maximum with a floor of 1 for
# non-linearity, so a wholly linear matrix shows pale borders rather than
# a degenerate scale; the observed range for the deviance gap.
.colour_limits <- function(values, colour_by) {
  if (colour_by == "none" || all(is.na(values))) {
    return(c(NA_real_, NA_real_))
  }
  if (.is_correlation_colour(colour_by)) return(c(-1, 1))
  if (colour_by == "asymmetry") return(c(0, 1))
  if (colour_by == "nonlinearity") {
    return(c(0, max(1, max(values, na.rm = TRUE))))
  }
  range(values, na.rm = TRUE)
}

# One hex colour per value from the scale the legend draws, so the painted
# channel and the colour bar cannot drift apart. NA where the value is
# missing or the scale has no finite limits.
.colour_hex <- function(values, colour_by, limits, palette) {
  out <- rep(NA_character_, length(values))
  if (colour_by == "none" || !all(is.finite(limits))) return(out)
  scale <- .palette_scale(palette, limits, .colour_label(colour_by),
                          colour_by)
  ok <- !is.na(values)
  out[ok] <- scale$map(values[ok])
  out
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

# BuOr pairs RdBu's blue with PuOr's orange; it is a background palette
# only (no ColorBrewer scale carries the name).
.palettes_diverging <- c("RdYlBu", "RdBu", "PuOr", "Spectral", "BuOr")

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
    BuOr    = c(low = "#2166AC", mid = "#F7F7F7", high = "#B35806"),
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
      # barheight omitted; deferred to theme legend.key.height so the
      # bar flex-fills the available vertical space (corrplot-style).
      theme = ggplot2::theme(
        legend.key.width      = grid::unit(0.9, "lines"),
        legend.title.position = "top",
        legend.title          = ggplot2::element_text(hjust = 0.5),
        legend.ticks          = ggplot2::element_line(linewidth = 0.5),
        legend.frame          = ggplot2::element_rect(colour = "grey50",
                                                      linewidth = 0.3)
      )
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
      # barheight omitted; deferred to theme legend.key.height so the
      # bar flex-fills the available vertical space (corrplot-style).
      theme = ggplot2::theme(
        legend.key.width      = grid::unit(0.9, "lines"),
        legend.title.position = "top",
        legend.title          = ggplot2::element_text(hjust = 0.5),
        legend.ticks          = ggplot2::element_line(linewidth = 0.5),
        legend.frame          = ggplot2::element_rect(colour = "grey50",
                                                      linewidth = 0.3)
      )
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
    choices <- .palette_choices()                     # nolint: object_usage_linter.
    cli::cli_abort(c(
      "Unknown {.arg palette}: {.val {palette}}.",
      i = "Choices: {.val {choices}}"
    ))
  }
}

# ---------------------------------------------------------------
# Stand-alone colour-bar legend plot placed to the right of the matrix.
# ---------------------------------------------------------------

.build_legend_plot <- function(colour_by, limits, palette, text_pt = 9,
                               family = "") {
  label <- .colour_label(colour_by)
  df <- data.frame(x = 1, v = limits)
  ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$v)) +
    ggplot2::geom_point(
      ggplot2::aes(fill = .data$v),
      shape = 22, size = 0, stroke = 0, alpha = 0
    ) +
    .palette_scale(palette, limits, label, colour_by, show_guide = TRUE) +
    ggplot2::theme_void(base_family = family) +
    ggplot2::theme(
      legend.position        = "left",
      # Corrplot-style tracking: the bar flex-fills the legend box's
      # vertical extent via the grid null unit, so the colour-bar height
      # follows the matrix panel height regardless of figure size.
      legend.key.height      = grid::unit(1, "null"),
      legend.key.width       = grid::unit(0.9, "lines"),
      legend.title           = .element_text_or_blank(
        text_pt, face = "bold", family = family,
        margin = ggplot2::margin(b = 4)
      ),
      legend.text            = .element_text_or_blank(text_pt,
                                                      family = family),
      legend.margin          = ggplot2::margin(0, 0, 0, 0),
      legend.box.margin      = ggplot2::margin(0, 0, 0, 0),
      legend.box.spacing     = grid::unit(0, "pt"),
      plot.margin            = ggplot2::margin(0, 0, 0, 4)
    )
}

# ---------------------------------------------------------------
# Stand-alone group legend placed below the matrix: one key per level of
# the `group` column, in the colours the cells use for the points.
# ---------------------------------------------------------------

.build_group_legend_plot <- function(grouping, text_pt = 9, family = "") {
  levels <- names(grouping$colours)
  df <- data.frame(x = 1, level = factor(levels, levels = levels))
  ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$x,
                                   colour = .data$level)) +
    ggplot2::geom_point(alpha = 0, size = 0) +
    ggplot2::scale_colour_manual(
      values = grouping$colours,
      name   = grouping$name,
      guide  = ggplot2::guide_legend(
        nrow = 1L, override.aes = list(alpha = 1, size = 2.5)
      )
    ) +
    ggplot2::theme_void(base_family = family) +
    ggplot2::theme(
      legend.position   = "bottom",
      legend.title      = .element_text_or_blank(text_pt, face = "bold",
                                                 family = family),
      legend.text       = .element_text_or_blank(text_pt * 8.5 / 9,
                                                 family = family),
      legend.margin     = ggplot2::margin(0, 0, 0, 0),
      legend.box.margin = ggplot2::margin(0, 0, 0, 0),
      plot.margin       = ggplot2::margin(2, 0, 2, 0)
    )
}

# ---------------------------------------------------------------
# Text sizes and widths. Every text size is resolved to points from
# style$text_size; NA marks a text that is not drawn. The in-panel sizes
# (n_edf, glyph, asym, shape, empty, diag) are ggplot2 text sizes in mm,
# derived from the strip and diagonal sizes at the 0.2.0 ratios.
# ---------------------------------------------------------------

# The 0.2.0 scaling of cell text with the variable count k.
.text_auto_scale <- function(k) {
  max(0.35, (3 / max(k, 2L))^0.55)
}

# Point sizes of every text element under text_size = "auto". The strip
# keeps 5 points or more so a 12-variable strip stays legible in print.
.text_size_auto <- function(k) {
  a <- .text_auto_scale(k)
  strip <- max(5, 8 * a)
  list(
    strip    = strip,
    labels   = 10,
    diagonal = 5.2 * ggplot2::.pt * a,
    legend   = 9,
    key      = max(5, min(5.5, strip)),
    glossary = 9,
    title    = 13,
    axis     = strip
  )
}

# Ratios of each element to a single base size given in points.
.text_size_ratios <- function() {
  c(strip = 0.8, labels = 1.0, diagonal = 1.2, legend = 0.9, key = 0.75,
    glossary = 0.9, title = 1.3, axis = 0.8)
}

# Resolve style$text_size at variable count k to a named list of points,
# NA where the text is not drawn.
.resolve_text_pt <- function(k, text_size = "auto") {
  auto <- .text_size_auto(k)
  if (is.null(text_size)) {
    return(lapply(auto, function(v) NA_real_))
  }
  if (identical(text_size, "auto")) return(auto)
  if (is.numeric(text_size)) {
    return(as.list(text_size * .text_size_ratios()))
  }
  out <- auto
  for (nm in names(text_size)) {
    v <- text_size[[nm]]
    out[[nm]] <- if (is.null(v)) {
      NA_real_
    } else if (identical(v, "auto")) {
      auto[[nm]]
    } else {
      v
    }
  }
  out
}

.cell_text_sizes <- function(k, text_size = "auto") {
  pt <- .resolve_text_pt(k, text_size)
  strip <- pt$strip
  list(
    pt     = pt,
    n_edf  = strip / 2,
    glyph  = strip * 4.6 / 8,
    asym   = strip * 3.8 / 8,
    shape  = strip * 6.0 / 8,
    empty  = strip * 3.2 / 8,
    diag   = pt$diagonal / ggplot2::.pt
  )
}

# ggplot2 element_text of size `pt` points, or element_blank() when the
# text is not drawn.
.element_text_or_blank <- function(pt, ...) {
  if (is.na(pt)) return(ggplot2::element_blank())
  ggplot2::element_text(size = pt, ...)
}

# Linewidth of a coloured border: style$border_width points, or by
# default linewidth 2.4 at four variables scaled like the cell text with
# the variable count, never below linewidth 1.0.
.border_linewidth <- function(k, border_width = NULL) {
  if (!is.null(border_width)) return(border_width / ggplot2::.pt)
  max(1.0, 2.4 * .text_auto_scale(k) / .text_auto_scale(4L))
}

# ---------------------------------------------------------------
# Correlation background. A cell with correlation r is filled with the
# opaque colour abs(r) * strength of the way from white to the palette
# end of the sign of r; r = 0 is white.
# ---------------------------------------------------------------

.background_choices <- function() {
  c("pearson", "spearman", "kendall", "none")
}

.background_label <- function(background_by) {
  switch(background_by,
    pearson  = "Pearson r",
    spearman = "Spearman rho",
    kendall  = "Kendall tau",
    NULL
  )
}

# The correlation of a face under background_by; Pearson for "none".
.face_correlation <- function(face, background_by = "pearson") {
  value <- switch(background_by,
    spearman = face$cor_spearman,
    kendall  = face$cor_kendall,
    face$cor_pearson
  )
  as.numeric(value %||% NA_real_)
}

.background_hex <- function(r, palette = "BuOr", strength = 0.35) {
  eps <- .brewer_divergent_endpoints(palette)
  vapply(r, function(v) {
    if (is.na(v)) return(NA_character_)
    end <- if (v < 0) eps[["low"]] else eps[["high"]]
    rgb <- grDevices::colorRamp(c("white", end))(min(1, abs(v)) * strength)
    grDevices::rgb(rgb[, 1L], rgb[, 2L], rgb[, 3L], maxColorValue = 255)
  }, character(1L))
}

# The colour bar of the background over [-1, 1], drawn from the same
# blended colours as the cells, labelled at -1, 0 and 1. The ticks span
# the bar, so the one at 0 is a thin dark line across it and those at -1
# and 1 fall on the frame.
.background_bar_breaks <- function() c(-1, 0, 1)

.build_background_bar <- function(background_by, palette, strength,
                                  text_pt = 9, family = "") {
  v <- seq(-1, 1, length.out = 201L)
  df <- data.frame(x = 1, v = c(-1, 1))
  bar_width <- grid::unit(0.9, "lines")
  ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$v)) +
    ggplot2::geom_point(ggplot2::aes(fill = .data$v), shape = 22, size = 0,
                        stroke = 0, alpha = 0) +
    ggplot2::scale_fill_gradientn(
      colours = .background_hex(v, palette, strength),
      values  = (v + 1) / 2,
      limits  = c(-1, 1),
      breaks  = .background_bar_breaks(),
      labels  = c("-1", "0", "1"),
      name    = paste0("Background\n(", .background_label(background_by),
                       ")"),
      guide   = ggplot2::guide_colourbar(
        theme = ggplot2::theme(
          legend.title.position = "top",
          legend.title        = ggplot2::element_text(hjust = 0.5),
          legend.key.width    = bar_width,
          legend.ticks        = ggplot2::element_line(colour = "grey10",
                                                      linewidth = 0.4),
          legend.ticks.length = 0.5 * bar_width,
          legend.frame        = ggplot2::element_rect(colour = "grey50",
                                                      linewidth = 0.3)
        )
      )
    ) +
    ggplot2::theme_void(base_family = family) +
    ggplot2::theme(
      legend.position    = "left",
      legend.key.height  = grid::unit(1, "null"),
      legend.title       = .element_text_or_blank(
        text_pt, face = "bold", family = family,
        margin = ggplot2::margin(b = 4)
      ),
      legend.text        = .element_text_or_blank(text_pt, family = family),
      legend.margin      = ggplot2::margin(0, 0, 0, 0),
      legend.box.margin  = ggplot2::margin(0, 0, 0, 0),
      legend.box.spacing = grid::unit(0, "pt"),
      plot.margin        = ggplot2::margin(6, 0, 0, 4)
    )
}

# ---------------------------------------------------------------
# Axis transforms (Feature 3 -- rendering-only knob).
# Each transform exposes a function f(new_values) returning the
# transformed numeric vector and a `suffix` to append to the
# variable's border label. Same function is applied consistently
# to raw scatter, spline grid, and CI ribbon -- guaranteeing visual
# coherence regardless of compact tier or matrix dimension. The
# underlying GAM fit is NOT touched: this is a pure presentation
# layer, byte-identical fits across all four modes.
# ---------------------------------------------------------------

.axes_modes <- function() {
  c("original", "standardised", "centred", "rank")
}

.build_axis_transform <- function(raw, mode = "original") {
  mode <- match.arg(mode, .axes_modes())
  raw_clean <- raw[is.finite(raw)]
  n_raw <- length(raw_clean)
  switch(mode,
    original = list(
      fn     = function(x) x,
      suffix = ""
    ),
    standardised = {
      mu <- if (n_raw > 0L) mean(raw_clean) else 0
      sd <- if (n_raw > 1L) stats::sd(raw_clean) else 1
      if (!is.finite(sd) || sd <= 0) sd <- 1
      list(
        fn     = function(x) (x - mu) / sd,
        suffix = " (z)"
      )
    },
    centred = {
      mu <- if (n_raw > 0L) mean(raw_clean) else 0
      list(
        fn     = function(x) x - mu,
        suffix = " (centred)"
      )
    },
    rank = {
      # ecdf-based rank for any new value, including grid points
      # not in raw. Multiply by n to get rank-like 1..n integers.
      if (n_raw < 2L) {
        list(
          fn     = function(x) x,
          suffix = " (rank)"
        )
      } else {
        ec <- stats::ecdf(raw_clean)
        list(
          fn     = function(x) ec(x) * n_raw,
          suffix = " (rank)"
        )
      }
    }
  )
}

.label_with_suffix <- function(name, suffix, mode) {
  if (identical(mode, "rank")) {
    sprintf("rank(%s)", name)
  } else if (nzchar(suffix)) {
    paste0(name, suffix)
  } else {
    name
  }
}

# ---------------------------------------------------------------
# Compact-tier resolver. Decides per-cell content suppression based
# on n_var (= matrix dimension) and the user's `compact` setting.
# Returns an integer tier in 0:3 -- see PLAN_v011_features.md section 2.2
# for the pixel-budget rationale that anchors the thresholds.
# ---------------------------------------------------------------

.compact_tier <- function(n_var, compact = "auto", compact_threshold = 12L,
                          compact_levels = NULL) {
  compact <- match.arg(compact, c("auto", "always", "never"))
  if (compact == "never") return(0L)
  # Effective thresholds -- default ladder per Feature 2 plan;
  # overridable via compact_levels list (advanced knob).
  levels <- if (is.null(compact_levels)) {
    list(t1 = compact_threshold,
         t2 = compact_threshold + 6L,
         t3 = compact_threshold + 13L)
  } else {
    .validate_compact_levels(compact_levels, compact_threshold)
  }
  if (compact == "always") {
    # "always" forces at least tier 1; further ladder still kicks in by n_var.
    if (n_var >= levels$t3) return(3L)
    if (n_var >= levels$t2) return(2L)
    return(1L)
  }
  # "auto" -- tier from the ladder.
  if (n_var >= levels$t3) return(3L)
  if (n_var >= levels$t2) return(2L)
  if (n_var >= levels$t1) return(1L)
  0L
}

.validate_compact_levels <- function(levels, compact_threshold) {
  if (!is.list(levels)) {
    cli::cli_abort(
      "{.arg compact_levels} must be a named list with t1 / t2 / t3."
    )
  }
  required <- c("t1", "t2", "t3")
  missing <- setdiff(required, names(levels))
  if (length(missing)) {
    cli::cli_abort(c(
      "{.arg compact_levels} is missing entries: {.val {missing}}.",
      i = "Required: {.val {required}}."
    ))
  }
  for (nm in required) {
    v <- levels[[nm]]
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v < 2L) {
      cli::cli_abort(
        "{.arg compact_levels${nm}} must be a single integer >= 2."
      )
    }
  }
  if (!(levels$t1 < levels$t2 && levels$t2 < levels$t3)) {
    cli::cli_abort(
      "{.arg compact_levels} must satisfy t1 < t2 < t3."
    )
  }
  lapply(levels, as.integer)
}

# ---------------------------------------------------------------
# Focus filter. Returns a logical vector over the faces -- TRUE = cell
# is "in focus" (rendered with full encoding), FALSE = cell is dimmed
# (grey85 at alpha = style$focus_dim_alpha). Matrix shape is preserved
# either way.
# ---------------------------------------------------------------

.focus_choices <- function() {
  c("asymmetry", "edf", "k_flag", "non_linearity", "none")
}

# NA (no filter) or one of the focus metrics.
.check_focus_by <- function(focus_by, call = rlang::caller_env()) {
  if (length(focus_by) != 1L) {
    cli::cli_abort(
      "{.arg focus_by} must be a single value (NA or a metric name).",
      call = call
    )
  }
  if (is.na(focus_by)) return(NA_character_)
  choices <- .focus_choices()
  if (!focus_by %in% choices) {
    cli::cli_abort(c(
      "Unknown {.arg focus_by} value: {.val {focus_by}}.",
      i = "Allowed: NA or {.val {choices}}."
    ), call = call)
  }
  focus_by
}

# `faces` is a list of directed cells (see .pair_face()); each needs
# `edf`, `asymmetry_index` and `k_flag` for the metric in use.
.resolve_focus_mask <- function(faces, focus_by, focus_threshold = "q90") {
  if (is.null(focus_by) || is.na(focus_by) || identical(focus_by, "none")) {
    return(rep(TRUE, length(faces)))
  }
  vals <- vapply(faces, function(f) {
    switch(focus_by,
      asymmetry      = as.numeric(f$asymmetry_index %||% NA_real_),
      edf            = as.numeric(f$edf %||% NA_real_),
      non_linearity  = {
        v <- as.numeric(f$edf %||% NA_real_)
        if (is.na(v)) NA_real_ else v - 1
      },
      k_flag         = if (isTRUE(f$k_flag)) 1 else 0,
      NA_real_
    )
  }, numeric(1L))
  if (all(is.na(vals))) return(rep(TRUE, length(faces)))
  cutoff <- if (is.character(focus_threshold) &&
                grepl("^q[0-9]{1,2}$", focus_threshold)) {
    q <- as.numeric(sub("^q", "", focus_threshold)) / 100
    stats::quantile(vals, probs = q, na.rm = TRUE, names = FALSE)
  } else if (is.numeric(focus_threshold) && length(focus_threshold) == 1L) {
    focus_threshold
  } else {
    cli::cli_abort(
      "{.arg focus_threshold} must be a quantile string like {.val q90} or a single numeric."
    )
  }
  vals >= cutoff
}

# ---------------------------------------------------------------
# One directed cell of a pair: the `_yx` or `_xy` fields of a pair
# element under direction-free names, plus the pair-level quantities.
# `yx` is vars[j] ~ s(vars[i]) with x = var_i, drawn at row var_j and
# column var_i; `xy` is vars[i] ~ s(vars[j]) with x = var_j, drawn at row
# var_i and column var_j. Every cell is row ~ s(column).
# ---------------------------------------------------------------

.pair_face <- function(pair, direction = c("yx", "xy")) {
  direction <- rlang::arg_match(direction)
  field <- function(name) pair[[paste0(name, "_", direction)]]
  swap <- direction == "xy"
  list(
    direction              = direction,
    var_x                  = if (swap) pair$var_j else pair$var_i,
    var_y                  = if (swap) pair$var_i else pair$var_j,
    pred                   = field("pred"),
    partial                = field("partial"),
    deriv                  = field("deriv"),
    edf                    = field("edf"),
    association_p          = field("association_p"),
    association_p_adj      = field("association_p_adj"),
    dev_exp                = field("dev_exp"),
    deviance_gap           = field("deviance_gap"),
    directional_complexity = field("directional_complexity"),
    shape                  = field("shape"),
    shape_code             = field("shape_code"),
    k_capped               = isTRUE(field("k_capped")),
    k_flag                 = isTRUE(field("k_check")$k_flag),
    error                  = field("error"),
    n_used                 = pair$n_used,
    asymmetry_index        = pair$asymmetry_index,
    pair_not_significant   = .pair_not_significant(pair),
    cor_pearson            = pair$cor_pearson,
    cor_spearman           = pair$cor_spearman,
    cor_kendall            = pair$cor_kendall
  )
}

# The face's partial residuals when the style asks for them, else NULL
# (raw points).
.face_partial <- function(face, style) {
  if (identical(style$adjusted_points, "raw")) return(NULL)
  face$partial
}

# The significance glyph of a face: from the adjusted p-value when the
# fit adjusted across the matrix, from the raw one otherwise.
.face_signif <- function(face, p_adjust = "none") {
  p <- if (identical(p_adjust, "none")) {
    face$association_p
  } else {
    face$association_p_adj
  }
  .pvalue_to_glyph(p)
}

# TRUE when the cell's p-value (adjusted when the fit adjusted) is 0.05 or more.
.face_not_significant <- function(face, p_adjust = "none") {
  p <- if (identical(p_adjust, "none")) {
    face$association_p
  } else {
    face$association_p_adj
  }
  is.finite(p) && p >= 0.05
}

.k_warn_glyph <- function(glyph_style = "ascii") {
  if (identical(glyph_style, "unicode")) "\u26A0" else "!"
}

# The dash shown in place of A when neither direction is significant. An
# en dash only under "unicode": the default pdf() device cannot encode it.
.a_dash <- function(glyph_style = "ascii") {
  if (identical(glyph_style, "unicode")) "\u2013" else "-"
}

# ---------------------------------------------------------------
# The strip: one line of small grey text above the data area, e.g.
# "A 0.32  EDF 2.4  **" or, compact, "A 0.32 E 2.4 **". NULL when no
# annotation applies to the face. `background_by` picks the correlation
# of the "r" annotation (Pearson when "none"), labelled "marginal r" when
# the fit is `adjusted`; `wrap` breaks the line after the third item.
# ---------------------------------------------------------------

.cell_strip_text <- function(face, annotations, glyph_style = "ascii",
                             compact = FALSE, p_adjust = "none",
                             background_by = "pearson", wrap = FALSE,
                             adjusted = FALSE) {
  parts <- character()
  if ("formula" %in% annotations) {
    parts <- c(parts, sprintf("%s ~ %s", face$var_y, face$var_x))
  }
  not_signif <- .face_not_significant(face, p_adjust)
  if ("code" %in% annotations && !is.na(face$shape_code)) {
    parts <- c(parts, face$shape_code)
    if (not_signif) parts <- c(parts, "n.s.")
  }
  if ("A" %in% annotations && !is.na(face$asymmetry_index)) {
    # Neither direction significant: the index would compare two smooths
    # of noise, so the strip shows a dash in its place.
    parts <- c(parts, if (isTRUE(face$pair_not_significant)) {
      paste("A", .a_dash(glyph_style))
    } else {
      sprintf("A %.2f", face$asymmetry_index)
    })
  }
  if ("edf" %in% annotations && !is.na(face$edf)) {
    parts <- c(parts, sprintf(if (compact) "E %.1f" else "EDF %.1f", face$edf))
  }
  # Adding 0 prints a value that rounds to -0 as 0.00.
  r <- .face_correlation(face, background_by)
  if ("r" %in% annotations && !is.na(r)) {
    parts <- c(parts, sprintf(if (adjusted) "marginal r %.2f" else "r %.2f",
                             round(r, 2L) + 0))
  }
  if ("n" %in% annotations && !is.na(face$n_used)) {
    parts <- c(parts, sprintf("n %d", as.integer(face$n_used)))
  }
  if ("signif" %in% annotations) {
    glyph <- .face_signif(face, p_adjust)
    if (nzchar(glyph)) parts <- c(parts, glyph)
  }
  if ("shape" %in% annotations && !is.na(face$shape)) {
    glyph <- .shape_glyph(face$shape, style = glyph_style)
    if (!is.na(glyph) && nzchar(glyph)) {
      parts <- c(parts, glyph)
      if (not_signif && !"n.s." %in% parts) parts <- c(parts, "n.s.")
    }
  }
  if ("k_warn" %in% annotations && (face$k_flag || face$k_capped)) {
    parts <- c(parts, .k_warn_glyph(glyph_style))
  }
  if (!length(parts)) return(NULL)
  sep <- if (compact) " " else "  "
  if (wrap && length(parts) > 3L) {
    return(paste(paste(parts[1:3], collapse = sep),
                 paste(parts[-(1:3)], collapse = sep), sep = "\n"))
  }
  paste(parts, collapse = sep)
}

# ---------------------------------------------------------------
# Cell theme: square panel, the background colour (NA for none), a
# border that carries the cell's colour when the channel is "border",
# the strip as the subtitle left-aligned to the panel. `strip_pt` NA
# removes the title and the strip.
# ---------------------------------------------------------------

.cell_theme <- function(strip_pt, border_colour = "grey55",
                        border_linewidth = 0.35, background = NA,
                        family = "") {
  ggplot2::theme_void(base_size = 8, base_family = family) +
    ggplot2::theme(
      aspect.ratio        = 1,
      plot.margin         = ggplot2::margin(3, 3, 3, 3),
      plot.background     = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background    = ggplot2::element_rect(fill = background,
                                                  colour = NA),
      panel.border        = ggplot2::element_rect(
        fill = NA, colour = border_colour, linewidth = border_linewidth
      ),
      plot.title.position = "panel",
      plot.title          = .element_text_or_blank(
        strip_pt + 1, colour = "grey15", hjust = 0, family = family,
        margin = ggplot2::margin(0, 0, 1, 0)
      ),
      plot.subtitle       = .element_text_or_blank(
        strip_pt, colour = "grey35", hjust = 0, family = family,
        margin = ggplot2::margin(0, 0, 1.5, 0)
      )
    )
}

# The grey85 wash of an out-of-focus cell.
.dim_wash_layer <- function(alpha) {
  ggplot2::annotate(
    "rect", xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf,
    fill = "grey85", alpha = alpha
  )
}

# The bottom-right corner tile of the "tile" channel, 12 % of the panel.
.corner_tile_layer <- function(colour) {
  ggplot2::annotation_custom(grid::rectGrob(
    x = grid::unit(1, "npc"), y = grid::unit(0, "npc"),
    just = c("right", "bottom"),
    width = grid::unit(0.12, "npc"), height = grid::unit(0.12, "npc"),
    gp = grid::gpar(fill = colour, col = "white", lwd = 0.6)
  ))
}

# The raw points of a cell: grey points, points coloured by group, or a
# light grey binned density when the cell has more rows than
# style$density_threshold and no grouping.
.cell_points_layer <- function(points, style, group_colours = NULL,
                               n_used = nrow(points)) {
  if (is.null(group_colours) && isTRUE(n_used > style$density_threshold)) {
    return(list(
      ggplot2::geom_bin2d(
        data = points, ggplot2::aes(x = .data$x, y = .data$y),
        bins = 40L
      ),
      ggplot2::scale_fill_gradient(low = "grey94", high = "grey45",
                                   guide = "none")
    ))
  }
  if (is.null(group_colours)) {
    return(ggplot2::geom_point(
      data = points, ggplot2::aes(x = .data$x, y = .data$y),
      colour = "grey25", size = style$point_size, alpha = style$point_alpha,
      inherit.aes = FALSE
    ))
  }
  # Coloured points keep an opacity of at least 0.5 so the group colours
  # stay legible against each other.
  list(
    ggplot2::geom_point(
      data = points,
      ggplot2::aes(x = .data$x, y = .data$y, colour = .data$group),
      size = style$point_size, alpha = max(style$point_alpha, 0.5),
      inherit.aes = FALSE
    ),
    ggplot2::scale_colour_manual(values = group_colours, na.value = "grey70",
                                 guide = "none")
  )
}

# The 0.2.0 corner placement of the annotations, used when
# style$annotation_position = "corners".
.add_corner_annotations <- function(p, face, annotations, style, text_sizes,
                                    p_adjust = "none",
                                    background_by = "pearson",
                                    adjusted = FALSE) {
  if (is.na(text_sizes$pt$strip)) return(p)
  family <- style$base_family

  # Top-right: significance glyph.
  if ("signif" %in% annotations) {
    glyph <- .face_signif(face, p_adjust)
    if (nzchar(glyph)) {
      p <- p + ggplot2::annotate(
        "text", x = Inf, y = Inf, hjust = 1.25, vjust = 1.4,
        label = glyph, size = text_sizes$glyph, fontface = "bold",
        family = family
      )
    }
  }

  # Bottom-left stack: formula, A, EDF, r and n, one line each.
  bl_lines <- character()
  if ("formula" %in% annotations) {
    bl_lines <- c(bl_lines, sprintf("%s ~ %s", face$var_y, face$var_x))
  }
  if ("A" %in% annotations && !is.na(face$asymmetry_index)) {
    bl_lines <- c(bl_lines, if (isTRUE(face$pair_not_significant)) {
      paste("A =", .a_dash(style$glyph_style))
    } else {
      sprintf("A = %.2f", face$asymmetry_index)
    })
  }
  if ("edf" %in% annotations && !is.na(face$edf)) {
    bl_lines <- c(bl_lines, sprintf("EDF = %.2f", face$edf))
  }
  r <- .face_correlation(face, background_by)
  if ("r" %in% annotations && !is.na(r)) {
    r_fmt <- if (adjusted) "marginal r = %.2f" else "r = %.2f"
    bl_lines <- c(bl_lines, sprintf(r_fmt, round(r, 2L) + 0))
  }
  if ("n" %in% annotations && !is.na(face$n_used)) {
    bl_lines <- c(bl_lines, sprintf("n = %d", as.integer(face$n_used)))
  }
  if (length(bl_lines)) {
    p <- p + ggplot2::annotate(
      "text", x = -Inf, y = -Inf,
      hjust = -0.07, vjust = -0.15,
      label = paste(bl_lines, collapse = "\n"),
      size = text_sizes$n_edf, lineheight = 0.95,
      colour = "grey15", fontface = "plain", family = family
    )
  }

  # Top-left: 2-letter shape code.
  want_code <- "code" %in% annotations && !is.na(face$shape_code)
  not_signif <- .face_not_significant(face, p_adjust)
  if (want_code) {
    p <- p + ggplot2::annotate(
      "text", x = -Inf, y = Inf,
      hjust = -0.20, vjust = 1.4,
      label = if (not_signif) paste(face$shape_code, "n.s.") else face$shape_code,
      size = text_sizes$n_edf,
      colour = "grey20", fontface = "bold", family = family
    )
  }

  # Bottom-right: shape glyph.
  if ("shape" %in% annotations && !is.na(face$shape)) {
    glyph <- .shape_glyph(face$shape, style = style$glyph_style)
    if (!is.na(glyph) && nzchar(glyph)) {
      p <- p + ggplot2::annotate(
        "text", x = Inf, y = -Inf,
        hjust = 1.15, vjust = -0.25,
        label = if (not_signif && !want_code) paste("n.s.", glyph) else glyph,
        size = text_sizes$shape,
        colour = "grey25", fontface = "bold", family = family
      )
    }
  }

  # Top-left beside the code: k-check warning on flagged or capped cells.
  if ("k_warn" %in% annotations && (face$k_flag || face$k_capped)) {
    p <- p + ggplot2::annotate(
      "text", x = -Inf, y = Inf,
      hjust = if (want_code) -1.30 else -0.20,
      vjust = 1.4,
      label = .k_warn_glyph(style$glyph_style),
      size = text_sizes$n_edf,
      colour = "#b30000", fontface = "bold", family = family
    )
  }
  p
}

# ---------------------------------------------------------------
# Off-diagonal cell. One ggplot for one direction of one pair: the
# strip, the raw points, the band and the curve, the colour channel,
# the focus wash and the compact-tier suppression. `points` is a data
# frame with `x`, `y` and optionally `group` for the rows of the cell;
# `colour` is the hex colour of the cell's colour_by value or NA;
# `background` the hex colour of its correlation background or NA.
# ---------------------------------------------------------------

.render_cell <- function(
  pair,
  direction,
  points,
  style,
  text_sizes,
  annotations = c("A", "signif"),
  display = "fit",
  p_adjust = "none",
  colour = NA_character_,
  tier = 0L,
  is_focused = TRUE,
  group_colours = NULL,
  x_transform = NULL,
  y_transform = NULL,
  title = NULL,
  background = NA_character_,
  border_linewidth = .border_linewidth(4L, style$border_width),
  background_by = "pearson",
  wrap_strip = FALSE,
  adjusted = FALSE
) {
  face <- .pair_face(pair, direction)
  tier <- as.integer(tier)
  if (!isTRUE(is_focused)) colour <- NA_character_
  if (display != "fit") {
    return(.build_deriv_panel(
      face, order = if (display == "d1") 1L else 2L,
      style = style, text_sizes = text_sizes, colour = colour,
      tier = tier, is_focused = is_focused, title = title,
      background = background, border_linewidth = border_linewidth
    ))
  }

  # Tier policy ----------------------------------------------------------
  # Suppression only removes detail: points at tier 1, the band at tier
  # 2, the curve and the strip at tier 3. The strip is compact from tier
  # 1 on.
  show_data   <- isTRUE(style$show_data) && tier < 1L
  show_ci     <- isTRUE(style$show_ci) && tier < 2L
  show_spline <- tier < 3L
  if (tier >= 3L) annotations <- character()
  compact <- tier >= 1L
  tf_x <- if (is.null(x_transform)) function(v) v else x_transform$fn
  tf_y <- if (is.null(y_transform)) function(v) v else y_transform$fn

  # Panel, strip and colour channel ----------------------------------------
  on_border <- style$colour_channel == "border" && !is.na(colour)
  strip <- if (style$annotation_position == "strip") {
    .cell_strip_text(face, annotations, style$glyph_style, compact, p_adjust,
                     background_by, wrap = wrap_strip, adjusted = adjusted)
  } else {
    NULL
  }
  p <- ggplot2::ggplot() +
    .cell_theme(
      strip_pt = text_sizes$pt$strip,
      border_colour = if (on_border) colour else "grey55",
      border_linewidth = if (on_border) border_linewidth else 0.35,
      background = background,
      family = style$base_family
    ) +
    ggplot2::labs(title = title, subtitle = strip)
  if (!isTRUE(is_focused)) {
    p <- p + .dim_wash_layer(style$focus_dim_alpha)
  }
  if (style$colour_channel == "fill" && !is.na(colour)) {
    p <- p + ggplot2::annotate(
      "rect", xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf,
      fill = colour, alpha = 0.45
    )
  }
  if (style$colour_channel == "tile" && !is.na(colour)) {
    p <- p + .corner_tile_layer(colour)
  }

  # Empty cell: a failed fit or fewer than 5 shared rows -----------------
  if (nrow(face$pred) == 0L) {
    label <- if (!is.na(face$error)) "no fit" else "n < 5"
    return(.empty_cell_text(p, label, text_sizes, style$base_family))
  }

  # Data, band and curve ---------------------------------------------------
  if (show_data && nrow(points) > 0L) {
    points$x <- tf_x(points$x)
    points$y <- tf_y(points$y)
    p <- p + .cell_points_layer(points, style, group_colours,
                                n_used = face$n_used)
  }
  if (show_ci) {
    pred_ci <- face$pred
    pred_ci$x  <- tf_x(pred_ci$x)
    pred_ci$lo <- tf_y(pred_ci$lo)
    pred_ci$hi <- tf_y(pred_ci$hi)
    p <- p + ggplot2::geom_ribbon(
      data = pred_ci,
      ggplot2::aes(x = .data$x, ymin = .data$lo, ymax = .data$hi),
      fill = style$curve_colour, alpha = style$band_alpha,
      inherit.aes = FALSE
    )
  }
  if (show_spline) {
    pred_line <- face$pred
    pred_line$x   <- tf_x(pred_line$x)
    pred_line$fit <- tf_y(pred_line$fit)
    p <- p + ggplot2::geom_line(
      data = pred_line,
      ggplot2::aes(x = .data$x, y = .data$fit),
      colour = style$curve_colour,
      linewidth = style$curve_width / ggplot2::.pt,
      inherit.aes = FALSE
    )
  } else if (isTRUE(is_focused)) {
    # Tier 3: the shape glyph in the cell centre stands for the curve.
    glyph <- .shape_glyph(face$shape, style = style$glyph_style)
    if (!is.na(glyph) && nzchar(glyph) && !is.na(text_sizes$shape)) {
      p <- p + ggplot2::annotate(
        "text", x = 0.5, y = 0.5,
        label = glyph, size = text_sizes$shape * 1.2,
        colour = "grey20", fontface = "bold", family = style$base_family
      ) + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
    }
  }

  # Corner annotations -----------------------------------------------------
  if (style$annotation_position == "corners" && length(annotations)) {
    p <- .add_corner_annotations(p, face, annotations, style, text_sizes,
                                 p_adjust, background_by, adjusted)
  }
  p
}

# The centred grey label of an empty cell ("no fit", "n < 5"), or the
# empty panel alone when the strip text is not drawn.
.empty_cell_text <- function(p, label, text_sizes, family = "") {
  if (!is.na(text_sizes$empty)) {
    p <- p + ggplot2::annotate(
      "text", x = 0.5, y = 0.5, label = label,
      size = text_sizes$empty, colour = "grey40", family = family
    )
  }
  p + ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1)
}

# ---------------------------------------------------------------
# Derivative cell. Renders f^{(k)}(x) on the full x-grid with its band
# (when the fit stored one and the style shows bands) and a dashed zero
# line that is always inside the panel's y-range. No points. The strip
# names the order and n.
# ---------------------------------------------------------------

.deriv_order_label <- function(order, style = c("ascii", "unicode")) {
  style <- rlang::arg_match(style)
  order <- as.integer(order)
  if (!is.finite(order) || order < 1L) return("")
  if (style == "unicode") {
    if (order == 1L) return("f\u2032")          # f'
    if (order == 2L) return("f\u2033")          # f''
    return(paste0("f", strrep("\u2032", order)))
  }
  # ASCII fallback: d1f/dx, d2f/dx2, ...
  if (order == 1L) return("df/dx")
  if (order == 2L) return("d2f/dx2")
  sprintf("d%df/dx%d", order, order)
}

.build_deriv_panel <- function(face, order, style, text_sizes,
                               colour = NA_character_, tier = 0L,
                               is_focused = TRUE, title = NULL,
                               background = NA_character_,
                               border_linewidth = 1.2) {
  tier <- as.integer(tier)
  # Tiers 0-1: curve and band; tier 2: curve only; tier 3: no strip.
  show_ribbon <- isTRUE(style$show_ci) && tier < 2L
  show_strip  <- tier < 3L
  on_border <- style$colour_channel == "border" && !is.na(colour)
  strip <- NULL
  if (show_strip) {
    parts <- .deriv_order_label(order, style = style$glyph_style)
    if (!is.na(face$n_used)) {
      parts <- c(parts, sprintf("n %d", as.integer(face$n_used)))
    }
    strip <- paste(parts, collapse = "  ")
  }
  p <- ggplot2::ggplot() +
    .cell_theme(
      strip_pt = text_sizes$pt$strip,
      border_colour = if (on_border) colour else "grey55",
      border_linewidth = if (on_border) border_linewidth else 0.35,
      background = background,
      family = style$base_family
    ) +
    ggplot2::labs(title = title, subtitle = strip)
  if (!isTRUE(is_focused)) {
    p <- p + .dim_wash_layer(style$focus_dim_alpha)
  }
  if (style$colour_channel == "fill" && !is.na(colour)) {
    p <- p + ggplot2::annotate(
      "rect", xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf,
      fill = colour, alpha = 0.45
    )
  }
  if (style$colour_channel == "tile" && !is.na(colour)) {
    p <- p + .corner_tile_layer(colour)
  }

  deriv_df <- face$deriv[[as.character(as.integer(order))]]
  if (is.null(deriv_df) || nrow(deriv_df) == 0L) {
    return(.empty_cell_text(
      p, sprintf("deriv %d unavailable", as.integer(order)), text_sizes,
      style$base_family
    ))
  }

  # Reference line at zero -- sign flips of the derivative correspond
  # to turning points (k=1) or inflections (k=2), so the zero crossing
  # is the feature of interest the panel exists to surface. The y-range
  # is expanded to include it even when the curve and band sit entirely
  # on one side.
  p <- p + ggplot2::geom_hline(
    yintercept = 0, linetype = "dashed", colour = "grey50",
    linewidth = 0.3
  ) + ggplot2::expand_limits(y = 0)

  # The band is drawn when the fit stored one (ci_type other than
  # "none"); pointwise or simultaneous was resolved at fit time.
  ci_type <- deriv_df$ci_type[1L] %||% "none"
  if (show_ribbon && !identical(ci_type, "none") &&
      all(c("lo", "hi") %in% names(deriv_df)) &&
      all(is.finite(deriv_df$lo)) && all(is.finite(deriv_df$hi))) {
    p <- p + ggplot2::geom_ribbon(
      data = deriv_df,
      ggplot2::aes(x = .data$x, ymin = .data$lo, ymax = .data$hi),
      fill = "#6a3d9a", alpha = 0.20, inherit.aes = FALSE
    )
  }
  p + ggplot2::geom_line(
    data = deriv_df,
    ggplot2::aes(x = .data$x, y = .data$fit),
    colour = "#6a3d9a", linewidth = 0.6, inherit.aes = FALSE
  )
}

# ---------------------------------------------------------------
# Blank diagonal cell -- used when labels live on the border (or are
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
# Border-label cells -- variable names in the top strip (rotated)
# and left strip (horizontal, right-aligned). Mirrors corrplot's
# tl.pos = "lt" convention. No panel border, no aspect ratio;
# widths / heights are set by the assembly layer.
# ---------------------------------------------------------------

.build_top_label_cell <- function(label, srt = 45, size_pt = 10, family = "") {
  hj <- if (identical(srt, 0)) 0.5 else 0
  vj <- if (identical(srt, 0)) 0 else 0.5
  p <- ggplot2::ggplot()
  if (!is.na(size_pt)) {
    p <- p + ggplot2::annotate(
      "text", x = 0.5, y = 0,
      label = label, angle = srt,
      hjust = hj, vjust = vj,
      size = size_pt / ggplot2::.pt, colour = "grey10", family = family
    )
  }
  p +
    ggplot2::xlim(0, 1) + ggplot2::ylim(0, 1) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::theme_void(base_size = 8) +
    ggplot2::theme(
      plot.margin      = ggplot2::margin(3, 3, 3, 3),
      plot.background  = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background = ggplot2::element_rect(fill = NA, colour = NA)
    )
}

.build_left_label_cell <- function(label, size_pt = 10, family = "") {
  p <- ggplot2::ggplot()
  if (!is.na(size_pt)) {
    p <- p + ggplot2::annotate(
      "text", x = 1, y = 0.5,
      label = label,
      hjust = 1, vjust = 0.5,
      size = size_pt / ggplot2::.pt, colour = "grey10", family = family
    )
  }
  p +
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
# Corner key: a two-by-two schematic of the first two variables in the
# empty top-left corner, headed "each cell: row ~ s(column)". The
# off-diagonal boxes carry the formula on two lines, the diagonal boxes
# are grey. When either name is longer than .key_name_chars() the key
# reads v1 and v2, since a cut name tells the reader nothing. Sizes are
# in points, with text width estimated at 0.5 em per character; the
# assembly sizes the corner from .key_layout().
# ---------------------------------------------------------------

.key_name_chars <- function() 7L

.key_heading <- function() "each cell:\nrow ~ s(column)"

.key_names <- function(vars, max_chars = .key_name_chars()) {
  ab <- c(vars[[1L]], vars[[2L]])
  if (any(nchar(ab) > max_chars)) c("v1", "v2") else ab
}

# The key names and the geometry of the key at `key_pt`, in points.
.key_layout <- function(vars, key_pt) {
  ab <- .key_names(vars)
  a <- ab[[1L]]
  b <- ab[[2L]]
  em <- 0.5 * key_pt
  line <- 1.2 * key_pt
  row_w <- max(nchar(c(a, b))) * em + 0.5 * key_pt
  box_w <- (max(nchar(c(a, b))) + 3L) * em + 0.6 * key_pt
  box_h <- 2 * line + 0.4 * key_pt
  heading_w <- max(nchar(strsplit(.key_heading(), "\n", fixed = TRUE)[[1L]]))
  list(
    a = a, b = b, row_w = row_w, box_w = box_w, box_h = box_h,
    line = line,
    width = max(row_w + 2 * box_w, heading_w * em),
    height = 3 * line + 2 * box_h
  )
}

# The key drawn in a corner panel of `panel_w` x `panel_h` points,
# anchored to its bottom-right corner, beside the first matrix cell.
.build_key_cell <- function(vars, key_pt, panel_w, panel_h, family = "") {
  if (length(vars) < 2L || is.na(key_pt)) return(.build_corner_cell())
  lay <- .key_layout(vars, key_pt)
  x_box <- panel_w - 2 * lay$box_w
  box_h <- lay$box_h
  boxes <- data.frame(
    xmin = x_box + c(0, 1, 0, 1) * lay$box_w,
    ymin = c(1, 1, 0, 0) * box_h,
    fill = c("grey92", NA, NA, "grey92"),
    stringsAsFactors = FALSE
  )
  boxes$xmax <- boxes$xmin + lay$box_w
  boxes$ymax <- boxes$ymin + box_h
  texts <- data.frame(
    x = c(panel_w, x_box + 0.5 * lay$box_w, x_box + 1.5 * lay$box_w,
          x_box - 0.3 * key_pt, x_box - 0.3 * key_pt,
          x_box + 1.5 * lay$box_w, x_box + 0.5 * lay$box_w),
    y = c(2 * box_h + 3 * lay$line, rep(2 * box_h + 0.5 * lay$line, 2L),
          1.5 * box_h, 0.5 * box_h, 1.5 * box_h, 0.5 * box_h),
    label = c(.key_heading(), lay$a, lay$b, lay$a, lay$b,
              sprintf("%s ~\ns(%s)", lay$a, lay$b),
              sprintf("%s ~\ns(%s)", lay$b, lay$a)),
    hjust = c(1, 0.5, 0.5, 1, 1, 0.5, 0.5),
    vjust = c(1, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5),
    colour = c("grey10", rep("grey30", 4L), rep("grey15", 2L)),
    stringsAsFactors = FALSE
  )
  ggplot2::ggplot() +
    ggplot2::geom_rect(
      data = boxes,
      ggplot2::aes(xmin = .data$xmin, xmax = .data$xmax,
                   ymin = .data$ymin, ymax = .data$ymax),
      fill = boxes$fill, colour = "grey60", linewidth = 0.25,
      inherit.aes = FALSE
    ) +
    ggplot2::geom_text(
      data = texts,
      ggplot2::aes(x = .data$x, y = .data$y, label = .data$label),
      hjust = texts$hjust, vjust = texts$vjust, colour = texts$colour,
      size = key_pt / ggplot2::.pt, lineheight = 0.9, family = family,
      inherit.aes = FALSE
    ) +
    ggplot2::scale_x_continuous(limits = c(0, panel_w), expand = c(0, 0)) +
    ggplot2::scale_y_continuous(limits = c(0, panel_h), expand = c(0, 0)) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::theme_void(base_size = 8, base_family = family) +
    ggplot2::theme(
      plot.margin      = ggplot2::margin(0, 0, 0, 0),
      plot.background  = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background = ggplot2::element_rect(fill = NA, colour = NA)
    )
}

# ---------------------------------------------------------------
# Diagonal cell -- kernel density of the variable with a rug of raw
# values along the bottom edge. Mirrors the GGally::ggpairs default
# diagonal so readers can see tail weight, bimodality, support
# clipping, and any concentration of mass that would otherwise be
# invisible from the off-diagonal smooths alone.
# ---------------------------------------------------------------

.build_density_rug_cell <- function(var_name, x_values,
                                    text_sizes = .cell_text_sizes(3L)) {
  x <- x_values[is.finite(x_values)]
  if (length(x) < 5L) return(.build_blank_diagonal_cell())
  dens <- tryCatch(stats::density(x, na.rm = TRUE),
                   error = function(e) NULL)
  if (is.null(dens) || !length(dens$x)) {
    return(.build_blank_diagonal_cell())
  }
  dens_df <- data.frame(x = dens$x, y = dens$y)
  rug_df  <- data.frame(x = x)
  ggplot2::ggplot() +
    ggplot2::geom_area(
      data    = dens_df,
      mapping = ggplot2::aes(x = .data$x, y = .data$y),
      fill    = "grey55", colour = NA, alpha = 0.35,
      inherit.aes = FALSE
    ) +
    ggplot2::geom_line(
      data    = dens_df,
      mapping = ggplot2::aes(x = .data$x, y = .data$y),
      colour  = "grey20", linewidth = 0.45,
      inherit.aes = FALSE
    ) +
    ggplot2::geom_rug(
      data    = rug_df,
      mapping = ggplot2::aes(x = .data$x),
      sides   = "b", colour = "grey25",
      alpha   = 0.35, length = grid::unit(0.07, "npc"),
      inherit.aes = FALSE
    ) +
    ggplot2::theme_void(base_size = 8) +
    ggplot2::theme(
      aspect.ratio     = 1,
      plot.margin      = ggplot2::margin(3, 3, 3, 3),
      plot.background  = ggplot2::element_rect(fill = NA, colour = NA),
      panel.background = ggplot2::element_rect(fill = NA, colour = NA),
      panel.border     = ggplot2::element_rect(
        fill = NA, colour = "grey55", linewidth = 0.35
      )
    )
}

# ---------------------------------------------------------------
# Diagonal cell -- the variable name, bold, neutral grey background.
# Used when style$diagonal = "name".
# ---------------------------------------------------------------

.build_diagonal_cell <- function(var_name,
                                 text_sizes = .cell_text_sizes(3L),
                                 family = "") {
  char_scale <- min(1, 10 / max(1L, nchar(var_name)))
  label_size <- text_sizes$diag * char_scale
  p <- ggplot2::ggplot()
  if (!is.na(label_size)) {
    p <- p + ggplot2::annotate(
      "text", x = 0.5, y = 0.5, label = var_name,
      size = label_size, fontface = "bold", colour = "grey10",
      family = family
    )
  }
  p +
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
