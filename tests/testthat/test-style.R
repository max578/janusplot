# Tests for janusplot_style(): construction, the class and field order,
# every validation error, and the print() method.

test_that("janusplot_style() returns the 26 documented fields in order", {
  s <- janusplot_style()
  expect_s3_class(s, c("janusplot_style", "list"), exact = TRUE)
  expect_named(s, c(
    "colour_channel", "palette", "annotation_position", "show_data",
    "show_ci", "point_size", "point_alpha", "curve_colour", "band_alpha",
    "density_threshold", "group_palette", "group_max_levels", "labels",
    "label_srt", "label_cex", "diagonal", "text_scale_diag",
    "text_scale_off_diag", "glyph_style", "show_shape_legend",
    "show_glossary", "glossary_scale", "compact", "compact_threshold",
    "compact_levels", "focus_dim_alpha"
  ))
  expect_length(formals(janusplot_style), 26L)
  expect_identical(s$colour_channel, "border")
  expect_null(s$palette)
  expect_identical(s$annotation_position, "strip")
  expect_identical(s$curve_colour, "#08306b")
  expect_identical(s$density_threshold, 2000L)
  expect_identical(s$group_palette, "Okabe-Ito")
  expect_identical(s$group_max_levels, 8L)
  expect_identical(s$labels, "border")
  expect_identical(s$diagonal, "auto")
  expect_identical(s$glyph_style, "ascii")
  expect_identical(s$compact, "auto")
  expect_identical(s$compact_threshold, 12L)
  expect_null(s$compact_levels)
})

test_that("values are resolved and coerced at construction", {
  s <- janusplot_style(
    colour_channel = "tile", palette = "magma", annotation_position = "corners",
    density_threshold = 500, group_max_levels = 3, compact_threshold = 15,
    compact_levels = list(t1 = 15, t2 = 20, t3 = 30),
    group_palette = c("red", "blue"), labels = "none", diagonal = "density"
  )
  expect_identical(s$colour_channel, "tile")
  expect_identical(s$palette, "magma")
  expect_identical(s$annotation_position, "corners")
  expect_identical(s$density_threshold, 500L)
  expect_identical(s$group_max_levels, 3L)
  expect_identical(s$compact_threshold, 15L)
  expect_identical(s$compact_levels, list(t1 = 15L, t2 = 20L, t3 = 30L))
  expect_identical(s$group_palette, c("red", "blue"))
  expect_identical(s$labels, "none")
  expect_identical(s$diagonal, "density")
})

test_that("unknown names are an error naming them", {
  expect_error(janusplot_style(fill_alpha = 0.5), "fill_alpha")
  expect_error(janusplot_style(show_asymmetry = TRUE), "show_asymmetry")
})

test_that("enumerated arguments are matched", {
  expect_error(janusplot_style(colour_channel = "edge"), "must be one of")
  expect_error(janusplot_style(annotation_position = "top"), "must be one of")
  expect_error(janusplot_style(labels = "diagonal"), "must be one of")
  expect_error(janusplot_style(diagonal = "violin"), "must be one of")
  expect_error(janusplot_style(glyph_style = "emoji"), "must be one of")
  expect_error(janusplot_style(compact = "sometimes"), "must be one of")
  expect_error(janusplot_style(palette = "not_a_palette"), "must be one of")
})

test_that("logical flags must be a single TRUE or FALSE", {
  for (nm in c("show_data", "show_ci", "show_shape_legend", "show_glossary")) {
    args <- stats::setNames(list("yes"), nm)
    expect_error(do.call(janusplot_style, args), "TRUE or FALSE")
    args <- stats::setNames(list(NA), nm)
    expect_error(do.call(janusplot_style, args), "TRUE or FALSE")
    args <- stats::setNames(list(c(TRUE, FALSE)), nm)
    expect_error(do.call(janusplot_style, args), "TRUE or FALSE")
  }
})

test_that("positive scalars are validated", {
  for (nm in c("point_size", "label_cex", "text_scale_diag",
               "text_scale_off_diag", "glossary_scale")) {
    expect_error(do.call(janusplot_style, stats::setNames(list(0), nm)),
                 "single positive number")
    expect_error(do.call(janusplot_style, stats::setNames(list(-1), nm)),
                 "single positive number")
    expect_error(do.call(janusplot_style, stats::setNames(list("big"), nm)),
                 "single positive number")
    expect_error(do.call(janusplot_style, stats::setNames(list(c(1, 2)), nm)),
                 "single positive number")
  }
})

test_that("alphas are validated in [0, 1]", {
  for (nm in c("point_alpha", "band_alpha", "focus_dim_alpha")) {
    expect_error(do.call(janusplot_style, stats::setNames(list(-0.1), nm)),
                 "in \\[0, 1\\]")
    expect_error(do.call(janusplot_style, stats::setNames(list(2), nm)),
                 "in \\[0, 1\\]")
    expect_error(do.call(janusplot_style, stats::setNames(list("half"), nm)),
                 "in \\[0, 1\\]")
  }
  expect_identical(janusplot_style(point_alpha = 0)$point_alpha, 0)
  expect_identical(janusplot_style(band_alpha = 1)$band_alpha, 1)
})

test_that("integer thresholds are validated", {
  expect_error(janusplot_style(density_threshold = 0), "positive integer")
  expect_error(janusplot_style(density_threshold = "many"), "positive integer")
  expect_error(janusplot_style(group_max_levels = 0), "positive integer")
  expect_error(janusplot_style(group_max_levels = c(2, 3)), "positive integer")
  expect_error(janusplot_style(compact_threshold = 0L), "integer >= 2")
  expect_error(janusplot_style(compact_threshold = "twelve"), "integer >= 2")
  expect_error(janusplot_style(compact_levels = list(t1 = 10L, t2 = 8L, t3 = 20L)),
               "t1 < t2 < t3")
  expect_error(janusplot_style(compact_levels = list(t1 = 5L, t2 = 10L)),
               "missing entries")
  expect_error(janusplot_style(compact_levels = "t1 = 5"), "named list")
})

test_that("label_srt must be a single numeric", {
  expect_error(janusplot_style(label_srt = "45"), "numeric")
  expect_error(janusplot_style(label_srt = NA_real_), "numeric")
  expect_error(janusplot_style(label_srt = c(0, 45)), "numeric")
  expect_identical(janusplot_style(label_srt = 90)$label_srt, 90)
})

test_that("colours are validated", {
  expect_error(janusplot_style(curve_colour = "not a colour"), "invalid colour")
  expect_error(janusplot_style(curve_colour = c("red", "blue")),
               "single colour")
  expect_error(janusplot_style(curve_colour = 1), "single colour")
  expect_error(janusplot_style(group_palette = c("red", "not a colour")),
               "invalid colour")
  expect_error(janusplot_style(group_palette = 3), "name a palette")
  expect_error(janusplot_style(group_palette = character()), "name a palette")
  expect_identical(janusplot_style(group_palette = "Tableau 10")$group_palette,
                   "Tableau 10")
  expect_identical(janusplot_style(curve_colour = "firebrick")$curve_colour,
                   "firebrick")
})

test_that("print() lists the non-default values or says all defaults", {
  lines <- testthat::capture_output_lines(out <- print(janusplot_style()))
  expect_s3_class(out, "janusplot_style")
  expect_identical(lines, "janusplot style: all defaults")
  s <- janusplot_style(colour_channel = "fill", point_alpha = 0.4,
                       compact_levels = list(t1 = 5L, t2 = 8L, t3 = 12L))
  lines <- testthat::capture_output_lines(print(s))
  expect_identical(lines[1L], "janusplot style: 3 non-default values")
  expect_match(lines[2L], '^  colour_channel = "fill"$')
  expect_match(lines[3L], "^  point_alpha = 0.4$")
  expect_match(lines[4L], "^  compact_levels = list\\(t1 = 5L, t2 = 8L, t3 = 12L\\)$")
  lines <- testthat::capture_output_lines(print(janusplot_style(label_srt = 0)))
  expect_identical(lines[1L], "janusplot style: 1 non-default value")
})
