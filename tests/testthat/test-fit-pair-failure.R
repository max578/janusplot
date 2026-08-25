# A per-cell GAM fit can fail (e.g. a constant predictor gives mgcv's
# "term has fewer unique covariate combinations than k" error). This
# file asserts the failure is carried into the fit result, both public
# returns, and surfaced as a warning — never silently dropped (J3).

test_that(".fit_pair carries the mgcv error and reports n_used as unknown", {
  d <- data.frame(x1 = rep(1, 40), x2 = stats::rnorm(40))
  f <- janusplot:::.fit_pair(
    x_name = "x1", y_name = "x2", data_full = d,
    adjust = NULL, method = "REML", k = -1L, bs = "tp",
    na_action = "pairwise"
  )
  expect_true(is.character(f$error))
  expect_false(is.na(f$error))
  expect_true(nzchar(f$error))
  expect_true(is.na(f$n_used))
  expect_true(is.na(f$edf))
})

test_that("janusplot(with_data = TRUE) carries the error column and does not over-report n_used", {
  d <- data.frame(x1 = rep(1, 40), x2 = stats::rnorm(40), x3 = stats::rnorm(40))
  out <- suppressWarnings(
    janusplot(d, vars = c("x1", "x2", "x3"), with_data = TRUE)
  )
  tbl <- out$data
  expect_true("error" %in% names(tbl))
  failed_rows <- tbl[tbl$var_x == "x1" | tbl$var_y == "x1", ]
  expect_true(all(!is.na(failed_rows$error)))
  expect_true(all(is.na(failed_rows$n_used)))
})

test_that("janusplot_data() carries error_yx/error_xy into pairs_out", {
  d <- data.frame(x1 = rep(1, 40), x2 = stats::rnorm(40), x3 = stats::rnorm(40))
  res <- suppressWarnings(janusplot_data(d, vars = c("x1", "x2", "x3")))
  pair_x1_x2 <- res$pairs[[which(vapply(
    res$pairs, function(p) p$var_i == "x1" && p$var_j == "x2", logical(1L)
  ))]]
  expect_true("error_yx" %in% names(pair_x1_x2))
  expect_true("error_xy" %in% names(pair_x1_x2))
  expect_false(is.na(pair_x1_x2$error_yx))
  expect_false(is.na(pair_x1_x2$error_xy))
})

test_that("a failed cell emits a warning naming the failure", {
  d <- data.frame(x1 = rep(1, 40), x2 = stats::rnorm(40), x3 = stats::rnorm(40))
  expect_warning(
    janusplot_data(d, vars = c("x1", "x2", "x3")),
    "failed to fit"
  )
})
