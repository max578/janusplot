# Tests for janusplot_pair(): the two directions of one pair of a fit.
# Every fit pins engine = "gam" so the drawn EDFs and curves are stable.

pair_fit <- function(...) {
  d <- make_nonlinear_data(n = 200L, seed = 2L)
  janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam", ...)
}

# The title of each of the two side-by-side panels.
panel_titles <- function(p) {
  vapply(list(p[[1L]], p[[2L]]), function(panel) {
    ggplot2::get_labs(panel)$title
  }, character(1L))
}

# ---------------------------------------------------------------
# Return value and panel order
# ---------------------------------------------------------------

test_that("janusplot_pair() returns a ggplot of two panels", {
  p <- janusplot_pair(pair_fit(), "x1", "x2")
  expect_s3_class(p, "ggplot")
  expect_s3_class(p, "patchwork")
  expect_length(p$patches$plots, 1L)
})

test_that("the left panel is y ~ s(x) whichever order the pair is given in", {
  fit <- pair_fit()
  expect_identical(panel_titles(janusplot_pair(fit, "x1", "x2")),
                   c("x2 ~ s(x1)", "x1 ~ s(x2)"))
  expect_identical(panel_titles(janusplot_pair(fit, "x2", "x1")),
                   c("x1 ~ s(x2)", "x2 ~ s(x1)"))
  # The curve of the left panel runs over the range of x.
  p <- janusplot_pair(fit, "x2", "x1")
  built <- ggplot2::ggplot_build(p[[1L]])
  curve_x <- range(built$data[[length(built$data)]]$x)
  expect_equal(curve_x, range(fit$data$x2), tolerance = 1e-8)
})

test_that("the panels carry axis titles and the full strip", {
  fit <- pair_fit()
  p <- janusplot_pair(fit, "x1", "x2")
  labs_left <- ggplot2::get_labs(p[[1L]])
  expect_identical(labs_left$x, "x1")
  expect_identical(labs_left$y, "x2")
  expect_match(labs_left$subtitle, "^A [0-9.]+  EDF [0-9.]+  n 200")
})

test_that("the title carries the adjust terms of the fit", {
  d <- make_nonlinear_data(n = 120L, seed = 2L)
  d$g <- factor(rep(c("a", "b", "c"), length.out = nrow(d)))
  fit <- janusplot_fit(d, vars = c("x1", "x2"), engine = "gam",
                       adjust = ~ s(g, bs = "re"))
  expect_identical(
    panel_titles(janusplot_pair(fit, "x1", "x2")),
    c('x2 ~ s(x1) + s(g, bs = "re")', 'x1 ~ s(x2) + s(g, bs = "re")')
  )
})

# ---------------------------------------------------------------
# Validation
# ---------------------------------------------------------------

test_that("malformed calls are refused with a named cause", {
  fit <- pair_fit()
  expect_error(janusplot_pair(mtcars, "mpg", "hp"), "janusplot_fit")
  expect_error(janusplot_pair(fit, "x9", "x2"), "not a fitted variable")
  expect_error(janusplot_pair(fit, "x9", "x2"), "x1")
  expect_error(janusplot_pair(fit, "x1", "x1"), "different variables")
  expect_error(janusplot_pair(fit, "x1", "x2", display = "d3"), "display")
  expect_error(janusplot_pair(fit, "x1", "x2", style = list()),
               "janusplot_style")
})

test_that("a derivative view needs that order in the fit", {
  fit <- pair_fit(derivatives = integer())
  expect_error(janusplot_pair(fit, "x1", "x2", display = "d1"),
               "derivative order")
})

test_that("display = \"d1\" and \"d2\" draw the derivative panels", {
  fit <- pair_fit()
  for (display in c("d1", "d2")) {
    p <- janusplot_pair(fit, "x1", "x2", display = display)
    expect_s3_class(p, "ggplot")
    expect_match(ggplot2::get_labs(p[[1L]])$y, "/ d x1")
    expect_no_error(ggplot2::ggplot_build(p[[2L]]))
  }
})

# ---------------------------------------------------------------
# Grouping
# ---------------------------------------------------------------

test_that("group colours the points and adds the legend", {
  d <- make_nonlinear_data(n = 120L, seed = 2L)
  d$arm <- factor(rep(c("control", "treated"), length.out = nrow(d)))
  fit <- janusplot_fit(d, vars = c("x1", "x2"), engine = "gam")
  p <- janusplot_pair(fit, "x1", "x2", group = "arm")
  expect_s3_class(p, "patchwork")
  # The two panels sit above the group legend.
  legend <- p[[2L]]
  expect_identical(legend$scales$get_scales("colour")$name, "arm")
  left <- p[[1L]][[1L]]
  point_layer <- Filter(function(l) inherits(l$geom, "GeomPoint"),
                        left$layers)[[1L]]
  expect_true("group" %in% names(point_layer$data))
  expect_error(janusplot_pair(fit, "x1", "x2", group = "x9"), "not in")
})

# ---------------------------------------------------------------
# The overlay panel
# ---------------------------------------------------------------

test_that("display = \"both\" draws both curves in the z-score plane", {
  fit <- pair_fit()
  p <- janusplot_pair(fit, "x1", "x2", display = "both")
  expect_s3_class(p, "ggplot")
  panel <- p[[1L]]
  labs_panel <- ggplot2::get_labs(panel)
  expect_identical(labs_panel$x, "x1 (z-score)")
  expect_identical(labs_panel$y, "x2 (z-score)")
  expect_match(labs_panel$subtitle, "x2 ~ x1: EDF")
  expect_match(labs_panel$subtitle, "x1 ~ x2: EDF")
  built <- ggplot2::ggplot_build(panel)
  colours <- unlist(lapply(built$data, function(d) unique(d$colour)))
  expect_true(all(c("#08306b", "#d95f02") %in% colours))
  # Points are standardised: mean zero on both axes.
  pts <- built$data[[1L]]
  expect_equal(mean(pts$x), 0, tolerance = 1e-8)
  expect_equal(mean(pts$y), 0, tolerance = 1e-8)
})

test_that("display = \"both\" takes the group legend under the key", {
  d <- make_nonlinear_data(n = 120L, seed = 2L)
  d$arm <- factor(rep(c("control", "treated"), length.out = nrow(d)))
  fit <- janusplot_fit(d, vars = c("x1", "x2"), engine = "gam")
  p <- janusplot_pair(fit, "x1", "x2", display = "both", group = "arm")
  expect_length(p$patches$plots, 2L)
  expect_identical(p[[3L]]$scales$get_scales("colour")$name, "arm")
})

# ---------------------------------------------------------------
# Visual snapshots
# ---------------------------------------------------------------

test_that("the default pair matches its snapshot", {
  skip_if_not_installed("vdiffr")
  fit <- pair_fit()
  vdiffr::expect_doppelganger("pair-quadratic-default",
                              janusplot_pair(fit, "x1", "x2"))
})

test_that("the overlay pair matches its snapshot", {
  skip_if_not_installed("vdiffr")
  fit <- pair_fit()
  vdiffr::expect_doppelganger(
    "pair-quadratic-both",
    janusplot_pair(fit, "x1", "x2", display = "both")
  )
})
