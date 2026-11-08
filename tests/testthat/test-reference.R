# janusplot_reference(): structure, reproducibility and the cases it is
# built for. Small B keeps the suite fast; the calibration study lives in
# the workspace's simulation scripts.

make_uniform_line <- function(n = 150L, seed = 21L) {
  withr::with_seed(seed, {
    x <- stats::runif(n, -2, 2)
    data.frame(x = x, y = x + stats::rnorm(n, sd = 0.4))
  })
}

test_that("the reference returns two mechanism rows per pair", {
  fit <- janusplot_fit(make_uniform_line(), engine = "gam",
                       derivatives = integer())
  ref <- suppressMessages(janusplot_reference(fit, B = 9L, seed = 1L))
  expect_s3_class(ref, "janusplot_reference")
  expect_named(ref, c("var_x", "var_y", "mechanism", "n_used", "A",
                      "A_ref_median", "A_ref_q95", "p_value", "B_ok"))
  expect_identical(nrow(ref), 2L)
  expect_identical(ref$mechanism, c("x -> y", "y -> x"))
  expect_true(all(ref$p_value > 0 & ref$p_value <= 1))
  expect_true(all(ref$B_ok <= 9L))
  expect_length(attr(ref, "draws"), 2L)
  expect_equal(ref$A, rep(fit$pairs[[1L]]$asymmetry_index, 2L))
})

test_that("a seed makes the reference reproducible and leaves the stream", {
  fit <- janusplot_fit(make_uniform_line(), engine = "gam",
                       derivatives = integer())
  withr::local_seed(99L)
  before <- .Random.seed
  r1 <- suppressMessages(janusplot_reference(fit, B = 5L, seed = 3L))
  expect_identical(.Random.seed, before)
  r2 <- suppressMessages(janusplot_reference(fit, B = 5L, seed = 3L))
  expect_identical(r1$p_value, r2$p_value)
})

test_that("a straight line explains the uniform-predictor asymmetry", {
  fit <- janusplot_fit(make_uniform_line(n = 250L), engine = "gam",
                       derivatives = integer())
  ref <- suppressMessages(janusplot_reference(fit, B = 39L, seed = 4L))
  expect_gt(ref$p_value[ref$mechanism == "x -> y"], 0.05)
})

test_that("pairs can be chosen, and print and plot work", {
  fit <- janusplot_fit(make_linear_data(n = 100L)[, c("x1", "x2", "x3")],
                       engine = "gam", derivatives = integer())
  ref <- suppressMessages(janusplot_reference(fit, "x1", "x2", B = 5L,
                                              seed = 2L))
  expect_identical(unique(ref$var_x), "x1")
  lines <- testthat::capture_output_lines(print(ref))
  expect_match(lines[1L], "1 pair, B = 5 per mechanism")
  expect_true(any(grepl("^x1 <-> x2: A = ", lines)))
  expect_s3_class(plot(ref), "ggplot")
})

test_that("the reference refuses a non-Gaussian fit and bad arguments", {
  d <- make_uniform_line()
  d$count <- withr::with_seed(8L, stats::rpois(nrow(d), exp(1 + 0.3 * d$x)))
  fit_p <- suppressWarnings(janusplot_fit(d[, c("x", "count")],
                                          family = poisson(), engine = "gam",
                                          derivatives = integer()))
  expect_error(janusplot_reference(fit_p, B = 5L), "Gaussian family")
  fit <- janusplot_fit(d[, c("x", "y")], engine = "gam",
                       derivatives = integer())
  expect_error(janusplot_reference(fit, B = 0L), "positive integer")
  expect_error(janusplot_reference(fit, seed = "a"), "single number")
  expect_error(janusplot_reference(list(), B = 5L), "janusplot_fit")
})
