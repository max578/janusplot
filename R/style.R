# style.R -- The janusplot_style object: every appearance knob of the matrix
# and pair views, validated at construction, with a print() method that
# lists the values changed from their defaults. plot.janusplot_fit() and
# janusplot() take it as `style`; the renderers in internal-cell.R and
# internal-assemble.R read it.

#' Appearance settings for janusplot views
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Collects every appearance knob of [plot.janusplot_fit()] and
#' [janusplot()] into one validated object. Model settings live in
#' [janusplot_fit()], what the matrix encodes lives in `plot()`'s
#' `colour_by` and `annotations`, and how it is drawn lives here.
#'
#' @details
#' The default cell has no background fill. The panel border carries the
#' `colour_by` value, a thin strip above the data area carries the
#' annotations in small grey text, grey points sit behind a dark blue
#' curve with a 20 percent band, and cells with more than
#' `density_threshold` rows draw the points as a light grey binned
#' density instead. `colour_channel = "fill"` with `colour_by = "pearson"`
#' reproduces the 0.2.0 look.
#'
#' @param colour_channel Where the `colour_by` value is painted:
#'   `"border"` (the default) colours the panel border, `"tile"` fills a
#'   small bottom-right corner tile and leaves the border grey, `"fill"`
#'   washes the whole cell at alpha 0.45.
#' @param palette Name of the colour palette for the `colour_by` scale, or
#'   `NULL` (the default) for `"RdBu"` when `colour_by` is a correlation
#'   and `"viridis"` otherwise. Sequential choices: `"viridis"`,
#'   `"magma"`, `"inferno"`, `"plasma"`, `"cividis"`, `"mako"`, `"rocket"`,
#'   `"turbo"` (not colour-blind safe), `"YlOrRd"`, `"YlGnBu"`, `"Blues"`,
#'   `"Greens"`. Diverging choices: `"RdYlBu"`, `"RdBu"`, `"PuOr"`,
#'   `"Spectral"` (not colour-blind safe). A sequential palette under a
#'   correlation `colour_by` is replaced by `"RdBu"`.
#' @param annotation_position Where the `annotations` of `plot()` are
#'   written: `"strip"` (the default) in a thin strip above the data area,
#'   `"corners"` inside the panel where 0.2.0 placed them (A, EDF and n
#'   bottom-left, significance top-right, shape code top-left, shape
#'   glyph bottom-right).
#' @param show_data Logical. `TRUE` (the default) draws the raw points of
#'   each cell behind the curve on fit cells; derivative cells never
#'   carry points.
#' @param show_ci Logical. `TRUE` (the default) draws the 95 percent band
#'   around the curve, and around a derivative curve when the fit stored
#'   one.
#' @param point_size Size of the raw points; `0.4` by default.
#' @param point_alpha Opacity of the raw points in `[0, 1]`; `0.25` by
#'   default.
#' @param curve_colour Colour of the fitted curve and its band; the dark
#'   blue `"#08306b"` by default.
#' @param band_alpha Opacity of the band in `[0, 1]`; `0.20` by default.
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
#' @param label_cex Positive multiplier on the border-label font size;
#'   `1` by default.
#' @param diagonal Content of the diagonal cells: `"auto"` (the default)
#'   and `"blank"` leave them empty, `"name"` writes the variable name,
#'   `"density"` draws a kernel density with a rug of the raw values.
#' @param text_scale_diag Positive multiplier on the diagonal name labels;
#'   `1` by default.
#' @param text_scale_off_diag Positive multiplier on every off-diagonal
#'   annotation; `1` by default.
#' @param glyph_style `"ascii"` (the default) or `"unicode"` for the shape
#'   glyphs, the derivative order labels and the k-check warning sign.
#' @param show_shape_legend Logical. `TRUE` (the default) attaches the
#'   shape-categories legend below the matrix.
#' @param show_glossary Logical. `TRUE` (the default) attaches a caption
#'   describing the abbreviations and encodings on the plot.
#' @param glossary_scale Positive multiplier on the glossary font size;
#'   `1` by default.
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
#' @returns A named list of class `janusplot_style` holding the 26 values
#'   above. `print()` lists the values that differ from the defaults and
#'   returns `x` invisibly.
#'
#' @family smooth-associations
#' @seealso [plot.janusplot_fit()] and [janusplot()], which take the
#'   object as `style`.
#'
#' @examples
#' janusplot_style()
#' janusplot_style(colour_channel = "tile", point_alpha = 0.4)
#'
#' # The 0.2.0 look: Pearson r washed over the whole cell.
#' fit <- janusplot_fit(mtcars[, c("mpg", "hp", "wt")], engine = "gam")
#' plot(fit, colour_by = "pearson",
#'      style = janusplot_style(colour_channel = "fill"))
#' @export
janusplot_style <- function(
  colour_channel = c("border", "tile", "fill"),
  palette = NULL,
  annotation_position = c("strip", "corners"),
  show_data = TRUE,
  show_ci = TRUE,
  point_size = 0.4,
  point_alpha = 0.25,
  curve_colour = "#08306b",
  band_alpha = 0.20,
  density_threshold = 2000L,
  group_palette = "Okabe-Ito",
  group_max_levels = 8L,
  labels = c("border", "none"),
  label_srt = 45,
  label_cex = 1,
  diagonal = c("auto", "blank", "name", "density"),
  text_scale_diag = 1,
  text_scale_off_diag = 1,
  glyph_style = c("ascii", "unicode"),
  show_shape_legend = TRUE,
  show_glossary = TRUE,
  glossary_scale = 1,
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
  palette             <- .check_palette(palette)
  .check_flag(show_data, "show_data")
  .check_flag(show_ci, "show_ci")
  .check_flag(show_shape_legend, "show_shape_legend")
  .check_flag(show_glossary, "show_glossary")
  .check_scalar_positive(point_size, "point_size")
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
  .check_scalar_positive(label_cex, "label_cex")
  .check_scalar_positive(text_scale_diag, "text_scale_diag")
  .check_scalar_positive(text_scale_off_diag, "text_scale_off_diag")
  .check_scalar_positive(glossary_scale, "glossary_scale")
  compact_threshold <- .check_compact_threshold(compact_threshold)
  if (!is.null(compact_levels)) {
    compact_levels <- .validate_compact_levels(compact_levels,
                                               compact_threshold)
  }
  out <- list(
    colour_channel      = colour_channel,
    palette             = palette,
    annotation_position = annotation_position,
    show_data           = show_data,
    show_ci             = show_ci,
    point_size          = point_size,
    point_alpha         = point_alpha,
    curve_colour        = curve_colour,
    band_alpha          = band_alpha,
    density_threshold   = density_threshold,
    group_palette       = group_palette,
    group_max_levels    = group_max_levels,
    labels              = labels,
    label_srt           = label_srt,
    label_cex           = label_cex,
    diagonal            = diagonal,
    text_scale_diag     = text_scale_diag,
    text_scale_off_diag = text_scale_off_diag,
    glyph_style         = glyph_style,
    show_shape_legend   = show_shape_legend,
    show_glossary       = show_glossary,
    glossary_scale      = glossary_scale,
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
