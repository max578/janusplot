test_that("non-data-frame input is rejected", {
  expect_error(janusplot(1:10), class = "rlang_error")
})

test_that("too few rows is rejected", {
  expect_error(janusplot(data.frame(a = 1:3, b = 4:6)), class = "rlang_error")
})

test_that("vars must exist in data", {
  d <- make_linear_data(n = 50L)
  expect_error(janusplot(d, vars = c("x1", "missing")),
               class = "rlang_error")
})

test_that("vars must be numeric", {
  d <- data.frame(a = 1:30, g = factor(rep(c("a", "b"), 15L)))
  expect_error(janusplot(d, vars = c("a", "g")), class = "rlang_error")
})

test_that("adjust must be a one-sided formula", {
  d <- make_linear_data(n = 50L)
  expect_error(janusplot(d, adjust = "not a formula"),
               class = "rlang_error")
  expect_error(janusplot(d, adjust = y ~ x), class = "rlang_error")
})

test_that(".resolve_vars picks numeric columns by default", {
  d <- data.frame(a = 1:30, b = 1:30 + 0.5,
                  g = factor(rep(c("a", "b"), 15L)))
  out <- janusplot:::.resolve_vars(d, NULL)
  expect_equal(out, c("a", "b"))
})
