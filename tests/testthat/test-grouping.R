# Tests for plot(group = ): points coloured by a categorical column of
# fit$data, the legend, the errors, and the invariance of the fit.

make_grouped <- function(n = 90L, seed = 12L) {
  withr::with_seed(seed, {
    g <- rep(c("s1", "s2", "s3"), length.out = n)
    eff <- c(s1 = -1, s2 = 0, s3 = 1)[g]
    x1 <- stats::runif(n, 0, 3)
    data.frame(
      x1 = x1,
      x2 = sin(x1) + eff + stats::rnorm(n, sd = 0.3),
      x3 = 0.5 * x1 + eff + stats::rnorm(n, sd = 0.3),
      site = g,
      irrigated = rep(c(TRUE, FALSE), length.out = n),
      stringsAsFactors = FALSE
    )
  })
}

fit_grouped <- function(d = make_grouped(), ...) {
  janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam", ...)
}

point_layer <- function(cell) {
  cell$layers[[which(vapply(cell$layers, function(l) {
    inherits(l$geom, "GeomPoint")
  }, logical(1L)))[1L]]]
}

test_that("group colours the points by the factor and adds one legend", {
  fit <- fit_grouped()
  grouping <- janusplot:::.resolve_group(fit, "site", janusplot_style())
  expect_identical(grouping$name, "site")
  expect_s3_class(grouping$values, "factor")
  expect_identical(levels(grouping$values), c("s1", "s2", "s3"))
  expect_length(grouping$values, nrow(fit$data))
  expect_identical(names(grouping$colours), c("s1", "s2", "s3"))
  expect_identical(unname(grouping$colours),
                   unname(grDevices::palette.colors(3L, "Okabe-Ito")))

  face <- janusplot:::.pair_face(fit$pairs[[1L]], "yx")
  points <- janusplot:::.cell_points(fit, face$var_x, face$var_y, grouping)
  expect_named(points, c("x", "y", "group"))
  cell <- janusplot:::.render_cell(
    fit$pairs[[1L]], "yx", points, style = janusplot_style(),
    text_sizes = janusplot:::.cell_text_sizes(3L),
    group_colours = grouping$colours
  )
  lyr <- point_layer(cell)
  expect_true("colour" %in% names(lyr$mapping))
  expect_null(lyr$aes_params$colour)
  p <- plot(fit, group = "site", style = janusplot_style(show_shape_legend = FALSE))
  expect_s3_class(p, "ggplot")
  legend <- janusplot:::.build_group_legend_plot(grouping)
  expect_s3_class(legend, "ggplot")
  expect_identical(legend$theme$legend.position, "bottom")
})

test_that("character, logical and factor columns are accepted", {
  d <- make_grouped()
  fit <- fit_grouped(d)
  expect_s3_class(plot(fit, group = "irrigated",
                       style = janusplot_style(show_shape_legend = FALSE)),
                  "ggplot")
  d$site <- factor(d$site, levels = c("s3", "s2", "s1", "unused"))
  fit <- fit_grouped(d)
  grouping <- janusplot:::.resolve_group(fit, "site", janusplot_style())
  expect_identical(levels(grouping$values), c("s3", "s2", "s1"))
})

test_that("group errors name a missing column and too many levels", {
  fit <- fit_grouped()
  expect_error(plot(fit, group = "region"), "region")
  expect_error(plot(fit, group = "region"), "site")
  expect_error(plot(fit, group = "x4"), "x4")
  expect_error(plot(fit, group = c("site", "irrigated")), "single column name")
  expect_error(plot(fit, group = "site",
                    style = janusplot_style(group_max_levels = 2L)),
               "3 levels")
  expect_error(plot(fit, group = "site",
                    style = janusplot_style(group_palette = c("red", "blue"))),
               "2 colours")
  # A numeric column of the fit is not a grouping.
  expect_error(plot(fit, group = "x1"), "factor, character or logical")
})

test_that("a vector group_palette is used in order and NA levels stay grey", {
  d <- make_grouped()
  d$site[1:5] <- NA
  fit <- fit_grouped(d)
  st <- janusplot_style(group_palette = c("red", "blue", "green", "black"))
  grouping <- janusplot:::.resolve_group(fit, "site", st)
  expect_identical(unname(grouping$colours), c("red", "blue", "green"))
  expect_true(anyNA(grouping$values))
  expect_s3_class(plot(fit, group = "site", style = st), "ggplot")
})

test_that("group never changes the fit or its table", {
  d <- make_grouped()
  fit <- fit_grouped(d)
  before <- fit$table
  p <- plot(fit, group = "site")
  expect_s3_class(p, "ggplot")
  expect_identical(fit$table, before)
  expect_identical(summary(fit), before)
  # Grouped and ungrouped views draw the same curves.
  face <- janusplot:::.pair_face(fit$pairs[[1L]], "yx")
  expect_identical(face$pred, fit_grouped(d)$pairs[[1L]]$pred_yx)
})

test_that("grouped cells keep points above the density threshold", {
  fit <- fit_grouped()
  grouping <- janusplot:::.resolve_group(fit, "site", janusplot_style())
  face <- janusplot:::.pair_face(fit$pairs[[1L]], "yx")
  points <- janusplot:::.cell_points(fit, face$var_x, face$var_y, grouping)
  cell <- janusplot:::.render_cell(
    fit$pairs[[1L]], "yx", points,
    style = janusplot_style(density_threshold = 10L),
    text_sizes = janusplot:::.cell_text_sizes(3L),
    group_colours = grouping$colours
  )
  geoms <- vapply(cell$layers, function(l) class(l$geom)[1L], character(1L))
  expect_true("GeomPoint" %in% geoms)
  expect_false("GeomBin2d" %in% geoms)
})
