# Display rules added for 1.0.0: the dash for A on a pair with no
# significant direction, the identity line of the overlay, wrapped pair
# titles, the near-interpolation warning and the curve extractor.

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
  layers_of <- function(p) vapply(p$layers, function(l) class(l$geom)[1L],
                                  character(1L))
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
