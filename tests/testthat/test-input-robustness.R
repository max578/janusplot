# Each behaviour lives in the shared fitting internals; tests cover
# both janusplot() and janusplot_fit().

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

test_that("janusplot_fit() fits non-syntactic names and restores them", {
  d <- make_odd_names_data()
  res <- janusplot_fit(d, vars = odd_vars, engine = "gam")
  expect_identical(res$vars, odd_vars)
  err <- c(vapply(res$pairs, `[[`, character(1L), "error_yx"),
           vapply(res$pairs, `[[`, character(1L), "error_xy"))
  expect_true(all(is.na(err)))
  expect_true(all(is.finite(vapply(res$pairs, `[[`, numeric(1L), "edf_yx"))))
  vi <- vapply(res$pairs, `[[`, character(1L), "var_i")
  vj <- vapply(res$pairs, `[[`, character(1L), "var_j")
  expect_setequal(unique(c(vi, vj)), odd_vars)
})

test_that("plot() and summary() restore non-syntactic names", {
  d <- make_odd_names_data()
  fit <- janusplot_fit(d, vars = odd_vars, engine = "gam")
  expect_s3_class(plot(fit), "ggplot")
  tbl <- summary(fit)
  expect_setequal(unique(c(tbl$var_x, tbl$var_y)), odd_vars)
  expect_true(all(is.na(tbl$error)))
  expect_true(all(is.finite(tbl$edf)))
})

test_that("adjust can reference a non-syntactic column with backticks", {
  d <- make_odd_names_data()
  vv <- c("grain yield (t/ha)", "N-rate %", "2019_yield")
  res <- janusplot_fit(d, vars = vv, adjust = ~ `site name`,
                        engine = "gam")
  expect_true(all(is.na(vapply(res$pairs, `[[`, character(1L), "error_yx"))))
  expect_true(all(is.finite(vapply(res$pairs, `[[`, numeric(1L), "edf_yx"))))
  fit <- janusplot_fit(d, vars = vv, adjust = ~ s(`site name`, k = 4),
                       engine = "gam")
  expect_true(all(is.na(summary(fit)$error)))
  expect_s3_class(plot(fit), "ggplot")
})

test_that("restored names reach error messages of failed cells", {
  d <- make_odd_names_data()
  d[["a b"]] <- 1
  expect_warning(
    res <- janusplot_fit(d, vars = c("a b", "a.b", "N-rate %"),
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
  res <- janusplot_fit(d, engine = "gam")
  # same data reached via the internal aliasing helper is unchanged
  al <- janusplot:::.alias_columns(d, names(d), NULL)
  expect_identical(al$data, d)
  expect_identical(al$vars, names(d))
  expect_false(al$aliased)
  expect_identical(res$vars, names(d))
})

test_that("per-variable k lists keyed by non-syntactic names are honoured", {
  d <- make_odd_names_data()
  res <- janusplot_fit(d, vars = c("N-rate %", "a b"), engine = "gam",
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
    res <- janusplot_fit(d, vars = c("x1", "x2", "x3"),
                          adjust = ~ site_year, engine = "gam"),
    "site_year"
  )
  expect_true(all(is.na(vapply(res$pairs, `[[`, character(1L), "error_yx"))))
  msgs <- testthat::capture_messages(
    janusplot(d, vars = c("x1", "x2", "x3"),
              adjust = ~ s(site_year, bs = "re") + irrigated,
              engine = "gam")
  )
  coerce_msgs <- grep("factor", msgs, value = TRUE)
  expect_length(coerce_msgs, 1L)
  expect_match(coerce_msgs, "site_year")
  expect_match(coerce_msgs, "irrigated")
})

test_that("random-effect terms work on a coerced character column", {
  d <- make_grouped_data()
  fit <- suppressMessages(
    janusplot_fit(d, vars = c("x1", "x2", "x3"),
                  adjust = ~ s(site_year, bs = "re"), engine = "gam")
  )
  expect_true(all(is.na(summary(fit)$error)))
  expect_true(all(is.finite(summary(fit)$edf)))
  expect_s3_class(plot(fit, group = "site_year"), "ggplot")
  res <- suppressMessages(
    janusplot_fit(d, vars = c("x1", "x2"),
                   adjust = ~ s(site_year, bs = "re"),
                   engine = "bam", keep_fits = TRUE)
  )
  expect_true(is.factor(res$pairs[[1L]]$fit_yx$model$site_year))
})

test_that("factor adjust columns trigger no coercion message", {
  d <- make_grouped_data()
  d$site_year <- factor(d$site_year)
  msgs <- testthat::capture_messages(
    janusplot_fit(d, vars = c("x1", "x2"),
                   adjust = ~ s(site_year, bs = "re"), engine = "gam")
  )
  expect_false(any(grepl("factor", msgs)))
})

test_that("infinite values are treated as missing with one warning", {
  d <- make_linear_data(n = 80L)
  d$x1[c(3L, 9L)] <- c(Inf, -Inf)
  d$x3[5L] <- Inf
  w <- testthat::capture_warnings(
    res <- janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam")
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

test_that("janusplot_fit() drops infinite values and plot() draws those rows", {
  d <- make_linear_data(n = 80L)
  d$x2[1:4] <- Inf
  expect_warning(
    fit <- janusplot_fit(d, vars = c("x1", "x2"), engine = "gam"),
    "x2"
  )
  tbl <- summary(fit)
  expect_true(all(tbl$n_used == 76L))
  expect_true(all(is.na(tbl$error)))
  expect_length(janusplot:::.cell_rows(fit, "x1", "x2"), 76L)
  expect_silent(p <- plot(fit))
  expect_s3_class(p, "ggplot")
})

test_that("na_action = 'complete' also drops infinite rows", {
  d <- make_linear_data(n = 80L)
  d$x3[2L] <- -Inf
  res <- suppressWarnings(
    janusplot_fit(d, vars = c("x1", "x2", "x3"), na_action = "complete",
                   engine = "gam")
  )
  expect_true(all(vapply(res$pairs, `[[`, integer(1L), "n_used") == 79L))
})

make_disjoint_data <- function(n = 80L, seed = 13L) {
  withr::with_seed(seed, {
    x1 <- stats::rnorm(n)
    d <- data.frame(
      x1 = x1,
      x2 = 0.8 * x1 + stats::rnorm(n, sd = 0.5),
      x3 = sin(x1) + stats::rnorm(n, sd = 0.3)
    )
  })
  half <- seq_len(n / 2L)
  d$x1[half] <- NA
  d$x2[-half] <- NA
  d
}

test_that("a pair with no shared rows warns once and leaves other cells intact", {
  d <- make_disjoint_data()
  w <- testthat::capture_warnings(
    res <- janusplot_fit(d, engine = "gam")
  )
  expect_length(w, 1L)
  expect_match(w, "fewer than 5")
  expect_match(w, "x1")
  expect_match(w, "x2")
  expect_match(w, "n = 0", fixed = TRUE)
  p12 <- res$pairs[[1L]]
  expect_identical(c(p12$var_i, p12$var_j), c("x1", "x2"))
  expect_identical(p12$n_used, 0L)
  expect_true(is.na(p12$edf_yx))
  others <- res$pairs[-1L]
  expect_true(all(is.finite(vapply(others, `[[`, numeric(1L), "edf_yx"))))
})

test_that("janusplot() renders a matrix with a sparse pair", {
  d <- make_disjoint_data()
  d$x2[1:3] <- d$x1[1:3] <- 1
  w <- testthat::capture_warnings(
    fit <- janusplot_fit(d, engine = "gam")
  )
  expect_length(w, 1L)
  expect_match(w, "n = 3", fixed = TRUE)
  expect_silent(p <- plot(fit))
  expect_s3_class(p, "ggplot")
  tbl <- summary(fit)
  sparse <- (tbl$var_x %in% c("x1", "x2")) & (tbl$var_y %in% c("x1", "x2"))
  expect_true(all(tbl$n_used[sparse] == 3L))
  expect_true(all(is.finite(tbl$edf[!sparse])))
  f <- withr::local_tempfile(fileext = ".png")
  expect_no_error(ggplot2::ggsave(f, p, width = 5, height = 5))
})

test_that("failed and sparse cells share one warning", {
  d <- make_disjoint_data()
  d$x4 <- 1
  w <- testthat::capture_warnings(janusplot_fit(d, engine = "gam"))
  expect_length(w, 1L)
  expect_match(w, "failed to fit")
  expect_match(w, "fewer than 5")
})

test_that("an error is raised only when every pair has fewer than 5 rows", {
  d <- data.frame(a = c(1:4, rep(NA, 6)), b = c(rep(NA, 6), 1:4),
                  c = c(1, NA, 2, NA, 3, NA, 4, NA, 5, NA))
  expect_error(janusplot_fit(d, engine = "gam"), "fewer than 5")
  expect_error(janusplot(d, engine = "gam"), "fewer than 5")
})

make_collinear_data <- function(n = 60L, seed = 14L) {
  withr::with_seed(seed, {
    x1 <- stats::runif(n, 0, 3)
    data.frame(
      x1 = x1,
      x2 = x1,
      x3 = 2 * x1 + 1,
      x4 = sin(x1) + stats::rnorm(n, sd = 0.3)
    )
  })
}

test_that("identical and collinear columns route through the failed-cell path", {
  d <- make_collinear_data()
  w <- testthat::capture_warnings(
    res <- janusplot_fit(d, engine = "gam")
  )
  expect_length(w, 1L)
  expect_match(w, "failed to fit")
  pick <- function(a, b) {
    res$pairs[[which(vapply(res$pairs, function(p) {
      p$var_i == a && p$var_j == b
    }, logical(1L)))]]
  }
  p12 <- pick("x1", "x2")
  expect_match(p12$error_yx, "identical")
  expect_match(p12$error_yx, "x1")
  expect_match(p12$error_yx, "x2")
  expect_match(p12$error_xy, "identical")
  p13 <- pick("x1", "x3")
  expect_match(p13$error_yx, "collinear")
  expect_match(p13$error_yx, "x3")
  expect_true(is.na(p13$n_used))
  p14 <- pick("x1", "x4")
  expect_true(is.na(p14$error_yx))
  expect_true(is.finite(p14$edf_yx))
})

test_that("a constant column is named in both directions", {
  withr::local_seed(2026L)
  d <- data.frame(a = stats::rnorm(60L), b = stats::rnorm(60L), k = 5)
  expect_warning(
    fit <- janusplot_fit(d, engine = "gam", derivatives = integer()),
    "failed to fit"
  )
  tbl <- summary(fit)
  err <- tbl$error[tbl$var_x == "k" | tbl$var_y == "k"]
  expect_length(err, 4L)
  expect_true(all(grepl("`k` is constant", err, fixed = TRUE)))
  expect_false(any(grepl("foreign function|unique covariate", err)))
  expect_true(all(is.finite(tbl$edf[tbl$var_x != "k" & tbl$var_y != "k"])))
})

test_that("the per-cell table carries the collinearity message", {
  d <- make_collinear_data()
  names(d)[2L] <- "x1 copy"
  expect_warning(
    fit <- janusplot_fit(d, engine = "gam"),
    "failed to fit"
  )
  expect_s3_class(plot(fit), "ggplot")
  tbl <- summary(fit)
  row <- tbl[tbl$var_x == "x1" & tbl$var_y == "x1 copy", ]
  expect_match(row$error, "`x1 copy`", fixed = TRUE)
  expect_match(row$error, "identical")
  expect_true(all(is.finite(tbl$edf[tbl$var_y == "x4"])))
})
