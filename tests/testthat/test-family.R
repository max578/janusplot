# A non-identity family: the curve and its band are drawn on the response
# scale, the shape label is read on the link scale, and the fit records
# the family so a comparison can name a difference.

# Both columns are counts: a family applies to every directed cell, so
# the reverse fit x ~ s(y) is a Poisson fit too.
make_poisson <- function(n = 200L) {
  withr::local_seed(2026L)
  x <- sample(0:20, n, replace = TRUE)
  data.frame(x = x, y = stats::rpois(n, exp(1 + x / 10)))
}

fit_family <- function(d, ...) {
  suppressMessages(
    janusplot_fit(d, engine = "gam", derivatives = integer(), ...)
  )
}

test_that("a Poisson curve is drawn on the response scale", {
  d <- make_poisson()
  fit <- fit_family(d, family = stats::poisson())
  pred <- fit$pairs[[1L]]$pred_yx
  # y ~ s(x): the mean runs from about e^1 to e^3
  expect_gt(max(pred$fit), 10)
  expect_true(all(pred$lo <= pred$fit & pred$fit <= pred$hi))
  expect_true(all(pred$lo >= 0))
  expect_equal(pred$fit, exp(pred$fit_link), tolerance = 1e-10)
})

test_that("the shape label is read from fit_link when it is present", {
  x <- seq(0, 2, length.out = 200L)
  raw <- data.frame(x = x, y = exp(1 + x))
  grid <- function(pred) list(pred = pred, raw = raw, x_name = "x", y_name = "y")
  link <- data.frame(x = x, fit = exp(1 + x), fit_link = 1 + x)
  resp <- data.frame(x = x, fit = exp(1 + x))
  classify <- function(g) {
    janusplot_shape_metrics(g)$shape_category
  }
  expect_identical(classify(grid(link)), "linear_up")
  expect_false(identical(classify(grid(resp)), "linear_up"))
})

test_that("an identity link leaves the prediction grid unchanged", {
  withr::local_seed(2026L)
  d <- data.frame(x = stats::rnorm(80L))
  d$y <- d$x + stats::rnorm(80L, sd = 0.5)
  fit <- fit_family(d)
  expect_named(fit$pairs[[1L]]$pred_yx, c("x", "fit", "se", "lo", "hi"))
})

test_that("the fit records family, link, discrete and nthreads", {
  fit <- fit_family(make_poisson(), family = stats::poisson())
  expect_identical(fit$settings$family, "poisson")
  expect_identical(fit$settings$link, "log")
  expect_false(fit$settings$discrete)
  expect_identical(fit$settings$nthreads, 1L)
  gauss <- fit_family(make_poisson())
  expect_identical(gauss$settings$family, "gaussian")
  expect_identical(gauss$settings$link, "identity")
})

test_that("a family given as a name or a function is recorded the same way", {
  d <- make_poisson()
  expect_identical(fit_family(d, family = "poisson")$settings$family, "poisson")
  expect_identical(fit_family(d, family = stats::poisson)$settings$family, "poisson")
})

test_that("a comparison names a difference in family", {
  d <- make_poisson()
  differ <- janusplot:::.compare_settings_differ(
    fit_family(d)$settings,
    fit_family(d, family = stats::poisson())$settings
  )
  expect_true(all(c("family", "link") %in% differ))
})
