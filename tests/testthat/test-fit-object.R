# Tests for the janusplot_fit object: structure, the renamed and new
# per-pair fields, p-value adjustment, the shape borderline margin, the
# cleaned data copy, flags, the print() and summary() methods, and the
# deprecated janusplot_data() alias. Exact values use engine = "gam".

fit_three <- function(d = make_linear_data(n = 100L), ...) {
  janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam", ...)
}

# ---------------------------------------------------------------
# Structure
# ---------------------------------------------------------------

test_that("janusplot_fit() returns the documented fields in order", {
  fit <- fit_three()
  expect_s3_class(fit, c("janusplot_fit", "list"), exact = TRUE)
  expect_named(fit, c("vars", "pairs", "table", "data", "adjust",
                      "settings", "flags", "fits", "call"))
  expect_identical(fit$vars, c("x1", "x2", "x3"))
  expect_length(fit$pairs, 3L)
  expect_null(fit$adjust)
  expect_null(fit$fits)
  expect_identical(fit$call[[1L]], as.name("janusplot_fit"))
  expect_named(fit$settings, c(
    "engine", "method", "k", "bs", "na_action", "n_grid", "derivatives",
    "derivative_ci", "derivative_ci_nsim", "p_adjust", "shape_cutoffs",
    "k_check_thresholds", "auto_refit_k", "k_max_iter",
    "family", "link", "discrete", "nthreads"
  ))
  expect_named(fit$flags, c("failed", "k_capped", "k_flagged", "sparse"))
})

test_that("$pairs keeps the 0.2.0 fields and carries the renamed and new ones", {
  fit <- fit_three()
  first <- fit$pairs[[1L]]
  kept <- c(
    "i", "j", "var_i", "var_j", "fit_yx", "fit_xy", "pred_yx", "pred_xy",
    "edf_yx", "edf_xy", "dev_exp_yx", "dev_exp_xy", "deviance_gap_yx",
    "deviance_gap_xy", "n_used", "asymmetry_index", "k_capped_yx",
    "k_capped_xy", "cor_pearson", "cor_spearman", "cor_kendall",
    "tie_ratio", "monotonicity_index_yx", "convexity_index_yx",
    "monotonicity_index_xy", "convexity_index_xy", "n_turning_yx",
    "n_inflect_yx", "n_turning_xy", "n_inflect_xy", "shape_yx", "shape_xy",
    "shape_code_yx", "shape_code_xy", "shape_archetype_yx",
    "shape_archetype_xy", "shape_monotonic_yx", "shape_monotonic_xy",
    "shape_linear_yx", "shape_linear_xy", "deriv_yx", "deriv_xy",
    "prediction_reference_yx", "prediction_reference_xy", "k_check_yx",
    "k_check_xy", "k_requested_yx", "k_requested_xy", "k_used_yx",
    "k_used_xy", "engine", "method", "error_yx", "error_xy"
  )
  added <- c(
    "association_p_yx", "association_p_xy",
    "association_p_adj_yx", "association_p_adj_xy",
    "directional_complexity_yx", "directional_complexity_xy",
    "shape_borderline_yx", "shape_borderline_xy"
  )
  expect_true(all(c(kept, added) %in% names(first)))
  expect_false(any(c("pvalue_yx", "pvalue_xy") %in% names(first)))
  expect_null(first$fit_yx)
  expect_true(is.finite(first$association_p_yx))
  expect_s3_class(first$pred_yx, "data.frame")
  expect_named(first$deriv_yx, c("1", "2"))
})

# ---------------------------------------------------------------
# p-value adjustment and directional complexity
# ---------------------------------------------------------------

test_that("p_adjust adjusts once across the directed cells", {
  d <- make_nonlinear_data(n = 150L)
  raw  <- janusplot_fit(d, engine = "gam")
  bh   <- janusplot_fit(d, engine = "gam", p_adjust = "BH")
  holm <- janusplot_fit(d, engine = "gam", p_adjust = "holm")
  p <- raw$table$association_p
  expect_identical(raw$table$association_p_adj, p)
  expect_identical(bh$table$association_p, p)
  expect_equal(bh$table$association_p_adj, stats::p.adjust(p, "BH"))
  expect_equal(holm$table$association_p_adj, stats::p.adjust(p, "holm"))
  expect_true(all(bh$table$association_p_adj >= p))
  expect_true(all(holm$table$association_p_adj >= p))
  expect_identical(bh$settings$p_adjust, "BH")
  # The pair fields carry the same adjusted values as the table rows.
  pr <- holm$pairs[[1L]]
  row_yx <- holm$table$var_x == pr$var_i & holm$table$var_y == pr$var_j
  expect_identical(pr$association_p_adj_yx,
                   holm$table$association_p_adj[row_yx])
  expect_identical(holm$table$signif[row_yx],
                   janusplot:::.pvalue_to_glyph(pr$association_p_adj_yx))
})

test_that("failed cells stay NA after adjustment", {
  d <- make_linear_data(n = 80L)
  d$x3 <- d$x1
  fit <- suppressWarnings(fit_three(d, p_adjust = "BH"))
  failed <- is.na(fit$table$edf)
  expect_true(any(failed))
  expect_true(all(is.na(fit$table$association_p_adj[failed])))
  expect_true(all(is.finite(fit$table$association_p_adj[!failed])))
})

test_that("directional complexity is antisymmetric and A is its magnitude", {
  fit <- janusplot_fit(make_nonlinear_data(n = 150L), engine = "gam")
  for (p in fit$pairs) {
    expect_equal(p$directional_complexity_xy, -p$directional_complexity_yx)
    expect_equal(p$asymmetry_index, abs(p$directional_complexity_yx))
    expect_equal(p$asymmetry_index,
                 janusplot:::.compute_asymmetry_index(p$edf_yx, p$edf_xy))
    expect_equal(p$directional_complexity_yx,
                 (p$edf_yx - p$edf_xy) / (p$edf_yx + p$edf_xy))
    upper <- fit$table$var_x == p$var_i & fit$table$var_y == p$var_j
    lower <- fit$table$var_x == p$var_j & fit$table$var_y == p$var_i
    expect_equal(fit$table$directional_complexity[upper],
                 p$directional_complexity_yx)
    expect_equal(fit$table$directional_complexity[lower],
                 p$directional_complexity_xy)
    expect_equal(fit$table$asymmetry_index[upper], p$asymmetry_index)
  }
})

# ---------------------------------------------------------------
# Shape borderline margin
# ---------------------------------------------------------------

test_that(".shape_borderline() is the gap to the cutoff that can flip the label", {
  co <- janusplot_shape_cutoffs()
  # convex_up needs M > 0.5 and C > 0.5: C sits 0.01 above its cutoff.
  expect_identical(janusplot:::.classify_shape(0.6, 0.51, 0L, 0L, 1, co),
                   "convex_up")
  expect_equal(janusplot:::.shape_borderline(0.6, 0.51, 0L, 0L, 1, co),
               0.01)
  # A near-flat curve: the flat-range ratio is 0.002 above `flat`.
  expect_equal(janusplot:::.shape_borderline(0.95, 0.05, 0L, 0L, 0.052, co),
               0.002)
  # A flat label is `flat` minus the ratio away from leaving the class.
  expect_equal(janusplot:::.shape_borderline(0.95, 0.05, 0L, 0L, 0.03, co),
               0.02)
  # Count-decided labels: only the flat gate can move them, so the margin
  # is the flat-range gap, and NA when that ratio is unavailable.
  expect_identical(janusplot:::.classify_shape(0.1, 0.6, 1L, 0L, 2, co),
                   "u_shape")
  expect_equal(janusplot:::.shape_borderline(0.1, 0.6, 1L, 0L, 2, co),
               2 - co$flat)
  expect_identical(janusplot:::.shape_borderline(0.1, 0.6, 1L, 0L,
                                                 NA_real_, co),
                   NA_real_)
  # Indeterminate: no cutoff consulted.
  expect_identical(janusplot:::.shape_borderline(NA_real_, 0.3, 0L, 0L, 1, co),
                   NA_real_)
  # The classifier's return is unchanged by the sibling.
  expect_type(janusplot:::.classify_shape(0.6, 0.51, 0L, 0L, 1, co),
              "character")
})

test_that("shape_borderline is finite on fitted cells and NA on failed cells", {
  d <- make_nonlinear_data(n = 150L)
  d$x5 <- d$x1
  fit <- suppressWarnings(janusplot_fit(d, engine = "gam"))
  tbl <- fit$table
  fitted <- !is.na(tbl$edf)
  expect_true(all(is.finite(tbl$shape_borderline[fitted])))
  expect_true(all(tbl$shape_borderline[fitted] >= 0))
  expect_true(all(is.na(tbl$shape_borderline[!fitted])))
  expect_true(all(tbl$shape_category[!fitted] == "indeterminate"))
  pr <- fit$pairs[[1L]]
  row_yx <- tbl$var_x == pr$var_i & tbl$var_y == pr$var_j
  expect_identical(pr$shape_borderline_yx, tbl$shape_borderline[row_yx])
})

# ---------------------------------------------------------------
# Cleaned data copy and settings
# ---------------------------------------------------------------

test_that("$data keeps original names, factor columns and Inf as NA", {
  d <- make_linear_data(n = 80L)
  names(d)[1L] <- "grain yield (t/ha)"
  d$x2[3L] <- Inf
  d$site <- factor(rep(c("a", "b"), length.out = nrow(d)))
  d$note <- rep(c("p", "q"), length.out = nrow(d))
  d$flag <- rep(c(TRUE, FALSE), length.out = nrow(d))
  vv <- c("grain yield (t/ha)", "x2", "x3")
  expect_warning(
    fit <- janusplot_fit(d, vars = vv, engine = "gam"),
    "Infinite"
  )
  expect_identical(names(fit$data), c(vv, "site", "note", "flag"))
  expect_false("x4" %in% names(fit$data))
  expect_true(is.na(fit$data$x2[3L]))
  expect_false(any(is.infinite(fit$data$x2)))
  expect_s3_class(fit$data$site, "factor")
  expect_type(fit$data$note, "character")
  expect_type(fit$data$flag, "logical")
  expect_identical(nrow(fit$data), nrow(d))
  expect_identical(fit$vars, vv)
})

test_that("$data follows na_action and the adjust coercions", {
  d <- make_linear_data(n = 80L)
  d$x1[1:4] <- NA
  d$x2[5:6] <- NA
  d$g <- rep(c("a", "b", "c"), length.out = nrow(d))
  pairwise <- fit_three(d)
  expect_identical(nrow(pairwise$data), nrow(d))
  complete <- fit_three(d, na_action = "complete")
  expect_identical(nrow(complete$data), nrow(d) - 6L)
  expect_false(anyNA(complete$data[, c("x1", "x2", "x3")]))
  expect_message(
    adjusted <- fit_three(d, adjust = ~ s(g, bs = "re")),
    "Converted"
  )
  expect_s3_class(adjusted$data$g, "factor")
  expect_identical(adjusted$adjust, ~ s(g, bs = "re"))
})

test_that("$settings records the resolved grid and method", {
  d <- make_linear_data(n = 80L)
  fit <- fit_three(d)
  expect_identical(fit$settings$n_grid, 200L)
  expect_identical(fit$settings$derivatives, 1:2)
  expect_identical(fit$settings$method, "REML")
  expect_identical(fit$settings$engine, "gam")
  expect_identical(fit$settings$k_check_thresholds,
                   list(edf_ratio = 0.9, k_index = 1.0, p = 0.05))
  expect_identical(nrow(fit$pairs[[1L]]$pred_yx), 200L)
  no_deriv <- fit_three(d, derivatives = integer())
  expect_identical(no_deriv$settings$n_grid, 100L)
  expect_identical(no_deriv$settings$derivatives, integer())
  expect_length(no_deriv$pairs[[1L]]$deriv_yx, 0L)
  expect_identical(nrow(no_deriv$pairs[[1L]]$pred_yx), 100L)
  bam_fit <- janusplot_fit(d, vars = c("x1", "x2"), n_grid = 50,
                           derivatives = 2L)
  expect_identical(bam_fit$settings$method, "fREML")
  expect_identical(bam_fit$settings$n_grid, 50L)
  expect_named(bam_fit$pairs[[1L]]$deriv_yx, "2")
})

test_that("janusplot_fit() validates its own arguments", {
  d <- make_linear_data(n = 60L)
  expect_error(janusplot_fit(d, keep_fits = NA), "keep_fits")
  expect_error(janusplot_fit(d, p_adjust = "bonferroni"), "p_adjust")
  expect_error(janusplot_fit(d, derivatives = 3L), "derivatives")
  expect_error(janusplot_fit(d, n_grid = 5), "n_grid")
})

# ---------------------------------------------------------------
# Flags and kept fits
# ---------------------------------------------------------------

test_that("flags$failed lists an identical-column pair", {
  d <- make_linear_data(n = 80L)
  d$x3 <- d$x1
  expect_warning(fit <- fit_three(d), "failed to fit")
  failed <- fit$flags$failed
  expect_s3_class(failed, "data.frame")
  expect_named(failed, c("var_x", "var_y", "reason"))
  expect_identical(nrow(failed), 2L)
  expect_setequal(failed$var_x, c("x1", "x3"))
  expect_setequal(failed$var_y, c("x1", "x3"))
  expect_match(failed$reason, "identical")
  expect_identical(nrow(fit$flags$sparse), 0L)
  expect_identical(fit$flags$k_capped, character())
})

test_that("flags$sparse lists a pair with fewer than 5 shared rows", {
  d <- make_linear_data(n = 40L)
  d$x3 <- NA_real_
  d$x3[1:3] <- c(0.1, 0.5, 0.9)
  expect_warning(fit <- fit_three(d), "fewer than 5")
  sparse <- fit$flags$sparse
  expect_named(sparse, c("var_i", "var_j", "n_shared"))
  expect_identical(nrow(sparse), 2L)
  expect_identical(sparse$var_j, c("x3", "x3"))
  expect_setequal(sparse$var_i, c("x1", "x2"))
  expect_identical(sparse$n_shared, c(3L, 3L))
  expect_identical(nrow(fit$flags$failed), 0L)
})

test_that("flags$k_capped names capped cells as var_y ~ s(var_x)", {
  df <- withr::with_seed(2026L, {
    n <- 120L
    g <- sample(seq_len(6L), n, replace = TRUE)
    data.frame(g = g, y1 = g + stats::rnorm(n))
  })
  fit <- suppressMessages(janusplot_fit(df, engine = "gam"))
  expect_identical(fit$flags$k_capped, "y1 ~ s(g)")
  expect_type(fit$flags$k_flagged, "character")
})

test_that("keep_fits = TRUE fills $fits with gam objects keyed i_j", {
  d <- make_linear_data(n = 80L)
  fit <- janusplot_fit(d, vars = c("x1", "x2"), engine = "gam",
                       keep_fits = TRUE)
  expect_setequal(names(fit$fits), c("1_2", "2_1"))
  expect_s3_class(fit$fits[["1_2"]], "gam")
  expect_s3_class(fit$pairs[[1L]]$fit_yx, "gam")
  expect_s3_class(fit$pairs[[1L]]$fit_xy, "gam")
  expect_identical(fit$fits[["1_2"]], fit$pairs[[1L]]$fit_yx)
})

# ---------------------------------------------------------------
# summary() and print()
# ---------------------------------------------------------------

test_that("summary() returns the per-cell table without view columns", {
  fit <- fit_three()
  tbl <- summary(fit)
  expect_s3_class(tbl, "data.frame")
  expect_identical(class(tbl), "data.frame")
  expect_identical(tbl, fit$table)
  expect_identical(nrow(tbl), 6L)
  expect_false(any(c("display", "colour_value", "pvalue") %in% names(tbl)))
  expect_true(all(c(
    "var_x", "var_y", "position", "n_used", "edf", "association_p",
    "association_p_adj", "signif", "asymmetry_index",
    "directional_complexity", "shape_category", "shape_borderline",
    "k_capped_yx", "k_capped_xy", "error"
  ) %in% names(tbl)))
  expect_setequal(tbl$position, c("upper", "lower"))
  expect_identical(sum(tbl$position == "upper"), 3L)
})

test_that("print() has six sections and names the top pair", {
  fit <- janusplot_fit(make_nonlinear_data(n = 150L), engine = "gam")
  lines <- testthat::capture_output_lines(out <- print(fit))
  expect_identical(out, fit)
  n_top <- min(5L, length(fit$pairs))
  expect_length(lines, 6L + n_top)
  expect_match(lines[1L], "^janusplot fit: 4 variables \\(x1, x2, x3, x4\\)$")
  expect_match(lines[2L], "^6 pairs, 12 directed cells$")
  expect_match(lines[3L], "^engine = gam, method = REML, adjust = none$")
  expect_match(lines[4L], "^no flags$")
  expect_match(lines[5L], "^Largest asymmetries:$")
  a <- vapply(fit$pairs, function(p) p$asymmetry_index, numeric(1L))
  top <- fit$pairs[[which.max(a)]]
  expect_match(lines[6L], paste0("^  ", top$var_i, " <-> ", top$var_j,
                                 "  A = [0-9]\\.[0-9]{2}  \\(",
                                 top$shape_yx, " \\| ", top$shape_xy, "\\)$"))
  expect_match(lines[length(lines)], "summary\\(\\).*plot\\(\\)")
})

test_that("print() says one pair, not one pairs", {
  fit <- janusplot_fit(make_linear_data(n = 80L)[, 1:2], engine = "gam",
                       derivatives = integer())
  lines <- testthat::capture_output_lines(print(fit))
  expect_match(lines[2L], "^1 pair, 2 directed cells$")
})

test_that("print() reports flags and the adjust formula", {
  d <- make_linear_data(n = 80L)
  d$x3 <- d$x1
  d$g <- factor(rep(c("a", "b"), length.out = nrow(d)))
  fit <- suppressWarnings(fit_three(d, adjust = ~ g))
  lines <- testthat::capture_output_lines(print(fit))
  expect_match(lines[3L], "adjust = ~g$")
  expect_match(lines[4L], "^flags: 2 failed cells$")
})

# ---------------------------------------------------------------
# Deprecated alias
# ---------------------------------------------------------------

test_that("janusplot_data() is a deprecated alias of janusplot_fit()", {
  d <- make_linear_data(n = 80L)
  lifecycle::expect_deprecated(
    old <- janusplot_data(d, vars = c("x1", "x2"), engine = "gam")
  )
  new <- janusplot_fit(d, vars = c("x1", "x2"), engine = "gam")
  expect_s3_class(old, "janusplot_fit")
  expect_identical(old$call[[1L]], as.name("janusplot_data"))
  expect_identical(old$call$engine, "gam")
  old$call <- NULL
  new$call <- NULL
  expect_identical(old, new)
})

# ---------------------------------------------------------------
# Metric sanity checks carried over from the janusplot_data() tests
# ---------------------------------------------------------------

test_that("correlations lie in [-1, 1] and agree with stats::cor", {
  d <- make_linear_data(n = 200L)
  fit <- janusplot_fit(d, vars = c("x1", "x2"))
  p <- fit$pairs[[1L]]
  expect_true(is.finite(p$cor_spearman))
  expect_true(all(abs(c(p$cor_pearson, p$cor_spearman, p$cor_kendall)) <= 1))
  ref <- stats::cor(d$x1, d$x2, use = "pairwise.complete.obs")
  expect_equal(p$cor_pearson, ref, tolerance = 1e-10)
})

test_that("shape labels recover a near-linear canonical shape", {
  # mgcv REML smoothing on noisy linear data may yield a near-linear
  # spline with tiny wiggles, so allow any monotone-increasing family.
  withr::with_seed(42L, {
    n  <- 200L
    x1 <- stats::runif(n, 0, 10)
    x2 <- x1 + stats::rnorm(n, sd = 0.1)
    d  <- data.frame(x1 = x1, x2 = x2)
  })
  fit <- janusplot_fit(d, vars = c("x1", "x2"))
  p <- fit$pairs[[1L]]
  expect_true(p$shape_yx %in%
                c("linear_up", "convex_up", "concave_up", "s_shape"))
  expect_gt(p$cor_spearman, 0.9)
})

test_that("asymmetry_index is in [0, 1] and finite on heteroscedastic data", {
  fit <- janusplot_fit(make_nonlinear_data(n = 200L))
  ax <- vapply(fit$pairs, function(p) p$asymmetry_index, numeric(1L))
  ax <- ax[!is.na(ax)]
  expect_true(all(ax >= 0 & ax <= 1))
  het <- janusplot_fit(make_heteroscedastic_data(n = 300L),
                       vars = c("x1", "x2"))
  expect_true(is.finite(het$pairs[[1L]]$asymmetry_index))
})
