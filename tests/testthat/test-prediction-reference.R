# Population-level prediction under random-effect adjustment.
#
# Known truth: y = f(x) + b_site + e with f(x) = sin(2 * pi * x) and
# eight site effects that sum to zero. The population-level curve is
# f itself, so the plotted curve must sit on f and must not move when
# a different site becomes the most frequent one.

make_site_data <- function(modal_site = 1L, seed = 2026L) {
  withr::with_seed(seed, {
    b <- c(-3, -2, -1, -0.5, 0.5, 1, 2, 3)
    n_site <- rep(50L, 8L)
    n_site[modal_site] <- 80L
    site <- rep(seq_len(8L), times = n_site)
    x <- stats::runif(length(site))
    y <- sin(2 * pi * x) + b[site] + stats::rnorm(length(site), sd = 0.3)
    data.frame(
      x = x, y = y,
      site = factor(site, levels = seq_len(8L)),
      z = stats::rnorm(length(site))
    )
  })
}

curve_yx <- function(d, adjust) {
  out <- janusplot_fit(d, vars = c("x", "y"), adjust = adjust)
  out$pairs[[1L]]
}

test_that("the curve under a random effect sits on the population mean", {
  pr <- curve_yx(make_site_data(modal_site = 1L),
                 adjust = ~ s(site, bs = "re"))
  truth <- sin(2 * pi * pr$pred_yx$x)
  # Modal-site prediction would sit 3 units below the truth.
  expect_lt(abs(mean(pr$pred_yx$fit - truth)), 0.15)
})

test_that("making another site modal does not move the curve", {
  lo <- curve_yx(make_site_data(modal_site = 1L),
                 adjust = ~ s(site, bs = "re"))
  hi <- curve_yx(make_site_data(modal_site = 8L),
                 adjust = ~ s(site, bs = "re"))
  # Modal-site prediction would move by b[8] - b[1] = 6 units.
  expect_lt(abs(mean(lo$pred_yx$fit) - mean(hi$pred_yx$fit)), 0.2)
})

test_that("the random effect is recorded as excluded", {
  pr <- curve_yx(make_site_data(), adjust = ~ s(site, bs = "re"))
  ref <- pr$prediction_reference_yx
  expect_s3_class(ref, "data.frame")
  expect_identical(ref$variable, "site")
  expect_identical(ref$reference, "excluded (random effect)")
  expect_true(is.na(ref$value))
})

test_that("a numeric fixed covariate is averaged over the data and recorded", {
  d <- make_site_data()
  pr <- curve_yx(d, adjust = ~ s(z) + s(site, bs = "re"))
  expect_true(all(is.finite(pr$pred_yx$fit)))
  ref <- pr$prediction_reference_yx
  expect_identical(ref$variable, c("z", "site"))
  expect_identical(ref$reference[1L], "averaged over the data")
  expect_true(is.na(ref$value[1L]))
  expect_identical(ref$reference[2L], "excluded (random effect)")
  expect_lt(abs(mean(pr$pred_yx$fit - sin(2 * pi * pr$pred_yx$x))), 0.15)
})

test_that("a fixed factor is averaged over the data, not held at a level", {
  d <- make_site_data(modal_site = 3L)
  pr <- curve_yx(d, adjust = ~ site)
  ref <- pr$prediction_reference_yx
  expect_identical(ref$variable, "site")
  expect_identical(ref$reference, "averaged over the data")
  # Site effects weighted by their row counts: the averaged curve sits
  # that far from f, where the level of site 3 would sit at b[3] = -1.
  b <- c(-3, -2, -1, -0.5, 0.5, 1, 2, 3)
  w <- c(50, 50, 80, 50, 50, 50, 50, 50)
  avg <- sum(w * b) / sum(w)
  expect_lt(abs(mean(pr$pred_yx$fit - sin(2 * pi * pr$pred_yx$x)) - avg), 0.15)
})

test_that("a non-identity link keeps the typical-value reference", {
  d <- make_site_data(modal_site = 3L)
  d$count <- withr::with_seed(7L, stats::rpois(nrow(d), exp(1 + d$x)))
  fit <- suppressWarnings(janusplot_fit(d, vars = c("x", "count"),
                                        adjust = ~ site, family = poisson()))
  pr <- fit$pairs[[1L]]
  expect_identical(pr$prediction_reference_yx$reference, "3")
  expect_null(pr$partial_yx)
})

test_that("an unadjusted fit records an empty reference", {
  pr <- curve_yx(make_site_data(), adjust = NULL)
  expect_identical(nrow(pr$prediction_reference_yx), 0L)
})

test_that("each fit result carries its prediction reference", {
  d <- make_site_data()
  f <- .fit_pair("x", "y", d, adjust = ~ s(site, bs = "re"),
                 method = NULL, k = -1L, bs = "tp", na_action = "pairwise")
  expect_identical(f$prediction_reference$reference,
                   "excluded (random effect)")
  e <- .empty_fit_result("x", "y", 0L)
  expect_identical(nrow(e$prediction_reference), 0L)
})
