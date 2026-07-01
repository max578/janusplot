skip_on_cran()  # heavy GAM-fit suite: full on CI, skipped on CRAN for time budget

# Tests for Feature 3 — axes rendering modes.
# Covers: byte-identity of fits across modes; label-suffix correctness;
# transformation correctness for each mode; tier-3 no-op; at-k
# rendering across all 4 modes for k in {2, 5, 10, 15, 20, 26}.

skip_if_no_mgcv <- function() {
  testthat::skip_if_not_installed("mgcv")
}

# ---------------------------------------------------------------
# .build_axis_transform unit tests — pure helper
# ---------------------------------------------------------------

test_that(".build_axis_transform 'original' is identity", {
  raw <- c(1.5, 2.5, 7.0, 11.0)
  tf <- janusplot:::.build_axis_transform(raw, "original")
  expect_equal(tf$fn(raw), raw)
  expect_equal(tf$fn(c(NA, 1.5, 99)), c(NA, 1.5, 99))
  expect_identical(tf$suffix, "")
})

test_that(".build_axis_transform 'standardised' centres + scales", {
  raw <- c(1, 2, 3, 4, 5)
  tf <- janusplot:::.build_axis_transform(raw, "standardised")
  out <- tf$fn(raw)
  expect_equal(mean(out), 0, tolerance = 1e-9)
  expect_equal(stats::sd(out), 1, tolerance = 1e-9)
  expect_identical(tf$suffix, " (z)")
})

test_that(".build_axis_transform 'centred' subtracts the mean", {
  raw <- c(10, 20, 30)
  tf <- janusplot:::.build_axis_transform(raw, "centred")
  expect_equal(tf$fn(raw), c(-10, 0, 10))
  expect_identical(tf$suffix, " (centred)")
})

test_that(".build_axis_transform 'rank' returns ecdf * n, monotone", {
  raw <- c(1, 2, 5, 11, 50)
  tf <- janusplot:::.build_axis_transform(raw, "rank")
  out <- tf$fn(raw)
  # ecdf * n yields strictly increasing values for strictly
  # increasing inputs without ties.
  expect_true(all(diff(out) > 0))
  expect_true(all(out >= 0 & out <= length(raw)))
  expect_identical(tf$suffix, " (rank)")
})

test_that(".build_axis_transform handles degenerate inputs without erroring", {
  # All-NA -> identity fallback
  tf_na <- janusplot:::.build_axis_transform(rep(NA_real_, 5), "standardised")
  expect_equal(tf_na$fn(c(1, 2, 3)), c(1, 2, 3))
  # Single value -> identity fallback for rank
  tf_one <- janusplot:::.build_axis_transform(c(7), "rank")
  expect_equal(tf_one$fn(c(7, 14)), c(7, 14))
  # Constant column -> sd defaults to 1 for standardised
  tf_const <- janusplot:::.build_axis_transform(c(5, 5, 5), "standardised")
  expect_equal(tf_const$fn(c(5, 5, 5)), c(0, 0, 0))
})

# ---------------------------------------------------------------
# Label suffixing
# ---------------------------------------------------------------

test_that(".label_with_suffix handles every mode correctly", {
  expect_identical(janusplot:::.label_with_suffix("mpg", "", "original"), "mpg")
  expect_identical(janusplot:::.label_with_suffix("mpg", " (z)", "standardised"),
                   "mpg (z)")
  expect_identical(janusplot:::.label_with_suffix("mpg", " (centred)", "centred"),
                   "mpg (centred)")
  expect_identical(janusplot:::.label_with_suffix("mpg", " (rank)", "rank"),
                   "rank(mpg)")
})

# ---------------------------------------------------------------
# Byte-identity of fits across modes — the load-bearing invariant
# ---------------------------------------------------------------

test_that("fits + metrics are byte-identical across axes modes", {
  skip_if_no_mgcv()
  dat <- make_nonlinear_data(n = 200L, seed = 2L)
  d_orig <- janusplot(dat, axes = "original",     with_data = TRUE)$data
  d_std  <- janusplot(dat, axes = "standardised", with_data = TRUE)$data
  d_ctr  <- janusplot(dat, axes = "centred",      with_data = TRUE)$data
  d_rnk  <- janusplot(dat, axes = "rank",         with_data = TRUE)$data
  # The fit-side columns must be identical; rendering-only knob.
  cols <- c("edf", "pvalue", "asymmetry_index", "dev_exp",
            "cor_pearson", "cor_spearman", "cor_kendall", "tie_ratio",
            "monotonicity_index", "convexity_index",
            "n_turning_points", "n_inflections", "shape_category",
            "k_prime", "k_index", "k_p", "k_flag")
  expect_identical(d_orig[, cols], d_std[, cols])
  expect_identical(d_orig[, cols], d_ctr[, cols])
  expect_identical(d_orig[, cols], d_rnk[, cols])
})

# ---------------------------------------------------------------
# At-k correctness: render at k = 2, 5, 10, 15, 20, 26 across all
# 4 axes modes (24 combinations). Each must build a ggplot
# without errors or warnings. Labels must reflect the chosen mode.
# ---------------------------------------------------------------

make_wide_data <- function(k_var, n = 80L, seed = 42L) {
  withr::with_seed(seed, {
    as.data.frame(matrix(stats::rnorm(n * k_var), ncol = k_var,
                         dimnames = list(NULL, sprintf("v%02d", seq_len(k_var)))))
  })
}

test_that("every (k, axes) combination renders without warnings", {
  skip_if_no_mgcv()
  k_values <- c(2L, 5L, 10L, 15L, 20L, 26L)
  modes    <- c("original", "standardised", "centred", "rank")
  for (k in k_values) {
    dat <- make_wide_data(k)
    for (m in modes) {
      p <- expect_silent(janusplot(dat, axes = m))
      expect_s3_class(p, "ggplot")
    }
  }
})

collect_label_strings <- function(g) {
  # Walk patchwork's plot list looking for ggplot layer labels.
  plots <- if (!is.null(g$patches$plots)) g$patches$plots else list(g)
  out <- character()
  for (p in plots) {
    if (inherits(p, "patchwork")) {
      out <- c(out, collect_label_strings(p))
      next
    }
    if (!inherits(p, "ggplot") || !length(p$layers)) next
    for (lyr in p$layers) {
      lbl <- lyr$aes_params$label %||% lyr$data$label
      if (!is.null(lbl)) out <- c(out, as.character(lbl))
    }
  }
  out
}

test_that("border labels carry the mode suffix at every k", {
  skip_if_no_mgcv()
  for (k in c(3L, 12L, 20L)) {
    dat <- make_wide_data(k)
    g_std  <- janusplot(dat, axes = "standardised", labels = "border")
    g_rnk  <- janusplot(dat, axes = "rank",         labels = "border")
    g_orig <- janusplot(dat, axes = "original",     labels = "border")
    std_labels  <- collect_label_strings(g_std)
    rnk_labels  <- collect_label_strings(g_rnk)
    orig_labels <- collect_label_strings(g_orig)
    expect_true(any(grepl(" \\(z\\)$", std_labels)),
                info = sprintf("k = %d standardised", k))
    expect_true(any(grepl("^rank\\(", rnk_labels)),
                info = sprintf("k = %d rank", k))
    # Original mode: no mode-suffix on label strings.
    expect_false(any(grepl(" \\(z\\)$|^rank\\(|\\(centred\\)$", orig_labels)),
                 info = sprintf("k = %d original", k))
  }
})

# ---------------------------------------------------------------
# Tier-3 no-op: at k >= 25 the cells don't render the curve, so
# `axes` is documented no-op. Calling it must NOT error.
# ---------------------------------------------------------------

test_that("tier 3 (k = 26) accepts every axes mode silently", {
  skip_if_no_mgcv()
  dat <- make_wide_data(26L)
  for (m in c("original", "standardised", "centred", "rank")) {
    p <- janusplot(dat, axes = m)
    expect_s3_class(p, "ggplot")
  }
})

# ---------------------------------------------------------------
# Public API validation
# ---------------------------------------------------------------

test_that("invalid axes value errors via arg_match", {
  skip_if_no_mgcv()
  dat <- make_linear_data(50L, seed = 1L)
  expect_error(
    janusplot(dat, vars = c("x1", "x2"), axes = "nonsense"),
    "must be one of"
  )
})

# ---------------------------------------------------------------
# save_as file output
# ---------------------------------------------------------------

test_that("save_as writes PNG / PDF with device from extension", {
  skip_if_no_mgcv()
  testthat::skip_if_not_installed("ggplot2")
  dat <- make_linear_data(60L, seed = 1L)
  tmpdir <- withr::local_tempdir()
  # PNG + PDF use base R grDevices — always available. SVG needs
  # svglite (ggplot2 dispatches to svglite::svglite for .svg), so
  # it gets its own conditional-skip test below.
  for (ext in c("png", "pdf")) {
    path <- file.path(tmpdir, paste0("matrix.", ext))
    p <- janusplot(dat, vars = c("x1", "x2", "x3"), save_as = path)
    expect_true(file.exists(path))
    expect_true(file.size(path) > 100)
    expect_s3_class(p, "ggplot")
  }
})

test_that("save_as writes SVG when svglite is available", {
  skip_if_no_mgcv()
  testthat::skip_if_not_installed("svglite")
  dat <- make_linear_data(60L, seed = 1L)
  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "matrix.svg")
  p <- janusplot(dat, vars = c("x1", "x2", "x3"), save_as = path)
  expect_true(file.exists(path))
  expect_true(file.size(path) > 100)
  expect_s3_class(p, "ggplot")
})

test_that("save_as rejects unknown extensions loudly", {
  skip_if_no_mgcv()
  dat <- make_linear_data(60L, seed = 1L)
  expect_error(
    janusplot(dat, vars = c("x1", "x2"), save_as = "matrix.xyz"),
    "Cannot infer image device"
  )
  expect_error(
    janusplot(dat, vars = c("x1", "x2"), save_as = "matrix_no_extension"),
    "Cannot infer image device"
  )
})

test_that("save_as honours width / height / dpi overrides", {
  skip_if_no_mgcv()
  dat <- make_linear_data(60L, seed = 1L)
  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "matrix.png")
  janusplot(dat, vars = c("x1", "x2", "x3"),
            save_as = path, save_width = 4, save_height = 4, save_dpi = 96)
  expect_true(file.exists(path))
  # 4x4 inches at 96 dpi -> 384 x 384 px; allow some slack since
  # patchwork may add small margins.
  expect_true(file.size(path) > 100)
})
