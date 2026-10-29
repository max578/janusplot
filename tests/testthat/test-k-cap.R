skip_on_cran()  # heavy GAM-fit suite: full on CI, skipped on CRAN for time budget

# Tests for the per-pair basis-dimension cap: k_used = min(k requested or
# the mgcv default for `bs`, distinct x values in the pair's own rows).

skip_if_no_mgcv <- function() {
  testthat::skip_if_not_installed("mgcv")
}

# Six distinct predictor values; the default k (10 for bs = "tp") is
# above mgcv's limit and failed before the cap.
make_six_level_data <- function() {
  withr::with_seed(2026L, {
    n  <- 120L
    g  <- sample(seq_len(6L), n, replace = TRUE)
    y1 <- sin(g) + stats::rnorm(n, sd = 0.3)
    y2 <- stats::rnorm(n)
    data.frame(g = g, y1 = y1, y2 = y2)
  })
}

find_pair <- function(res, a, b) {
  for (p in res$pairs) {
    if (identical(p$var_i, a) && identical(p$var_j, b)) return(p)
  }
  NULL
}

test_that("x with 6 distinct values fits at the default k with k_used = 6", {
  skip_if_no_mgcv()
  df <- make_six_level_data()
  res <- suppressMessages(janusplot_fit(df, vars = c("g", "y1")))
  p <- find_pair(res, "g", "y1")
  # _yx is y1 ~ s(g): capped
  expect_true(is.na(p$error_yx))
  expect_true(is.finite(p$edf_yx))
  expect_identical(p$k_requested_yx, 10L)
  expect_identical(p$k_used_yx, 6L)
  expect_true(p$k_capped_yx)
  # _xy is g ~ s(y1): y1 has 120 distinct values, untouched
  expect_identical(p$k_used_xy, 10L)
  expect_false(p$k_capped_xy)
  expect_true(is.finite(p$asymmetry_index))
})

test_that("summary(janusplot_fit()) carries k_requested / k_used / k_capped", {
  skip_if_no_mgcv()
  df <- make_six_level_data()
  fit <- suppressMessages(janusplot_fit(df, vars = c("g", "y1")))
  tbl <- summary(fit)
  expect_s3_class(plot(fit), "ggplot")
  expect_true(all(c("k_requested", "k_used", "k_capped") %in% names(tbl)))
  row_g <- tbl[tbl$var_x == "g", ]
  expect_identical(row_g$k_used, 6L)
  expect_identical(row_g$k_requested, 10L)
  expect_true(row_g$k_capped)
  expect_true(is.finite(row_g$edf))
  row_y <- tbl[tbl$var_x == "y1", ]
  expect_false(row_y$k_capped)
  expect_type(tbl$k_capped, "logical")
  expect_type(tbl$k_used, "integer")
})

test_that("per-variable k is capped by the pair's own distinct count", {
  skip_if_no_mgcv()
  # x has 9 distinct values overall, so k = 8 is valid globally; y is
  # missing wherever x > 5, so the (x, y) pair keeps only 5 values.
  df <- withr::with_seed(2026L, {
    n <- 180L
    x <- rep(seq_len(9L), length.out = n)
    y <- x^2 / 10 + stats::rnorm(n, sd = 0.5)
    y[x > 5L] <- NA_real_
    z <- stats::rnorm(n)
    data.frame(x = x, y = y, z = z)
  })
  res <- suppressMessages(
    janusplot_fit(df, vars = c("x", "y", "z"), k = list(x = 8L))
  )
  p_xy <- find_pair(res, "x", "y")
  expect_true(is.na(p_xy$error_yx))
  expect_true(is.finite(p_xy$edf_yx))
  expect_identical(p_xy$k_requested_yx, 8L)
  expect_identical(p_xy$k_used_yx, 5L)
  expect_true(p_xy$k_capped_yx)
  p_xz <- find_pair(res, "x", "z")
  expect_identical(p_xz$k_used_yx, 8L)
  expect_false(p_xz$k_capped_yx)
})

test_that("a predictor with 20+ distinct values is untouched by the cap", {
  skip_if_no_mgcv()
  # Fixture EDFs recorded on the code before the cap existed, with
  # this exact data (seed 2026L, n = 200, x ~ U(0, 10),
  # y = sin(x) + N(0, 0.3^2)), default k = -1L, bs = "tp".
  df <- withr::with_seed(2026L, {
    n <- 200L
    x <- stats::runif(n, 0, 10)
    data.frame(x = x, y = sin(x) + stats::rnorm(n, sd = 0.3))
  })
  fixture <- list(
    bam = c(yx = 8.4512664198664,  xy = 2.33490992635927),
    gam = c(yx = 8.45126642275399, xy = 2.33492074760016)
  )
  for (eng in names(fixture)) {
    expect_no_message(res <- janusplot_fit(df, engine = eng))
    p <- res$pairs[[1L]]
    expect_false(p$k_capped_yx)
    expect_false(p$k_capped_xy)
    expect_identical(p$k_used_yx, 10L)
    expect_identical(p$k_used_xy, 10L)
    expect_equal(p$edf_yx, fixture[[eng]][["yx"]], tolerance = 1e-8)
    expect_equal(p$edf_xy, fixture[[eng]][["xy"]], tolerance = 1e-8)
  }
})

test_that("one inform per call names the capped variables and k used", {
  skip_if_no_mgcv()
  df <- withr::with_seed(2026L, {
    n <- 150L
    data.frame(
      dose6 = sample(seq_len(6L), n, replace = TRUE),
      rate4 = sample(seq_len(4L), n, replace = TRUE),
      contv = stats::rnorm(n)
    )
  })
  msgs <- testthat::capture_messages(janusplot_fit(df))
  cap_msgs <- msgs[grepl("basis dimension", msgs)]
  expect_length(cap_msgs, 1L)
  expect_match(cap_msgs, "dose6")
  expect_match(cap_msgs, "k = 6")
  expect_match(cap_msgs, "rate4")
  expect_match(cap_msgs, "k = 4")
  expect_no_match(cap_msgs, "contv")

  msgs_plot <- testthat::capture_messages(janusplot(df))
  expect_length(msgs_plot[grepl("basis dimension", msgs_plot)], 1L)
})

test_that("cap is resolved for other bases (cr, ps)", {
  skip_if_no_mgcv()
  df <- make_six_level_data()
  for (b in c("cr", "ps")) {
    res <- suppressMessages(
      janusplot_fit(df, vars = c("g", "y1"), bs = b, engine = "gam")
    )
    p <- find_pair(res, "g", "y1")
    expect_true(is.finite(p$edf_yx))
    expect_identical(p$k_requested_yx, 10L)
    expect_identical(p$k_used_yx, 6L)
    expect_true(p$k_capped_yx)
  }
})

test_that("auto_refit_k doubling never exceeds the distinct-value cap", {
  skip_if_no_mgcv()
  df <- withr::with_seed(13L, {
    n  <- 400L
    x  <- rep(seq(0, 10, length.out = 25L), length.out = n)
    data.frame(x = x, y = sin(3 * x) + stats::rnorm(n, sd = 0.2))
  })
  res <- suppressMessages(
    janusplot_fit(df, auto_refit_k = TRUE, k_max_iter = 4L)
  )
  p <- res$pairs[[1L]]
  # 25 distinct x values: the loop doubles 10 -> 20 and stops before 40.
  expect_gt(p$k_check_yx$k_iterations, 0L)
  expect_identical(p$k_used_yx, as.integer(p$k_check_yx$k_final))
  expect_lte(p$k_used_yx, 25L)
  expect_lte(p$k_check_yx$k_final, 25L)
})

test_that("a predictor below the basis minimum is not reported as capped", {
  skip_if_no_mgcv()
  df <- withr::with_seed(2026L, {
    n <- 60L
    data.frame(b2 = rep(c(0, 1), length.out = n), y = stats::rnorm(n))
  })
  msgs <- testthat::capture_messages(
    res <- suppressWarnings(janusplot_fit(df))
  )
  expect_false(any(grepl("basis dimension", msgs)))
  p <- res$pairs[[1L]]
  expect_false(p$k_capped_yx)
  expect_false(is.na(p$error_yx))
})

# ---------------------------------------------------------------
# The cap travels beside the asymmetry index
# ---------------------------------------------------------------

test_that("janusplot_fit() pairs carry k_capped_yx / k_capped_xy beside A", {
  skip_if_no_mgcv()
  df <- make_six_level_data()
  res <- suppressMessages(janusplot_fit(df, vars = c("g", "y1")))
  p <- res$pairs[[1L]]
  nm <- names(p)
  at <- which(nm == "asymmetry_index")
  expect_identical(nm[at + 1:2], c("k_capped_yx", "k_capped_xy"))
  expect_true(p$k_capped_yx)
  expect_false(p$k_capped_xy)
})

test_that("the per-cell table carries k_capped_yx / k_capped_xy beside A", {
  skip_if_no_mgcv()
  df <- make_six_level_data()
  tbl <- summary(suppressMessages(janusplot_fit(df, vars = c("g", "y1"))))
  at <- which(names(tbl) == "asymmetry_index")
  expect_identical(names(tbl)[at + 1:2], c("k_capped_yx", "k_capped_xy"))
  # Pair-level: both cells of the pair report the same flags, with _yx
  # the fit of the later variable on the earlier one (y1 ~ s(g)).
  expect_identical(tbl$k_capped_yx, c(TRUE, TRUE))
  expect_identical(tbl$k_capped_xy, c(FALSE, FALSE))
})

collect_cell_labels <- function(cell) {
  out <- character()
  for (lyr in cell$layers) {
    lbl <- lyr$aes_params$label
    if (!is.null(lbl)) out <- c(out, as.character(lbl))
  }
  out
}

build_k_warn_cell <- function(fit, direction, position) {
  face <- janusplot:::.pair_face(fit$pairs[[1L]], direction)
  janusplot:::.render_cell(
    fit$pairs[[1L]], direction,
    points = janusplot:::.cell_points(fit, face$var_x, face$var_y),
    style = janusplot_style(show_data = FALSE, show_ci = FALSE,
                            annotation_position = position),
    text_sizes = janusplot:::.cell_text_sizes(2L),
    annotations = "k_warn", display = "fit"
  )
}

test_that("k_warn fires on a capped cell", {
  skip_if_no_mgcv()
  df <- make_six_level_data()
  fit <- suppressMessages(janusplot_fit(df, vars = c("g", "y1"),
                                        engine = "gam"))
  pr <- fit$pairs[[1L]]
  # _yx is y1 ~ s(g): capped. The Wood trifecta cannot flag this cell
  # (fewer than 10 distinct x).
  expect_true(pr$k_capped_yx)
  expect_false(isTRUE(pr$k_check_yx$k_flag))
  expect_true("!" %in% collect_cell_labels(build_k_warn_cell(fit, "yx", "corners")))
  expect_identical(build_k_warn_cell(fit, "yx", "strip")$labels$subtitle, "!")

  # _xy is g ~ s(y1): y1 has 120 distinct values, untouched.
  expect_false(pr$k_capped_xy)
  expect_false(isTRUE(pr$k_check_xy$k_flag))
  expect_false("!" %in% collect_cell_labels(build_k_warn_cell(fit, "xy", "corners")))
  expect_null(build_k_warn_cell(fit, "xy", "strip")$labels$subtitle)
})
