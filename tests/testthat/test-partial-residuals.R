# Partial residuals under adjustment, and the averaged curve level.
#
# Known truth (Simpson's paradox): three groups with a common slope of
# +0.8 within each group and group means placed so that the pooled slope
# is negative. Partial residuals remove each row's group offset, so they
# rise with x while the raw values fall.

make_simpson_data <- function(n_per = 80L, seed = 11L) {
  withr::with_seed(seed, {
    g <- rep(c("a", "b", "c"), each = n_per)
    centre <- c(a = 0, b = 3, c = 6)[g]
    x <- centre + stats::rnorm(length(g))
    y <- -1.5 * centre + 0.8 * (x - centre) + stats::rnorm(length(g), sd = 0.4)
    data.frame(x = x, y = y, g = factor(g))
  })
}

test_that("an adjusted fit stores partial residuals that undo the reversal", {
  d <- make_simpson_data()
  fit <- janusplot_fit(d, vars = c("x", "y"), adjust = ~ g, engine = "gam",
                       derivatives = integer())
  pr <- fit$pairs[[1L]]
  expect_length(pr$partial_yx, nrow(d))
  expect_lt(stats::cor(d$x, d$y), -0.5)
  expect_gt(stats::cor(d$x, pr$partial_yx), 0.8)
  # The shift keeps the cloud at the data's mean level.
  expect_equal(mean(pr$partial_yx), mean(d$y), tolerance = 1e-8)
  # The averaged curve passes through the partial-residual cloud.
  curve_at_x <- stats::approx(pr$pred_yx$x, pr$pred_yx$fit, xout = d$x,
                              rule = 2L)$y
  expect_lt(abs(mean(pr$partial_yx - curve_at_x)), 0.05)
})

test_that("an unadjusted fit stores no partial residuals", {
  fit <- janusplot_fit(make_simpson_data(), vars = c("x", "y"),
                       engine = "gam", derivatives = integer())
  expect_null(fit$pairs[[1L]]$partial_yx)
  expect_null(fit$pairs[[1L]]$partial_xy)
})

test_that("the cells draw partial residuals unless the style asks for raw", {
  d <- make_simpson_data()
  fit <- janusplot_fit(d, vars = c("x", "y"), adjust = ~ g, engine = "gam",
                       derivatives = integer())
  face <- janusplot:::.pair_face(fit$pairs[[1L]], "yx")
  pts <- janusplot:::.cell_points(fit, "x", "y", NULL,
    janusplot:::.face_partial(face, janusplot_style()))
  expect_equal(pts$y, face$partial)
  raw <- janusplot:::.cell_points(fit, "x", "y", NULL,
    janusplot:::.face_partial(face, janusplot_style(adjusted_points = "raw")))
  expect_equal(raw$y, d$y)
  expect_true(janusplot:::.partial_points_shown(fit, janusplot_style()))
  expect_false(janusplot:::.partial_points_shown(
    fit, janusplot_style(adjusted_points = "raw")))
})

test_that("the glossary names partial residuals when they are drawn", {
  txt <- janusplot:::.build_glossary_text(c("A", "signif"), "nonlinearity",
                                          adjusted = TRUE, partial = TRUE)
  expect_match(txt, "Points: partial residuals")
  txt_raw <- janusplot:::.build_glossary_text(c("A", "signif"), "nonlinearity",
                                              adjusted = TRUE)
  expect_no_match(txt_raw, "partial residuals")
})

test_that("adjusted_points is validated", {
  expect_error(janusplot_style(adjusted_points = "both"), "must be one of")
  expect_error(janusplot_style(identity_line = NA), "TRUE or FALSE")
})
