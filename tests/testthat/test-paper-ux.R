# Display rules added for 1.0.0: the dash for A on a pair with no
# significant direction, the identity line of the overlay, wrapped pair
# titles, the near-interpolation warning, the curve extractor, the legends
# under the matrix, the scaled matrix points and the stacked pair faces.

make_noise_pair <- function(n = 200L, seed = 5L) {
  withr::with_seed(seed, data.frame(a = stats::rnorm(n), b = stats::rnorm(n)))
}

test_that("A is a dash in the strip when neither direction is significant", {
  fit <- janusplot_fit(make_noise_pair(), engine = "gam",
                       derivatives = integer())
  pr <- fit$pairs[[1L]]
  skip_if(!janusplot:::.pair_not_significant(pr),
          "the generator gave a significant direction")
  face <- janusplot:::.pair_face(pr, "yx")
  expect_true(face$pair_not_significant)
  expect_match(janusplot:::.cell_strip_text(face, c("A", "signif")),
               "^A -( |$)")
  expect_match(janusplot:::.cell_strip_text(face, c("A", "signif"),
                                            glyph_style = "unicode"),
               "^A \u2013")
  face$pair_not_significant <- FALSE
  expect_match(janusplot:::.cell_strip_text(face, c("A", "signif")),
               "^A [0-9]\\.[0-9]{2}")
})

test_that(".pair_not_significant needs both directions at p >= 0.05", {
  f <- janusplot:::.pair_not_significant
  expect_true(f(list(association_p_adj_yx = 0.3, association_p_adj_xy = 0.06)))
  expect_false(f(list(association_p_adj_yx = 0.3, association_p_adj_xy = 0.01)))
  expect_false(f(list(association_p_adj_yx = NA_real_,
                      association_p_adj_xy = 0.5)))
})

test_that("identity_line adds the y = x line to the overlay", {
  d <- make_linear_data(n = 120L)
  fit <- janusplot_fit(d[, c("x1", "x2")], engine = "gam",
                       derivatives = integer())
  layers_of <- function(p) {
    vapply(p$layers, function(l) class(l$geom)[1L], character(1L))
  }
  p_on <- janusplot_pair(fit, "x1", "x2", display = "both",
                         style = janusplot_style(identity_line = TRUE))
  p_off <- janusplot_pair(fit, "x1", "x2", display = "both")
  on <- p_on[[1L]]
  off <- p_off[[1L]]
  expect_true("GeomAbline" %in% layers_of(on))
  expect_false("GeomAbline" %in% layers_of(off))
})

test_that("long model formulas wrap in the pair titles", {
  d <- make_linear_data(n = 120L)
  names(d) <- c("a_rather_long_name", "another_long_name", "x3", "x4")
  fit <- janusplot_fit(d[, 1:2], engine = "gam", derivatives = integer())
  p <- janusplot_pair(fit, "a_rather_long_name", "another_long_name")
  expect_match(p[[1L]]$labels$title, "~\n", fixed = TRUE)
})

test_that("cells that nearly interpolate are named in one warning", {
  expect_warning(
    janusplot_fit(anscombe[, c("x2", "y2")], engine = "gam",
                  derivatives = integer()),
    "nearly interpolate"
  )
  expect_no_warning(
    janusplot_fit(make_linear_data(n = 120L)[, c("x1", "x2")],
                  engine = "gam", derivatives = integer())
  )
})

test_that("janusplot_curves() returns both directions in long form", {
  fit <- janusplot_fit(make_nonlinear_data(n = 120L)[, c("x1", "x2", "x3")],
                       engine = "gam", n_grid = 50L, derivatives = 1L)
  cu <- janusplot_curves(fit)
  expect_named(cu, c("var_x", "var_y", "position", "x", "fit", "se", "lo",
                     "hi"))
  expect_identical(nrow(cu), 6L * 50L)
  one <- janusplot_curves(fit, "x1", "x2")
  expect_setequal(unique(paste(one$var_y, one$var_x)), c("x2 x1", "x1 x2"))
  tab <- summary(fit)
  key <- paste(tab$var_x, tab$var_y)
  pos <- tapply(cu$position, paste(cu$var_x, cu$var_y), unique)
  expect_identical(as.character(pos[key]), tab$position)
  pr <- fit$pairs[[1L]]
  first <- cu[cu$var_x == pr$var_i & cu$var_y == pr$var_j, ]
  expect_equal(first$fit, pr$pred_yx$fit)
  d1 <- janusplot_curves(fit, what = "d1")
  expect_identical(nrow(d1), 6L * 50L)
  expect_error(janusplot_curves(fit, what = "d2"), "derivative order")
  expect_error(janusplot_curves(fit, "x1"), "both")
  expect_error(janusplot_curves(fit, "x1", "nope"), "not a fitted variable")
})

test_that("pairs and matrices compose with `/` and `|`", {
  d <- withr::with_seed(1L, data.frame(a = stats::rnorm(90L),
                                       b = stats::rnorm(90L),
                                       g = factor(rep(c("u", "v", "w"), 30L))))
  d$b <- d$b + d$a
  fit <- janusplot_fit(d, engine = "gam", derivatives = integer(),
                       adjust = ~ g)
  p <- janusplot_pair(fit, "a", "b", group = "g")
  path <- withr::local_tempfile(fileext = ".png")
  expect_no_error(ggplot2::ggsave(path, p / p, width = 6, height = 8))
  expect_no_error(ggplot2::ggsave(path, p | p, width = 8, height = 4))
  m <- plot(fit, group = "g")
  expect_no_error(ggplot2::ggsave(path, m / m, width = 6, height = 10))
  expect_no_error(ggplot2::ggsave(path, m | m, width = 10, height = 6))
})

test_that("legend_position = 'bottom' sizes the legend row to its content", {
  vars <- c("x1", "x2", "x3")
  bars <- janusplot:::.bottom_bar_specs("nonlinearity", c(0, 4), "viridis",
                                        background_by = "pearson")
  expect_identical(vapply(bars, function(b) b$title, character(1L)),
                   c("Border: non-linearity (EDF - 1)",
                     "Background: Pearson r"))
  expect_identical(bars[[1L]]$breaks, c(0, 1, 2, 3, 4))
  expect_identical(bars[[2L]]$breaks, c(-1, 0, 1))
  expect_length(janusplot:::.bottom_bar_specs("none", c(NA_real_, NA_real_),
                                              "viridis"), 0L)

  key_h <- janusplot:::.key_layout(vars, 5.5)$height
  row <- janusplot:::.build_bottom_legend_row(vars, key_pt = 5.5,
                                              strip_w = 57, grouping = NULL,
                                              bars = bars, legend_pt = 9)
  expect_identical(row$height, max(2 * 9 + 16, key_h) + 6)
  # No key: the row is as high as the bars alone.
  row <- janusplot:::.build_bottom_legend_row(vars, key_pt = NA_real_,
                                              strip_w = 57, grouping = NULL,
                                              bars = bars, legend_pt = 9)
  expect_identical(row$height, 2 * 9 + 16 + 6)
  expect_null(janusplot:::.build_bottom_legend_row(vars, NA_real_, 57, NULL,
                                                   list()))
})

test_that("a matrix with its legends at the bottom renders", {
  d <- make_nonlinear_data(n = 120L)
  d$g <- factor(rep(c("u", "v", "w"), 40L))
  fit <- janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam",
                       derivatives = integer())
  fit_adj <- janusplot_fit(d, vars = c("x1", "x2", "x3"), adjust = ~ g,
                           engine = "gam", derivatives = integer())
  bottom <- janusplot_style(legend_position = "bottom", label_srt = 0)
  path <- withr::local_tempfile(fileext = ".png")
  expect_no_error(ggplot2::ggsave(path, plot(fit, group = "g", style = bottom),
                                  width = 5.5, height = 6))
  expect_no_error(ggplot2::ggsave(path, plot(fit, colour_by = "none",
                                             background_by = "none",
                                             style = bottom),
                                  width = 5.5, height = 6))
  cmp <- janusplot_compare(fit, fit_adj)
  expect_no_error(ggplot2::ggsave(path, plot(cmp, group = "g", style = bottom),
                                  width = 5.5, height = 6))
  expect_error(janusplot_style(legend_position = "top"), "legend_position")
})

test_that("matrix points shrink with the variable count; pair points do not", {
  expect_equal(janusplot:::.matrix_point_scale(4L), 1.09, tolerance = 0.01)
  expect_lt(janusplot:::.matrix_point_scale(8L),
            janusplot:::.matrix_point_scale(4L))
  pts <- data.frame(x = 1:3, y = 1:3)
  params_of <- function(scale) {
    janusplot:::.cell_points_layer(pts, janusplot_style(),
                                   point_scale = scale)$aes_params
  }
  # The pair view: the size as given, the outline left to ggplot2.
  expect_identical(params_of(NULL)$size, 0.4)
  expect_null(params_of(NULL)$stroke)
  # The matrix: scaled, no outline.
  expect_identical(params_of(0.5)$size, 0.2)
  expect_identical(params_of(0.5)$stroke, 0)
})

test_that("janusplot_pair() takes annotations and stacks the two faces", {
  d <- make_nonlinear_data(n = 120L)
  fit <- janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam",
                       derivatives = integer())
  p <- janusplot_pair(fit, "x1", "x2", annotations = "edf")
  expect_match(p[[1L]]$labels$subtitle, "^EDF [0-9.]+$")
  p <- janusplot_pair(fit, "x1", "x2", annotations = character())
  expect_null(p[[1L]]$labels$subtitle)
  expect_error(janusplot_pair(fit, "x1", "x2", annotations = "nope"),
               "annotations")

  # Two pairs stacked: forward panels in the first row, reverse below.
  p <- janusplot_pair(fit, c("x1", "x1"), c("x2", "x3"), arrange = "stacked")
  expect_identical(p$patches$layout$ncol, 2L)
  titles <- vapply(1:4, function(i) p[[i]]$labels$title, character(1L))
  expect_identical(titles, c("x2 ~ s(x1)", "x3 ~ s(x1)",
                             "x1 ~ s(x2)", "x1 ~ s(x3)"))
  one <- janusplot_pair(fit, "x1", "x2", arrange = "stacked")
  expect_identical(one[[1L]]$labels$title, "x2 ~ s(x1)")
  expect_identical(one[[2L]]$labels$title, "x1 ~ s(x2)")
  expect_identical(
    janusplot:::.pair_stack_layout(7L, by_row = TRUE),
    list(nrow = 2L, ncol = 4L)
  )
})

test_that("the reference plot orders its panels as the pairs were listed", {
  d <- make_nonlinear_data(n = 80L)
  names(d)[2:3] <- c("zz", "aa")
  fit <- janusplot_fit(d, vars = c("x1", "zz", "aa"), engine = "gam",
                       derivatives = integer())
  ref <- janusplot_reference(fit, x = c("x1", "x1"), y = c("zz", "aa"),
                             B = 5L, seed = 1L)
  p <- suppressWarnings(plot(ref))
  expect_identical(levels(p$data$pair), c("x1 <-> zz", "x1 <-> aa"))
})
