# Tests for janusplot_style(): construction, the class and field order,
# every validation error, and the print() method.

test_that("janusplot_style() returns the 33 documented fields in order", {
  s <- janusplot_style()
  expect_s3_class(s, c("janusplot_style", "list"), exact = TRUE)
  expect_named(s, c(
    "colour_channel", "palette", "background_palette", "background_strength",
    "annotation_position", "show_data", "adjusted_points", "identity_line",
    "show_ci", "point_size",
    "point_alpha", "curve_colour", "curve_width", "band_alpha",
    "border_width", "density_threshold", "group_palette", "group_max_levels",
    "labels", "label_srt", "diagonal", "glyph_style", "show_shape_legend",
    "show_glossary", "show_key", "legend_position", "pair_background",
    "text_size",
    "base_family", "compact", "compact_threshold", "compact_levels",
    "focus_dim_alpha"
  ))
  expect_length(formals(janusplot_style), 33L)
  expect_identical(s$legend_position, "right")
  expect_identical(s$background_palette, "BuOr")
  expect_identical(s$background_strength, 0.35)
  expect_identical(s$curve_width, 2)
  expect_null(s$border_width)
  expect_true(s$show_key)
  expect_true(s$pair_background)
  expect_identical(s$text_size, "auto")
  expect_identical(s$base_family, "")
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

test_that("show_shape_legend defaults to auto and accepts TRUE or FALSE", {
  expect_identical(janusplot_style()$show_shape_legend, "auto")
  expect_identical(janusplot_style(show_shape_legend = TRUE)$show_shape_legend,
                   TRUE)
  expect_error(janusplot_style(show_shape_legend = "always"), "auto")
  resolve <- janusplot:::.resolve_shape_legend
  expect_false(resolve("auto", c("A", "signif")))
  expect_true(resolve("auto", c("code", "signif")))
  expect_false(resolve(FALSE, "code"))
  expect_true(resolve(TRUE, character()))
})

test_that("logical flags must be a single TRUE or FALSE", {
  for (nm in c("show_data", "show_ci", "show_shape_legend", "show_glossary",
               "show_key", "pair_background")) {
    args <- stats::setNames(list("yes"), nm)
    expect_error(do.call(janusplot_style, args), "TRUE or FALSE")
    args <- stats::setNames(list(NA), nm)
    expect_error(do.call(janusplot_style, args), "TRUE or FALSE")
    args <- stats::setNames(list(c(TRUE, FALSE)), nm)
    expect_error(do.call(janusplot_style, args), "TRUE or FALSE")
  }
})

test_that("positive scalars are validated", {
  for (nm in c("point_size", "curve_width", "border_width")) {
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

test_that("the background palette and strength are validated", {
  expect_error(janusplot_style(background_palette = "viridis"),
               "must be one of")
  expect_identical(janusplot_style(background_palette = "PuOr")$background_palette,
                   "PuOr")
  for (bad in list(0, -0.1, 1.5, NA_real_, "strong", c(0.2, 0.3))) {
    expect_error(janusplot_style(background_strength = bad), "\\(0, 1\\]")
  }
  expect_identical(janusplot_style(background_strength = 1)$background_strength, 1)
})

test_that("text_size takes auto, a number, a named list or NULL", {
  expect_identical(janusplot_style(text_size = 9)$text_size, 9)
  s <- janusplot_style(text_size = list(strip = 6, glossary = NULL,
                                        title = "auto"))
  expect_identical(s$text_size, list(strip = 6, glossary = NULL, title = "auto"))
  expect_null(janusplot_style(text_size = NULL)$text_size)
  expect_error(janusplot_style(text_size = list(strip = 6, bogus = 3)),
               "bogus")
  expect_error(janusplot_style(text_size = list(strip = 6, bogus = 3)),
               "glossary")
  expect_error(janusplot_style(text_size = list(strip = -1, key = "x")),
               "strip")
  expect_error(janusplot_style(text_size = list(strip = -1, key = "x")),
               "key")
  expect_error(janusplot_style(text_size = list(6)), "named")
  expect_error(janusplot_style(text_size = "large"), "text_size")
  expect_error(janusplot_style(base_family = 1), "base_family")
})

test_that("text sizes resolve to points per element", {
  resolve <- janusplot:::.resolve_text_pt
  auto4 <- resolve(4L, "auto")
  expect_named(auto4, c("strip", "labels", "diagonal", "legend", "key",
                        "glossary", "title", "axis"))
  # The strip scales with the variable count and keeps 5 points.
  expect_equal(auto4$strip, 8 * (3 / 4)^0.55)
  expect_identical(resolve(12L, "auto")$strip, 5)
  expect_identical(resolve(40L, "auto")$strip, 5)
  # One number: every element at its fixed ratio.
  base <- resolve(4L, 10)
  expect_equal(unlist(base), c(strip = 8, labels = 10, diagonal = 12,
                               legend = 9, key = 7.5, glossary = 9,
                               title = 13, axis = 8))
  # A list: named elements set, NULL removes, the rest stay auto.
  mixed <- resolve(4L, list(strip = 7, glossary = NULL, title = "auto"))
  expect_identical(mixed$strip, 7)
  expect_identical(mixed$glossary, NA_real_)
  expect_identical(mixed$title, auto4$title)
  expect_identical(mixed$labels, auto4$labels)
  # NULL: no text at all.
  expect_true(all(is.na(unlist(resolve(4L, NULL)))))
})

test_that("the automatic border width scales with the variable count", {
  lw <- janusplot:::.border_linewidth
  expect_equal(lw(4L), 2.4)
  expect_gt(lw(2L), lw(4L))
  expect_lt(lw(12L), lw(4L))
  expect_identical(lw(40L), 1.0)
  expect_equal(lw(4L, border_width = 3), 3 / ggplot2::.pt)
})
