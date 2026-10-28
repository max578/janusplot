# deviance_gap = deviance explained by the smooth minus deviance
# explained by the straight-line fit of the same ordered pair.

test_that("the gap is near zero on a linear pair with high deviance explained", {
  d <- make_linear_data(n = 200L)
  pr <- janusplot_data(d, vars = c("x1", "x2"))$pairs[[1L]]
  expect_gt(pr$dev_exp_yx, 0.5)
  expect_lt(pr$deviance_gap_yx, 0.02)
  expect_lt(pr$deviance_gap_xy, 0.02)
})

test_that("the gap equals the smooth's minus the line's deviance explained", {
  d <- make_nonlinear_data(n = 200L)
  pr <- janusplot_data(d, vars = c("x1", "x2"), engine = "gam")$pairs[[1L]]
  r2_line <- summary(stats::lm(x2 ~ x1, data = d))$r.squared
  expect_equal(pr$deviance_gap_yx, pr$dev_exp_yx - r2_line,
               tolerance = 1e-6)
  expect_gt(pr$deviance_gap_yx, 0.5)
})

test_that("the gap is bounded in [0, 1] in every cell", {
  d <- make_nonlinear_data(n = 150L)
  tab <- janusplot(d, with_data = TRUE)$data
  expect_true("deviance_gap" %in% names(tab))
  expect_true(all(tab$deviance_gap >= 0 & tab$deviance_gap <= 1))
})

test_that("colour_by = 'deviance_gap' encodes the gap, not deviance explained", {
  d <- make_nonlinear_data(n = 150L)
  tab <- janusplot(d, vars = c("x1", "x2", "x3"),
                   colour_by = "deviance_gap", with_data = TRUE)$data
  expect_equal(tab$colour_value, tab$deviance_gap)
  expect_false(isTRUE(all.equal(tab$colour_value, tab$dev_exp)))
  expect_identical(.colour_label("deviance_gap"), "Dev. gap")
})

test_that("the gap is computed under adjustment with the same terms", {
  d <- make_nonlinear_data(n = 200L)
  pr <- janusplot_data(d, vars = c("x1", "x2"), adjust = ~ s(x4),
                       engine = "gam")$pairs[[1L]]
  lin <- mgcv::gam(x2 ~ x1 + s(x4), data = d, method = "REML")
  expect_equal(pr$deviance_gap_yx,
               max(0, pr$dev_exp_yx - summary(lin)$dev.expl),
               tolerance = 1e-6)
})

test_that("a failed or empty fit carries an NA gap", {
  e <- .empty_fit_result("x", "y", 0L)
  expect_true(is.na(e$deviance_gap))
})
