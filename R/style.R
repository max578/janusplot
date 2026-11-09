# style.R -- The janusplot_style object: every appearance knob of the matrix
# and pair views, validated at construction, with a print() method that
# lists the values changed from their defaults. plot.janusplot_fit() and
# janusplot() take it as `style`; the renderers in internal-cell.R and
# internal-assemble.R read it.

#' Appearance settings for janusplot views
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Collects every appearance knob of [plot.janusplot_fit()],
#' [janusplot_pair()] and [janusplot()] into one validated object. Model
#' settings live in [janusplot_fit()], what the matrix encodes lives in
#' `plot()`'s `colour_by`, `background_by` and `annotations`, and how it is
#' drawn lives here.
#'
#' @details
#' The default cell has a thick panel border carrying the `colour_by`
#' value, a background tinted by the pair's signed correlation (white at
#' zero, `background_strength` of the way to the palette's negative or
#' positive end at minus or plus one), a thin strip above the data area with the
#' annotations in small grey text, grey points behind a dark blue curve
#' with a 20 percent band, and, for cells with more than
#' `density_threshold` rows, a light grey binned density in place of the
#' points. A key in the empty top-left corner states the convention of
#' every cell, `row ~ s(column)`.
#'
#' `text_size` sets every text of the view. `"auto"` scales the strip and
#' the diagonal names with the variable count and keeps the strip at 5
#' points or more. A single number is a base size in points: the strip and
#' the axis text are 0.8 of it, the border labels 1.0, the diagonal names
#' 1.2, the legends and the glossary 0.9, the corner key 0.75 and the
#' title 1.3. A named list sets elements one by one: `strip` (the strip
#' and the in-panel annotations), `labels` (the border variable names),
#' `diagonal` (the names on the diagonal), `legend` (the colour bars and
#' the group legend), `key` (the corner key), `glossary` (the caption),
#' `title` (the title) and `axis` (the axes of the pair view). Each element
#' is a size in points, `"auto"`, or `NULL`, which removes that text;
#' elements not named stay `"auto"`. `text_size = NULL` removes every text.
#'
#' Widths are in points, as for text: a width `w` is drawn as the ggplot2
#' linewidth `w / ggplot2::.pt`. `border_width = NULL` scales the border
#' with the variable count: 6.8 points (linewidth 2.4) at four variables,
#' thicker for fewer, thinner for more, and never below 2.8 points
#' (linewidth 1.0).
#'
#' `colour_channel = "fill"` with `colour_by = "pearson"` and
#' `background_by = "none"` reproduces the 0.2.0 look.
#'
#' @param colour_channel Where the `colour_by` value is painted:
#'   `"border"` (the default) colours the panel border, `"tile"` fills a
#'   small bottom-right corner tile and leaves the border grey, `"fill"`
#'   washes the whole cell at alpha 0.45 and needs `background_by =
#'   "none"`.
#' @param palette Name of the colour palette for the `colour_by` scale, or
#'   `NULL` (the default) for `"RdBu"` when `colour_by` is a correlation
#'   and `"viridis"` otherwise. Sequential choices: `"viridis"`,
#'   `"magma"`, `"inferno"`, `"plasma"`, `"cividis"`, `"mako"`, `"rocket"`,
#'   `"turbo"` (not colour-blind safe), `"YlOrRd"`, `"YlGnBu"`, `"Blues"`,
#'   `"Greens"`. Diverging choices: `"RdYlBu"`, `"RdBu"`, `"PuOr"`,
#'   `"Spectral"` (not colour-blind safe). A sequential palette under a
#'   correlation `colour_by` is replaced by `"RdBu"`.
#' @param background_palette Diverging palette of the correlation
#'   background, one of `"BuOr"` (the default: blue negative, orange
#'   positive; its two sides stay the furthest apart under simulated
#'   red-green and blue-yellow colour-vision deficiency), `"RdBu"` (blue
#'   negative, red positive), `"RdYlBu"`, `"PuOr"` and `"Spectral"`.
#' @param background_strength Number in `(0, 1]`, `0.35` by default: how
#'   far from white towards the palette end the background of a cell with
#'   correlation of magnitude one is drawn. A cell with correlation `r` is
#'   drawn `abs(r) * background_strength` of the way, as an opaque colour.
#' @param annotation_position Where the `annotations` of `plot()` are
#'   written: `"strip"` (the default) in a thin strip above the data area,
#'   `"corners"` inside the panel where 0.2.0 placed them (A, EDF, r and n
#'   bottom-left, significance top-right, shape code top-left, shape
#'   glyph bottom-right).
#' @param show_data Logical. `TRUE` (the default) draws the raw points of
#'   each cell behind the curve on fit cells; derivative cells never
#'   carry points.
#' @param adjusted_points Points of a fit with `adjust`: `"partial"` (the
#'   default) draws partial residuals, each observation with its own
#'   adjustment replaced by the average adjustment, so the points sit
#'   around the curve as they do without adjustment; `"raw"` draws the
#'   observed values. Partial residuals need the identity link; with
#'   another link the points stay raw.
#' @param identity_line Logical. `TRUE` adds the dashed line `y = x` to
#'   the z-score panels of [janusplot_pair()] with `display = "both"`.
#'   There it is the standard-deviation line: a curve flatter than it,
#'   read along its own predictor axis, regresses towards the mean.
#'   `FALSE` (the default) leaves it out.
#' @param show_ci Logical. `TRUE` (the default) draws the 95 percent band
#'   around the curve, and around a derivative curve when the fit stored
#'   one.
#' @param point_size Size of the raw points; `0.4` by default.
#' @param point_alpha Opacity of the raw points in `[0, 1]`; `0.25` by
#'   default.
#' @param curve_colour Colour of the fitted curve and its band; the dark
#'   blue `"#08306b"` by default.
#' @param curve_width Width of the fitted curve in points; `2` by default.
#' @param band_alpha Opacity of the band in `[0, 1]`; `0.20` by default.
#' @param border_width Width in points of a border that carries a colour,
#'   or `NULL` (the default) for the width scaled with the variable count
#'   described in Details.
#' @param density_threshold Positive integer. A cell whose row count
#'   exceeds it draws the points as a binned density
#'   ([ggplot2::geom_bin2d()] with 40 bins) instead of points; `2000L` by
#'   default. Cells coloured by `group` always draw points.
#' @param group_palette Colours for the levels of `plot()`'s `group`
#'   column: the name of a palette known to
#'   [grDevices::palette.colors()] (`"Okabe-Ito"` by default) or a
#'   character vector of colours with at least one colour per level.
#' @param group_max_levels Positive integer. The largest number of levels
#'   a `group` column may have; `8L` by default.
#' @param labels Where variable names are drawn: `"border"` (the default)
#'   along the top and left margins, `"none"` nowhere.
#' @param label_srt Rotation in degrees of the top border labels; `45` by
#'   default.
#' @param diagonal Content of the diagonal cells: `"auto"` (the default)
#'   and `"blank"` leave them empty, `"name"` writes the variable name,
#'   `"density"` draws a kernel density with a rug of the raw values.
#' @param glyph_style `"ascii"` (the default) or `"unicode"` for the shape
#'   glyphs, the derivative order labels and the k-check warning sign.
#' @param show_shape_legend `"auto"` (the default) attaches the
#'   shape-categories legend below the matrix when the cells carry the
#'   two-letter shape code it decodes (`annotations` includes `"code"`);
#'   `TRUE` always attaches it, `FALSE` never.
#' @param show_glossary Logical. `TRUE` (the default) attaches a caption
#'   describing the abbreviations and encodings on the plot.
#' @param show_key Logical. `TRUE` (the default) draws in the top-left
#'   corner of the matrix a two-by-two key with the first two variables,
#'   showing that every cell is `row ~ s(column)`. It needs `labels =
#'   "border"`.
#' @param pair_background Logical. `TRUE` (the default) tints the panels of
#'   [janusplot_pair()] by the pair's Pearson correlation, as
#'   `background_by = "pearson"` tints the matrix. A fit with `adjust`
#'   draws no pair background.
#' @param text_size `"auto"` (the default), a single base size in points,
#'   a named list of element sizes, or `NULL` for no text; see Details.
#' @param base_family Font family of every text, `""` (the default) for
#'   the device's sans-serif font.
#' @param compact Scale-aware content suppression as the variable count
#'   grows: `"auto"` (the default) climbs the tier ladder at
#'   `compact_threshold`, `"always"` forces at least tier 1, `"never"`
#'   keeps every cell at tier 0. Tier 1 drops the points and compacts the
#'   strip, tier 2 drops the band, tier 3 drops the curve and shows the
#'   shape glyph alone.
#' @param compact_threshold Integer of at least 2. The variable count at
#'   which tier 1 starts under `compact = "auto"`; `12L` by default.
#' @param compact_levels Optional named list with entries `t1`, `t2`,
#'   `t3` giving the variable counts at which each tier starts, with
#'   `t1 < t2 < t3`. `NULL` (the default) uses `compact_threshold`,
#'   `compact_threshold + 6` and `compact_threshold + 13`.
#' @param focus_dim_alpha Opacity in `[0, 1]` of the grey wash on cells
#'   outside the `focus_by` selection; `0.25` by default.
#' @param x A `janusplot_style` object.
#' @param ... Ignored by the `print()` method.
#'
#' @returns A named list of class `janusplot_style` holding the 32 values
#'   above, with `text_size` stored as given. `print()` lists the values
#'   that differ from the defaults and returns `x` invisibly.
#'
#' @family smooth-associations
#' @seealso [plot.janusplot_fit()] and [janusplot()], which take the
#'   object as `style`.
#'
#' @examples
#' janusplot_style()
#' janusplot_style(colour_channel = "tile", point_alpha = 0.4)
#'
#' # Every text from one base size; no glossary text and no corner key.
#' janusplot_style(text_size = list(strip = 7, glossary = NULL, key = NULL))
#'
#' # The 0.2.0 look: Pearson r washed over the whole cell.
#' fit <- janusplot_fit(mtcars[, c("mpg", "hp", "wt")], engine = "gam")
#' plot(fit, colour_by = "pearson", background_by = "none",
#'      style = janusplot_style(colour_channel = "fill"))
#' @export
janusplot_style <- function(
  colour_channel = c("border", "tile", "fill"),
  palette = NULL,
  background_palette = "BuOr",
  background_strength = 0.35,
  annotation_position = c("strip", "corners"),
  show_data = TRUE,
  adjusted_points = c("partial", "raw"),
  identity_line = FALSE,
  show_ci = TRUE,
  point_size = 0.4,
  point_alpha = 0.25,
  curve_colour = "#08306b",
  curve_width = 2,
  band_alpha = 0.20,
  border_width = NULL,
  density_threshold = 2000L,
  group_palette = "Okabe-Ito",
  group_max_levels = 8L,
  labels = c("border", "none"),
  label_srt = 45,
  diagonal = c("auto", "blank", "name", "density"),
  glyph_style = c("ascii", "unicode"),
  show_shape_legend = "auto",
  show_glossary = TRUE,
  show_key = TRUE,
  pair_background = TRUE,
  text_size = "auto",
  base_family = "",
  compact = c("auto", "always", "never"),
  compact_threshold = 12L,
  compact_levels = NULL,
  focus_dim_alpha = 0.25
) {
  colour_channel      <- rlang::arg_match(colour_channel)
  annotation_position <- rlang::arg_match(annotation_position)
  labels              <- rlang::arg_match(labels)
  diagonal            <- rlang::arg_match(diagonal)
  glyph_style         <- rlang::arg_match(glyph_style)
  compact             <- rlang::arg_match(compact)
  adjusted_points     <- rlang::arg_match(adjusted_points)
  palette             <- .check_palette(palette)
  background_palette  <- rlang::arg_match(background_palette,
                                          .palettes_diverging)
  .check_strength(background_strength)
  .check_flag(show_data, "show_data")
  .check_flag(show_ci, "show_ci")
  .check_flag(identity_line, "identity_line")
  .check_flag_or_auto(show_shape_legend, "show_shape_legend")
  .check_flag(show_glossary, "show_glossary")
  .check_flag(show_key, "show_key")
  .check_flag(pair_background, "pair_background")
  .check_scalar_positive(point_size, "point_size")
  .check_scalar_positive(curve_width, "curve_width")
  if (!is.null(border_width)) {
    .check_scalar_positive(border_width, "border_width")
  }
  .check_opacity(point_alpha, "point_alpha")
  .check_opacity(band_alpha, "band_alpha")
  .check_opacity(focus_dim_alpha, "focus_dim_alpha")
  .check_colours(curve_colour, "curve_colour", single = TRUE)
  .check_group_palette(group_palette)
  density_threshold <- .check_positive_integer(density_threshold,
                                               "density_threshold")
  group_max_levels  <- .check_positive_integer(group_max_levels,
                                               "group_max_levels")
  .check_label_srt(label_srt)
  .check_text_size(text_size)
  .check_base_family(base_family)
  compact_threshold <- .check_compact_threshold(compact_threshold)
  if (!is.null(compact_levels)) {
    compact_levels <- .validate_compact_levels(compact_levels,
                                               compact_threshold)
  }
  out <- list(
    colour_channel      = colour_channel,
    palette             = palette,
    background_palette  = background_palette,
    background_strength = background_strength,
    annotation_position = annotation_position,
    show_data           = show_data,
    adjusted_points     = adjusted_points,
    identity_line       = identity_line,
    show_ci             = show_ci,
    point_size          = point_size,
    point_alpha         = point_alpha,
    curve_colour        = curve_colour,
    curve_width         = curve_width,
    band_alpha          = band_alpha,
    border_width        = border_width,
    density_threshold   = density_threshold,
    group_palette       = group_palette,
    group_max_levels    = group_max_levels,
    labels              = labels,
    label_srt           = label_srt,
    diagonal            = diagonal,
    glyph_style         = glyph_style,
    show_shape_legend   = show_shape_legend,
    show_glossary       = show_glossary,
    show_key            = show_key,
    pair_background     = pair_background,
    text_size           = text_size,
    base_family         = base_family,
    compact             = compact,
    compact_threshold   = compact_threshold,
    compact_levels      = compact_levels,
    focus_dim_alpha     = focus_dim_alpha
  )
  structure(out, class = c("janusplot_style", "list"))
}

#' @rdname janusplot_style
#' @export
print.janusplot_style <- function(x, ...) {
  defaults <- unclass(janusplot_style())
  changed <- names(x)[!vapply(names(x), function(nm) {
    identical(x[[nm]], defaults[[nm]])
  }, logical(1L))]
  if (!length(changed)) {
    cli::cat_line("janusplot style: all defaults")
    return(invisible(x))
  }
  cli::cat_line(sprintf("janusplot style: %d non-default value%s", length(changed),
                        if (length(changed) == 1L) "" else "s"))
  for (nm in changed) {
    value <- paste(deparse(x[[nm]], width.cutoff = 60L), collapse = " ")
    cli::cat_line("  ", nm, " = ", value)
  }
  invisible(x)
}

# ---------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------

# NULL, or one of the supported palette names.
.check_flag_or_auto <- function(x, arg_name, call = rlang::caller_env()) {
  if (identical(x, "auto")) return(invisible(NULL))
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg {arg_name}} must be {.val auto}, TRUE or FALSE.",
                   call = call)
  }
  invisible(NULL)
}

.check_palette <- function(palette, call = rlang::caller_env()) {
  if (is.null(palette)) return(NULL)
  rlang::arg_match(palette, .palette_choices(), error_call = call)
}

# A single finite opacity in [0, 1] (closed; the open-interval check of the
# direction test is .check_unit_interval() in direction-test.R).
.check_opacity <- function(x, arg_name, call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 0 || x > 1) {
    cli::cli_abort("{.arg {arg_name}} must be in [0, 1].", call = call)
  }
  invisible(NULL)
}

# A single finite number >= 1, returned as integer.
.check_positive_integer <- function(x, arg_name, call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 1) {
    cli::cli_abort("{.arg {arg_name}} must be a single positive integer.",
                   call = call)
  }
  as.integer(x)
}

# A single finite number >= 2, returned as integer.
.check_compact_threshold <- function(x, call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 2) {
    cli::cli_abort("{.arg compact_threshold} must be a single integer >= 2.",
                   call = call)
  }
  as.integer(x)
}

# A single numeric rotation in degrees.
.check_label_srt <- function(x, call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg label_srt} must be a single numeric value.",
                   call = call)
  }
  invisible(NULL)
}

# A character vector (or one string) of colours grDevices can resolve.
.check_colours <- function(x, arg_name, single = FALSE,
                           call = rlang::caller_env()) {
  if (!is.character(x) || !length(x) || anyNA(x) || !all(nzchar(x)) ||
      (single && length(x) != 1L)) {
    cli::cli_abort(paste0(
      "{.arg {arg_name}} must be ",
      if (single) "a single colour string." else "a character vector of colours."
    ), call = call)
  }
  # col2rgb() errors on an unknown name; that error becomes the message
  # below, which names the argument and the offending values.
  bad <- x[vapply(x, function(col) {
    is.null(tryCatch(grDevices::col2rgb(col), error = function(e) NULL))
  }, logical(1L))]
  if (length(bad)) {
    cli::cli_abort("{.arg {arg_name}} has {?an/} invalid colour{?s}: {.val {bad}}.",
                   call = call)
  }
  invisible(NULL)
}

# A palette name grDevices::palette.colors() knows, or a vector of colours.
.check_group_palette <- function(x, call = rlang::caller_env()) {
  if (is.character(x) && length(x) == 1L && !is.na(x) &&
      x %in% grDevices::palette.pals()) {
    return(invisible(NULL))
  }
  if (!is.character(x) || !length(x)) {
    cli::cli_abort(c(
      "{.arg group_palette} must name a palette or give a vector of colours.",
      i = "Palette names: {.val {grDevices::palette.pals()}}."
    ), call = call)
  }
  .check_colours(x, "group_palette", call = call)
}

# A single number in (0, 1].
.check_strength <- function(x, call = rlang::caller_env()) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0 || x > 1) {
    cli::cli_abort("{.arg background_strength} must be a number in (0, 1].",
                   call = call)
  }
  invisible(NULL)
}

# A single font family name; "" is the device default.
.check_base_family <- function(x, call = rlang::caller_env()) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    cli::cli_abort("{.arg base_family} must be a single string.", call = call)
  }
  invisible(NULL)
}

.text_elements <- function() {
  c("strip", "labels", "diagonal", "legend", "key", "glossary", "title",
    "axis")
}

# NULL, "auto", one positive number, or a named list whose elements are
# each a positive number, "auto" or NULL.
.check_text_size <- function(x, call = rlang::caller_env()) {
  if (is.null(x) || identical(x, "auto")) return(invisible(NULL))
  is_size <- function(v) {
    is.numeric(v) && length(v) == 1L && is.finite(v) && v > 0
  }
  if (is_size(x)) return(invisible(NULL))
  if (!is.list(x)) {
    cli::cli_abort(c(
      "{.arg text_size} must be {.val auto}, a size in points, a named list or NULL.",
      i = "List elements: {.val {(.text_elements())}}."
    ), call = call)
  }
  nms <- names(x)
  if (length(x) && (is.null(nms) || !all(nzchar(nms)))) {
    cli::cli_abort("Every element of {.arg text_size} must be named.",
                   call = call)
  }
  unknown <- setdiff(nms, .text_elements())
  if (length(unknown)) {
    cli::cli_abort(c(
      "Unknown {.arg text_size} element{?s}: {.val {unknown}}.",
      i = "Elements: {.val {(.text_elements())}}."
    ), call = call)
  }
  bad <- nms[!vapply(x, function(v) {
    is.null(v) || identical(v, "auto") || is_size(v)
  }, logical(1L))]
  if (length(bad)) {
    cli::cli_abort(c(
      "{.arg text_size} element{?s} {.val {bad}} must be a size in points, {.val auto} or NULL.",
      i = "Sizes are single positive numbers."
    ), call = call)
  }
  invisible(NULL)
}
