# Tests for janusplot_pair(): the two directions of one or more pairs of a
# fit, and the stacked layout of many pairs.
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
  expect_match(labs_left$subtitle,
               "^A [0-9.]+  EDF [0-9.]+  r -?[0-9.]+  n 200")
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
  expect_error(janusplot_pair(fit, "x9", "x2"), "not fitted")
  expect_error(janusplot_pair(fit, "x9", "x2"), "x2 ~ x9")
  expect_error(janusplot_pair(fit, "x9", "x2"), "x1")
  expect_error(janusplot_pair(fit, "x1", "x1"), "with itself")
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

# ---------------------------------------------------------------
# Many pairs
# ---------------------------------------------------------------

# The cells of a stacked layout, row by row: a wrap of plots keeps them
# in $patches$plots, the last cell is the object itself.
grid_cells <- function(p) c(p$patches$plots, list(p))

cell_title <- function(cell) {
  if (inherits(cell, "spacer")) return(NA_character_)
  ggplot2::get_labs(cell)$title
}

test_that("pairs are given as two vectors or as a two-column data frame", {
  fit <- pair_fit()
  by_vec <- janusplot_pair(fit, c("x1", "x1"), c("x2", "x3"))
  by_df  <- janusplot_pair(fit, data.frame(x = c("x1", "x1"),
                                           y = c("x2", "x3")))
  by_mat <- janusplot_pair(fit, cbind(c("x1", "x1"), c("x2", "x3")))
  for (p in list(by_vec, by_df, by_mat)) {
    expect_s3_class(p, "patchwork")
    # Two blocks in one stack, each block y ~ s(x) then x ~ s(y).
    expect_identical(
      vapply(grid_cells(p), cell_title, character(1L)),
      c("x2 ~ s(x1)", "x1 ~ s(x2)", "x3 ~ s(x1)", "x1 ~ s(x3)")
    )
  }
  # A factor data frame works the same.
  by_fac <- janusplot_pair(fit, data.frame(x = factor("x3"), y = factor("x2")))
  expect_identical(panel_titles(by_fac), c("x2 ~ s(x3)", "x3 ~ s(x2)"))
})

test_that("blocks fill stacks of nrow, side by side, in one aligned grid", {
  d <- make_nonlinear_data(n = 80L, seed = 2L)
  d$x5 <- d$x1 + d$x4
  d$x6 <- d$x2 - d$x3
  fit <- janusplot_fit(d, engine = "gam", derivatives = integer())
  all_pairs <- t(utils::combn(fit$vars, 2L))
  expect_identical(nrow(all_pairs), 15L)
  pairs <- as.data.frame(all_pairs[1:14, ], stringsAsFactors = FALSE)
  p <- janusplot_pair(fit, pairs, nrow = 5L)
  # Five rows of three stacks, two panels per block; the last stack holds
  # four blocks, so the last row ends in two spacers.
  expect_equal(p$patches$layout$ncol, 6)
  cells <- grid_cells(p)
  expect_length(cells, 30L)
  is_spacer <- vapply(cells, inherits, logical(1L), "spacer")
  expect_identical(which(is_spacer), c(29L, 30L))
  # The two panels of a block sit close; the space goes between blocks.
  margin_pt <- function(cell) as.numeric(cell$theme$plot.margin)
  expect_equal(margin_pt(cells[[1L]]), c(4, 1, 4, 11))
  expect_equal(margin_pt(cells[[2L]]), c(4, 11, 4, 1))
  # The first block of the second stack is the sixth pair, in row 1.
  expect_identical(
    vapply(cells[3:4], cell_title, character(1L)),
    sprintf(c("%2$s ~\ns(%1$s)", "%1$s ~\ns(%2$s)"), pairs[6L, 1L],
            pairs[6L, 2L])
  )
  # The second block of the first stack is the second pair, in row 2.
  expect_identical(
    cell_title(cells[[7L]]),
    sprintf("%2$s ~\ns(%1$s)", pairs[2L, 1L], pairs[2L, 2L])
  )
  # ncol gives the stack count; neither gives one stack up to five pairs.
  expect_equal(janusplot_pair(fit, pairs, ncol = 2L)$patches$layout$ncol, 4)
  one_stack <- janusplot_pair(fit, pairs[1:5, ])
  expect_equal(one_stack$patches$layout$ncol, 2)
  expect_identical(cell_title(grid_cells(one_stack)[[9L]]),
                   sprintf("%s ~ s(%s)", pairs[5L, 2L], pairs[5L, 1L]))
  expect_identical(janusplot:::.pair_stack_layout(14L),
                   list(nrow = 5L, ncol = 3L))
  expect_identical(janusplot:::.pair_stack_layout(14L, nrow = 5L),
                   list(nrow = 5L, ncol = 3L))
  expect_identical(janusplot:::.pair_stack_layout(14L, ncol = 2L),
                   list(nrow = 7L, ncol = 2L))
  expect_identical(janusplot:::.pair_stack_layout(5L),
                   list(nrow = 5L, ncol = 1L))
  expect_error(janusplot:::.pair_stack_layout(14L, nrow = 2L, ncol = 2L),
               "fewer than the 14")
  expect_error(janusplot:::.pair_stack_layout(3L, nrow = 0L), "nrow")
  expect_error(janusplot:::.pair_stack_layout(3L, ncol = 1.5), "ncol")
})

test_that("pair errors name every offending pair", {
  fit <- pair_fit()
  err <- expect_error(janusplot_pair(fit, c("x1", "x9", "x7"),
                                     c("x2", "x2", "x1")))
  expect_match(conditionMessage(err), "x2 ~ x9")
  expect_match(conditionMessage(err), "x1 ~ x7")
  expect_error(janusplot_pair(fit, c("x1", "x2", "x1"), c("x2", "x1", "x3")),
               "more than once")
  err <- expect_error(janusplot_pair(fit, c("x1", "x2", "x1"),
                                     c("x2", "x1", "x3")))
  expect_match(conditionMessage(err), "x2 ~ x1")
  expect_match(conditionMessage(err), "x1 ~ x2")
  expect_error(janusplot_pair(fit, c("x1", "x2"), "x3"), "same length")
  expect_error(janusplot_pair(fit, c("x1", NA), c("x2", "x3")), "without NA")
  expect_error(janusplot_pair(fit, "x1"), "two columns")
  expect_error(janusplot_pair(fit, data.frame(a = "x1")), "two columns")
})

test_that("the pair panels take the signed background", {
  fit <- pair_fit()
  pair <- fit$pairs[[1L]]
  expected <- janusplot:::.background_hex(pair$cor_pearson, "RdBu", 0.35)
  p <- janusplot_pair(fit, "x1", "x2")
  expect_identical(p[[1L]]$theme$panel.background$fill, expected)
  expect_identical(p[[2L]]$theme$panel.background$fill, expected)
  plain <- janusplot_pair(fit, "x1", "x2",
                          style = janusplot_style(pair_background = FALSE))
  expect_true(is.na(plain[[1L]]$theme$panel.background$fill))
  both <- janusplot_pair(fit, "x1", "x2", display = "both")
  expect_identical(both[[1L]]$theme$panel.background$fill, expected)
  # Adjusted curves take no background: the correlation is marginal.
  d <- make_nonlinear_data(n = 200L, seed = 2L)
  d$g <- factor(rep(c("a", "b", "c"), length.out = nrow(d)))
  adjusted <- janusplot_fit(d, vars = c("x1", "x2"), engine = "gam",
                            adjust = ~ s(g, bs = "re"))
  p_adj <- janusplot_pair(adjusted, "x1", "x2")
  expect_true(is.na(p_adj[[1L]]$theme$panel.background$fill))
  expect_true(is.na(p_adj[[2L]]$theme$panel.background$fill))
})

test_that("many overlay panels share one generic key", {
  fit <- pair_fit()
  p <- janusplot_pair(fit, c("x1", "x1"), c("x2", "x3"), display = "both")
  key <- p[[2L]]
  expect_identical(
    levels(key$data$curve),
    c("vertical ~ s(horizontal)", "horizontal ~ s(vertical)")
  )
})
