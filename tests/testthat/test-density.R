# Tests for the density rendering: a cell whose n_used exceeds
# style$density_threshold draws its points as a binned density
# (GeomBin2d), one at or below it draws points (GeomPoint).

layer_geoms <- function(p) {
  unname(vapply(p$layers, function(l) class(l$geom)[1L], character(1L)))
}

render_default_cell <- function(fit, style) {
  face <- janusplot:::.pair_face(fit$pairs[[1L]], "yx")
  janusplot:::.render_cell(
    fit$pairs[[1L]], "yx",
    points = janusplot:::.cell_points(fit, face$var_x, face$var_y),
    style = style, text_sizes = janusplot:::.cell_text_sizes(2L)
  )
}

test_that("a cell above the threshold uses GeomBin2d, below uses GeomPoint", {
  d <- make_nonlinear_data(n = 150L)
  fit <- janusplot_fit(d, vars = c("x1", "x2"), engine = "gam",
                       derivatives = integer())
  expect_identical(fit$pairs[[1L]]$n_used, 150L)
  dense <- render_default_cell(fit, janusplot_style(density_threshold = 100L))
  expect_identical(layer_geoms(dense), c("GeomBin2d", "GeomRibbon", "GeomLine"))
  expect_identical(dense$layers[[1L]]$stat_params$bins, 40L)
  points <- render_default_cell(fit, janusplot_style())
  expect_identical(layer_geoms(points), c("GeomPoint", "GeomRibbon", "GeomLine"))
  # The threshold is exclusive: n_used equal to it still draws points.
  at <- render_default_cell(fit, janusplot_style(density_threshold = 150L))
  expect_identical(layer_geoms(at)[1L], "GeomPoint")
  p <- plot(fit, style = janusplot_style(density_threshold = 100L,
                                         show_shape_legend = FALSE))
  expect_s3_class(p, "ggplot")
})

test_that(".cell_points_layer() decides on n_used and the grouping", {
  pts <- data.frame(x = stats::rnorm(20L), y = stats::rnorm(20L))
  st <- janusplot_style(density_threshold = 10L)
  dense <- janusplot:::.cell_points_layer(pts, st, n_used = 20L)
  expect_type(dense, "list")
  expect_s3_class(dense[[1L]]$geom, "GeomBin2d")
  sparse <- janusplot:::.cell_points_layer(pts, st, n_used = 10L)
  expect_s3_class(sparse$geom, "GeomPoint")
  expect_identical(sparse$aes_params$size, 0.4)
  expect_identical(sparse$aes_params$alpha, 0.25)
  pts$group <- factor(rep(c("a", "b"), 10L))
  grouped <- janusplot:::.cell_points_layer(pts, st, c(a = "red", b = "blue"),
                                            n_used = 20L)
  expect_s3_class(grouped[[1L]]$geom, "GeomPoint")
})

test_that("the density is drawn from the cell's own rows under pairwise NA", {
  d <- make_nonlinear_data(n = 150L)
  d$x2[1:30] <- NA
  fit <- janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam",
                       derivatives = integer())
  pr <- fit$pairs[[1L]]
  expect_identical(pr$n_used, 120L)
  rows <- janusplot:::.cell_rows(fit, "x1", "x2")
  expect_length(rows, pr$n_used)
  cell <- render_default_cell(fit, janusplot_style(density_threshold = 100L))
  expect_identical(nrow(cell$layers[[1L]]$data), 120L)
})
