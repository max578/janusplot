# Shared synthetic datasets for tests.
# Pinned seed + simple generators keep expected statistics stable.

make_linear_data <- function(n = 200L, seed = 1L) {
  withr::with_seed(seed, {
    x1 <- stats::rnorm(n)
    x2 <- 1 + 0.8 * x1 + stats::rnorm(n, sd = 0.5)
    x3 <- stats::rnorm(n)
    x4 <- 0.3 * x1 - 0.2 * x3 + stats::rnorm(n, sd = 0.4)
    data.frame(x1 = x1, x2 = x2, x3 = x3, x4 = x4)
  })
}

make_nonlinear_data <- function(n = 200L, seed = 2L) {
  withr::with_seed(seed, {
    x1 <- stats::runif(n, -3, 3)
    x2 <- x1^2 + stats::rnorm(n, sd = 0.6)
    x3 <- sin(x1) + stats::rnorm(n, sd = 0.4)
    x4 <- stats::rnorm(n)
    data.frame(x1 = x1, x2 = x2, x3 = x3, x4 = x4)
  })
}

make_heteroscedastic_data <- function(n = 300L, seed = 3L) {
  withr::with_seed(seed, {
    x1 <- stats::runif(n, 0, 5)
    x2 <- 0.5 * x1 + stats::rnorm(n, sd = 0.3 + 0.4 * x1)
    x3 <- stats::rnorm(n)
    data.frame(x1 = x1, x2 = x2, x3 = x3)
  })
}
