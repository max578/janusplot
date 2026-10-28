# Each behaviour lives in the shared fitting internals; tests cover
# both janusplot() and janusplot_data().

make_odd_names_data <- function(n = 80L, seed = 11L) {
  withr::with_seed(seed, {
    x <- stats::runif(n, 0, 3)
    d <- data.frame(
      x,
      2 + sin(x) + stats::rnorm(n, sd = 0.3),
      x^2 + stats::rnorm(n, sd = 0.5),
      stats::rnorm(n),
      0.5 * x + stats::rnorm(n, sd = 0.4),
      stats::rnorm(n),
      check.names = FALSE
    )
  })
  names(d) <- c("grain yield (t/ha)", "N-rate %", "2019_yield",
                "a b", "a.b", "site name")
  d
}

odd_vars <- c("grain yield (t/ha)", "N-rate %", "2019_yield", "a b", "a.b")

test_that("janusplot_data() fits non-syntactic names and restores them", {
  d <- make_odd_names_data()
  res <- janusplot_data(d, vars = odd_vars, engine = "gam")
  expect_identical(res$vars, odd_vars)
  err <- c(vapply(res$pairs, `[[`, character(1L), "error_yx"),
           vapply(res$pairs, `[[`, character(1L), "error_xy"))
  expect_true(all(is.na(err)))
  expect_true(all(is.finite(vapply(res$pairs, `[[`, numeric(1L), "edf_yx"))))
  vi <- vapply(res$pairs, `[[`, character(1L), "var_i")
  vj <- vapply(res$pairs, `[[`, character(1L), "var_j")
  expect_setequal(unique(c(vi, vj)), odd_vars)
})

test_that("janusplot(with_data = TRUE) restores non-syntactic names", {
  d <- make_odd_names_data()
  out <- janusplot(d, vars = odd_vars, engine = "gam", with_data = TRUE)
  expect_s3_class(out$plot, "ggplot")
  tbl <- out$data
  expect_setequal(unique(c(tbl$var_x, tbl$var_y)), odd_vars)
  expect_true(all(is.na(tbl$error)))
  expect_true(all(is.finite(tbl$edf)))
})

test_that("adjust can reference a non-syntactic column with backticks", {
  d <- make_odd_names_data()
  vv <- c("grain yield (t/ha)", "N-rate %", "2019_yield")
  res <- janusplot_data(d, vars = vv, adjust = ~ `site name`,
                        engine = "gam")
  expect_true(all(is.na(vapply(res$pairs, `[[`, character(1L), "error_yx"))))
  expect_true(all(is.finite(vapply(res$pairs, `[[`, numeric(1L), "edf_yx"))))
  out <- janusplot(d, vars = vv, adjust = ~ s(`site name`, k = 4),
                   engine = "gam", with_data = TRUE)
  expect_true(all(is.na(out$data$error)))
})

test_that("restored names reach error messages of failed cells", {
  d <- make_odd_names_data()
  d[["a b"]] <- 1
  expect_warning(
    res <- janusplot_data(d, vars = c("a b", "a.b", "N-rate %"),
                          engine = "gam"),
    "failed to fit"
  )
  errs <- unlist(lapply(res$pairs, function(p) c(p$error_yx, p$error_xy)))
  errs <- errs[!is.na(errs)]
  expect_gt(length(errs), 0L)
  expect_false(any(grepl("a.b.1", errs, fixed = TRUE)))
  expect_false(any(grepl("N.rate..", errs, fixed = TRUE)))
})

test_that("syntactic names take a no-op path with identical results", {
  d <- make_linear_data(n = 80L)
  res <- janusplot_data(d, engine = "gam")
  # same data reached via the internal aliasing helper is unchanged
  al <- janusplot:::.alias_columns(d, names(d), NULL)
  expect_identical(al$data, d)
  expect_identical(al$vars, names(d))
  expect_false(al$aliased)
  expect_identical(res$vars, names(d))
})

test_that("per-variable k lists keyed by non-syntactic names are honoured", {
  d <- make_odd_names_data()
  res <- janusplot_data(d, vars = c("N-rate %", "a b"), engine = "gam",
                        k = list(`N-rate %` = 5L))
  p <- res$pairs[[1L]]
  expect_identical(p$var_i, "N-rate %")
  expect_equal(p$k_check_yx$k_initial, 5)
})

test_that("alias restoration in messages is whole-token and single-pass", {
  d <- make_odd_names_data()
  al <- janusplot:::.alias_columns(d, odd_vars, ~ `site name`)
  expect_true(al$aliased)
  expect_identical(unname(al$map[al$vars]), odd_vars)
  expect_identical(all.vars(al$adjust), "site.name")
  # make.names(unique = TRUE) keeps the already-valid "a.b" and moves
  # "a b" to "a.b.1"; restoring must not touch the kept name.
  expect_identical(unname(al$map[c("a.b", "a.b.1")]), c("a.b", "a b"))
  txt <- "s(a.b) vs a.b.1, X2019_yield and site.name; N.rate..x stays"
  expect_identical(
    janusplot:::.restore_names_in_text(txt, al$map),
    "s(a.b) vs a b, 2019_yield and site name; N.rate..x stays"
  )
})
