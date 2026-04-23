# Tests for the single-display derivative view in janusplot().
# The matrix renders one quantity at a time: "fit", "d1", or "d2".
# Derivative CI rendering is off by default; opt-in via
# derivative_ci = "pointwise" or "simultaneous" (Simpson 2018 MC).

# ---------------------------------------------------------------
# Numerical correctness of .derivatives_lpmatrix()
# ---------------------------------------------------------------

test_that(".derivatives_lpmatrix recovers the true d1 of sin(3x)", {
  withr::with_seed(2026L, {
    n  <- 500L
    x  <- stats::runif(n, -pi, pi)
    y  <- sin(3 * x) + stats::rnorm(n, sd = 0.15)
  })
  d    <- data.frame(x = x, y = y)
  fit  <- mgcv::gam(y ~ s(x, k = 40L), data = d, method = "REML")
  x_g  <- seq(-pi, pi, length.out = 200L)
  nd   <- data.frame(x = x_g)
  dv   <- janusplot:::.derivatives_lpmatrix(fit, nd, x_g, orders = 1:2)

  expect_named(dv, c("1", "2"))
  expect_s3_class(dv[["1"]], "data.frame")
  expect_identical(names(dv[["1"]]), c("x", "fit", "se", "lo", "hi"))
  expect_identical(nrow(dv[["1"]]), 200L)
  expect_true(all(dv[["1"]]$se >= 0))
  expect_true(all(dv[["2"]]$se >= 0))

  int  <- which(x_g > -0.8 * pi & x_g < 0.8 * pi)
  truth_d1 <- 3 * cos(3 * x_g[int])
  truth_d2 <- -9 * sin(3 * x_g[int])
  rmse_d1  <- sqrt(mean((dv[["1"]]$fit[int] - truth_d1)^2))
  rmse_d2  <- sqrt(mean((dv[["2"]]$fit[int] - truth_d2)^2))

  expect_lt(rmse_d1, 0.5)
  expect_lt(rmse_d2, 3.0)
})

# ---------------------------------------------------------------
# Simultaneous-CI construction (Simpson 2018)
# ---------------------------------------------------------------

test_that("simultaneous bands are wider than pointwise, critical >= 1.96", {
  withr::with_seed(2026L, {
    n <- 300L
    x <- stats::runif(n, -pi, pi)
    y <- sin(x) + stats::rnorm(n, sd = 0.2)
  })
  d <- data.frame(x = x, y = y)
  pw  <- janusplot_data(d, derivatives = 1L,
                        derivative_ci = "pointwise")
  sim <- janusplot_data(d, derivatives = 1L,
                        derivative_ci = "simultaneous",
                        derivative_ci_nsim = 2000L)
  dfp <- pw$pairs[[1L]]$deriv_yx[["1"]]
  dfs <- sim$pairs[[1L]]$deriv_yx[["1"]]
  expect_identical(unique(dfp$ci_type), "pointwise")
  expect_identical(unique(dfs$ci_type), "simultaneous")
  w_pw  <- mean(dfp$hi - dfp$lo)
  w_sim <- mean(dfs$hi - dfs$lo)
  expect_gt(w_sim, w_pw)
  crit <- attr(dfs, "crit_multiplier")
  expect_true(is.finite(crit))
  expect_gt(crit, 1.96)
  expect_lt(crit, 6)   # sanity cap
})

test_that("derivative_ci = 'none' returns pointwise lo/hi but is tagged none", {
  d <- make_nonlinear_data(n = 150L, seed = 2L)
  out <- janusplot_data(d, vars = c("x1", "x2"),
                        derivatives = 1L, derivative_ci = "none")
  df <- out$pairs[[1L]]$deriv_yx[["1"]]
  expect_identical(unique(df$ci_type), "none")
  # lo/hi are still pointwise; the renderer honours the tag.
  expect_true(all(is.finite(df$lo)))
  expect_true(all(is.finite(df$hi)))
})

# ---------------------------------------------------------------
# Basis-robustness
# ---------------------------------------------------------------

test_that(".derivatives_lpmatrix works across bases (tp/cr/cs)", {
  d <- make_nonlinear_data(n = 200L, seed = 2L)
  for (bs_type in c("tp", "cr", "cs")) {
    fit <- mgcv::gam(x2 ~ s(x1, bs = bs_type), data = d, method = "REML")
    x_g <- seq(min(d$x1), max(d$x1), length.out = 120L)
    nd  <- data.frame(x1 = x_g)
    dv  <- janusplot:::.derivatives_lpmatrix(fit, nd, x_g, 1L)
    expect_true(
      is.data.frame(dv[["1"]]),
      info = sprintf("basis = %s produced no derivative", bs_type)
    )
    expect_true(all(is.finite(dv[["1"]]$fit)))
    expect_true(all(dv[["1"]]$se >= 0))
  }
})

# ---------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------

test_that(".derivatives_lpmatrix returns empty list on bad input", {
  expect_identical(
    janusplot:::.derivatives_lpmatrix(NULL, data.frame(), numeric(), 1L),
    list()
  )
  expect_identical(
    janusplot:::.derivatives_lpmatrix(NULL, data.frame(), 1:5, integer()),
    list()
  )
})

test_that(".diff_stencil returns NULL when the grid is too short", {
  X <- matrix(1:4, nrow = 2L)
  expect_null(janusplot:::.diff_stencil(X, h = 1, order = 1L))
  X4 <- matrix(1, nrow = 3L, ncol = 2L)
  expect_null(janusplot:::.diff_stencil(X4, h = 1, order = 2L))
})

test_that(".derivatives_simultaneous_bands returns empty list cleanly", {
  expect_identical(
    janusplot:::.derivatives_simultaneous_bands(
      NULL, data.frame(), numeric(), 1L, n_sim = 100L
    ),
    list()
  )
})

# ---------------------------------------------------------------
# adjust-term invariance
# ---------------------------------------------------------------

test_that("derivative estimates drop adjust covariates held at typical values", {
  d <- make_linear_data(n = 300L, seed = 4L)
  d$site <- factor(sample(letters[1:3], 300L, replace = TRUE))
  f_plain <- janusplot:::.fit_pair(
    x_name = "x1", y_name = "x2", data_full = d,
    adjust = NULL, method = "REML", k = -1L, bs = "tp",
    na_action = "pairwise", derivatives = 1L
  )
  f_adj <- janusplot:::.fit_pair(
    x_name = "x1", y_name = "x2", data_full = d,
    adjust = ~ s(site, bs = "re"),
    method = "REML", k = -1L, bs = "tp",
    na_action = "pairwise", derivatives = 1L
  )
  d1a <- f_plain$deriv[["1"]]$fit
  d1b <- f_adj$deriv[["1"]]$fit
  int <- seq(20, 80)
  rms_diff <- sqrt(mean((d1a[int] - d1b[int])^2))
  rms_lvl  <- sqrt(mean(d1a[int]^2))
  expect_lt(rms_diff / rms_lvl, 0.25)
})

# ---------------------------------------------------------------
# janusplot() integration — scalar display
# ---------------------------------------------------------------

test_that("janusplot(display = 'fit') returns the legacy single-panel cell type", {
  # Each off-diagonal cell must still be a plain ggplot (not a
  # patchwork) — this is the invariant that keeps legacy visual
  # snapshots interpretable.
  d <- make_linear_data(n = 120L, seed = 1L)
  f <- janusplot:::.fit_pair(
    x_name = "x1", y_name = "x2", data_full = d,
    adjust = NULL, method = "REML", k = -1L, bs = "tp",
    na_action = "pairwise"
  )
  cell <- janusplot:::.build_cell(
    fit_obj = f, show_data = TRUE, show_ci = TRUE,
    colour_by = "spearman", palette = "RdBu",
    signif_glyph = TRUE, annotations = c("edf", "A"),
    shape_cutoffs = janusplot_shape_cutoffs(),
    glyph_style = "ascii", asym_val = 0.1,
    colour_limits = c(-1, 1), is_upper = TRUE,
    text_sizes = janusplot:::.cell_text_sizes(3L),
    display = "fit"
  )
  expect_s3_class(cell, "ggplot")
  expect_false(inherits(cell, "patchwork"))
})

test_that("janusplot(display = 'd1') renders a derivative panel cell", {
  d <- make_nonlinear_data(n = 150L, seed = 2L)
  p <- janusplot(d, vars = c("x1", "x2"), display = "d1")
  expect_true(inherits(p, "ggplot") || inherits(p, "patchwork"))
})

test_that("janusplot(display = 'd2', derivative_ci = 'pointwise') runs", {
  d <- make_nonlinear_data(n = 150L, seed = 2L)
  p <- janusplot(d, vars = c("x1", "x2"),
                 display = "d2", derivative_ci = "pointwise")
  expect_true(inherits(p, "ggplot") || inherits(p, "patchwork"))
})

test_that("display validation rejects unknown values", {
  d <- make_linear_data(n = 60L, seed = 1L)
  expect_error(janusplot(d, vars = c("x1", "x2"), display = "d3"))
  expect_error(janusplot(d, vars = c("x1", "x2"),
                         display = c("fit", "d1")))   # vector no longer allowed
})

test_that("derivative_ci validation + nsim validation", {
  d <- make_linear_data(n = 60L, seed = 1L)
  expect_error(janusplot(d, vars = c("x1", "x2"),
                         display = "d1", derivative_ci = "banana"))
  expect_error(janusplot(d, vars = c("x1", "x2"),
                         display = "d1",
                         derivative_ci = "simultaneous",
                         derivative_ci_nsim = 10))
})

test_that("n_grid validation is strict and auto-resolves", {
  d <- make_linear_data(n = 60L, seed = 1L)
  expect_error(janusplot(d, vars = c("x1", "x2"), n_grid = 5))
  expect_error(janusplot(d, vars = c("x1", "x2"), n_grid = "fifty"))
  out <- janusplot_data(d, vars = c("x1", "x2"))
  expect_identical(nrow(out$pairs[[1L]]$pred_yx), 100L)
  out2 <- janusplot_data(d, vars = c("x1", "x2"), derivatives = 1L)
  expect_identical(nrow(out2$pairs[[1L]]$pred_yx), 200L)
  expect_identical(nrow(out2$pairs[[1L]]$deriv_yx[["1"]]), 200L)
})

# ---------------------------------------------------------------
# with_data = TRUE carries a `display` column
# ---------------------------------------------------------------

test_that("summary table tags display mode on every call", {
  d <- make_nonlinear_data(n = 120L, seed = 2L)
  out_fit <- janusplot(d, vars = c("x1", "x2"), with_data = TRUE)
  out_d1  <- janusplot(d, vars = c("x1", "x2"),
                       display = "d1", with_data = TRUE)
  out_d2  <- janusplot(d, vars = c("x1", "x2"),
                       display = "d2", with_data = TRUE)
  expect_true("display" %in% colnames(out_fit$data))
  expect_identical(unique(out_fit$data$display), "fit")
  expect_identical(unique(out_d1$data$display), "d1")
  expect_identical(unique(out_d2$data$display), "d2")
})

# ---------------------------------------------------------------
# janusplot_data() surfaces derivatives (multi-order allowed)
# ---------------------------------------------------------------

test_that("janusplot_data surfaces deriv_yx / deriv_xy with ci_type tag", {
  d <- make_nonlinear_data(n = 120L, seed = 2L)
  out <- janusplot_data(d, vars = c("x1", "x2"),
                        derivatives = c(1L, 2L),
                        derivative_ci = "pointwise")
  p   <- out$pairs[[1L]]
  expect_named(p$deriv_yx, c("1", "2"))
  expect_named(p$deriv_xy, c("1", "2"))
  expect_true(all(c("x", "fit", "se", "lo", "hi", "ci_type") %in%
                  names(p$deriv_yx[["1"]])))
  expect_identical(unique(p$deriv_yx[["1"]]$ci_type), "pointwise")
})

test_that("janusplot_data derivatives validation rejects bad orders", {
  d <- make_linear_data(n = 60L, seed = 1L)
  expect_error(janusplot_data(d, vars = c("x1", "x2"), derivatives = 3L))
  expect_error(janusplot_data(d, vars = c("x1", "x2"),
                              derivatives = c(1L, 1L)))
})

# ---------------------------------------------------------------
# Matrix title — what display mode labels the top of the plot
# ---------------------------------------------------------------

test_that("diagonal = 'density' renders a density+rug ggplot per variable", {
  d <- make_nonlinear_data(n = 200L, seed = 2L)
  p <- janusplot(d, vars = c("x1", "x2"), diagonal = "density",
                 show_shape_legend = FALSE, show_glossary = FALSE)
  expect_true(inherits(p, "ggplot") || inherits(p, "patchwork"))

  cell <- janusplot:::.build_density_rug_cell("x1", d$x1)
  expect_s3_class(cell, "ggplot")
  # Two layers in the data frame source (geom_area + geom_line +
  # geom_rug = 3 layers); the cell function must produce a real plot
  # not the blank fallback.
  expect_gte(length(cell$layers), 3L)
})

test_that("diagonal = 'density' falls back to blank when n < 5", {
  cell <- janusplot:::.build_density_rug_cell("x", c(1, 2, NA, NA))
  expect_s3_class(cell, "ggplot")
})

test_that("diagonal validation rejects unknown value", {
  d <- make_linear_data(n = 60L, seed = 1L)
  expect_error(janusplot(d, vars = c("x1", "x2"), diagonal = "violin"))
})

test_that(".display_title emits the three mode labels", {
  expect_match(janusplot:::.display_title("fit"), "Direct fit")
  expect_match(janusplot:::.display_title("d1"), "First derivative")
  expect_match(janusplot:::.display_title("d2"), "Second derivative")
  # Unicode primes when glyph_style = "unicode"
  expect_match(janusplot:::.display_title("d1", "unicode"), "\u2032")
  expect_match(janusplot:::.display_title("d2", "unicode"), "\u2033")
})

# ---------------------------------------------------------------
# vdiffr snapshots for the three display modes
# ---------------------------------------------------------------

test_that("janusplot display = 'd1' snapshot", {
  skip_if_not_installed("vdiffr")
  d <- make_nonlinear_data(n = 150L, seed = 2L)
  p <- janusplot(d, vars = c("x1", "x2"),
                 display = "d1",
                 colour_by = "none",
                 show_shape_legend = FALSE,
                 show_glossary = FALSE)
  vdiffr::expect_doppelganger("matrix-2var-d1-plain", p)
})

test_that("janusplot display = 'd1' simultaneous-CI snapshot", {
  skip_if_not_installed("vdiffr")
  withr::with_seed(2026L, {
    d <- make_nonlinear_data(n = 150L, seed = 2L)
    p <- janusplot(d, vars = c("x1", "x2"),
                   display = "d1",
                   derivative_ci = "simultaneous",
                   derivative_ci_nsim = 500L,
                   colour_by = "none",
                   show_shape_legend = FALSE,
                   show_glossary = FALSE)
  })
  vdiffr::expect_doppelganger("matrix-2var-d1-simultaneous", p)
})
