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

make_grouped_data <- function(n = 90L, seed = 12L) {
  withr::with_seed(seed, {
    g <- rep(c("s1", "s2", "s3"), length.out = n)
    eff <- c(s1 = -1, s2 = 0, s3 = 1)[g]
    x1 <- stats::runif(n, 0, 3)
    data.frame(
      x1 = x1,
      x2 = sin(x1) + eff + stats::rnorm(n, sd = 0.3),
      x3 = 0.5 * x1 + eff + stats::rnorm(n, sd = 0.3),
      site_year = g,
      irrigated = rep(c(TRUE, FALSE), length.out = n),
      stringsAsFactors = FALSE
    )
  })
}

test_that("character adjust columns are coerced to factor with one inform", {
  d <- make_grouped_data()
  expect_message(
    res <- janusplot_data(d, vars = c("x1", "x2", "x3"),
                          adjust = ~ site_year, engine = "gam"),
    "site_year"
  )
  expect_true(all(is.na(vapply(res$pairs, `[[`, character(1L), "error_yx"))))
  msgs <- testthat::capture_messages(
    janusplot(d, vars = c("x1", "x2", "x3"),
              adjust = ~ s(site_year, bs = "re") + irrigated,
              engine = "gam", with_data = TRUE)
  )
  coerce_msgs <- grep("factor", msgs, value = TRUE)
  expect_length(coerce_msgs, 1L)
  expect_match(coerce_msgs, "site_year")
  expect_match(coerce_msgs, "irrigated")
})

test_that("random-effect terms work on a coerced character column", {
  d <- make_grouped_data()
  out <- suppressMessages(
    janusplot(d, vars = c("x1", "x2", "x3"),
              adjust = ~ s(site_year, bs = "re"),
              engine = "gam", with_data = TRUE)
  )
  expect_true(all(is.na(out$data$error)))
  expect_true(all(is.finite(out$data$edf)))
  res <- suppressMessages(
    janusplot_data(d, vars = c("x1", "x2"),
                   adjust = ~ s(site_year, bs = "re"),
                   engine = "bam", keep_fits = TRUE)
  )
  expect_true(is.factor(res$pairs[[1L]]$fit_yx$model$site_year))
})

test_that("factor adjust columns trigger no coercion message", {
  d <- make_grouped_data()
  d$site_year <- factor(d$site_year)
  msgs <- testthat::capture_messages(
    janusplot_data(d, vars = c("x1", "x2"),
                   adjust = ~ s(site_year, bs = "re"), engine = "gam")
  )
  expect_false(any(grepl("factor", msgs)))
})

test_that("infinite values are treated as missing with one warning", {
  d <- make_linear_data(n = 80L)
  d$x1[c(3L, 9L)] <- c(Inf, -Inf)
  d$x3[5L] <- Inf
  w <- testthat::capture_warnings(
    res <- janusplot_data(d, vars = c("x1", "x2", "x3"), engine = "gam")
  )
  expect_length(w, 1L)
  expect_match(w, "x1")
  expect_match(w, "x3")
  expect_match(w, "infinite", ignore.case = TRUE)
  expect_true(all(is.na(vapply(res$pairs, `[[`, character(1L), "error_yx"))))
  n_used <- stats::setNames(
    vapply(res$pairs, `[[`, integer(1L), "n_used"),
    vapply(res$pairs, function(p) paste(p$var_i, p$var_j), character(1L))
  )
  expect_identical(unname(n_used[c("x1 x2", "x1 x3", "x2 x3")]),
                   c(78L, 77L, 79L))
})

test_that("janusplot() drops infinite values and reports n_used", {
  d <- make_linear_data(n = 80L)
  d$x2[1:4] <- Inf
  expect_warning(
    out <- janusplot(d, vars = c("x1", "x2"), engine = "gam",
                     with_data = TRUE),
    "x2"
  )
  expect_true(all(out$data$n_used == 76L))
  expect_true(all(is.na(out$data$error)))
})

test_that("na_action = 'complete' also drops infinite rows", {
  d <- make_linear_data(n = 80L)
  d$x3[2L] <- -Inf
  res <- suppressWarnings(
    janusplot_data(d, vars = c("x1", "x2", "x3"), na_action = "complete",
                   engine = "gam")
  )
  expect_true(all(vapply(res$pairs, `[[`, integer(1L), "n_used") == 79L))
})
