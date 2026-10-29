# Tests for the janusplot() legacy shim: every 0.2.0 argument marked
# shimmed or removed in the 1.0.0 freeze warns through lifecycle and maps
# to its new home. The shim is removed in 1.1.0; so is this file.

skip_on_cran()  # heavy GAM-fit suite: full on CI, skipped on CRAN for time budget

d_lin <- make_linear_data(n = 80L)

shim <- function(...) {
  janusplot:::.shim_legacy_args(
    list(...), style = janusplot_style(), colour_by = "nonlinearity",
    annotations = c("A", "signif")
  )
}

test_that("every style knob warns and lands in the style object", {
  values <- list(
    show_data = FALSE, show_ci = FALSE, palette = "magma",
    show_shape_legend = FALSE, glyph_style = "unicode", labels = "none",
    diagonal = "density", label_srt = 90, label_cex = 1.5,
    text_scale_diag = 0.5, text_scale_off_diag = 1.2, show_glossary = FALSE,
    glossary_scale = 0.7, compact = "never", compact_threshold = 15L,
    compact_levels = list(t1 = 15L, t2 = 20L, t3 = 30L), focus_dim_alpha = 0.5
  )
  for (nm in names(values)) {
    lifecycle::expect_deprecated(
      out <- do.call(shim, values[nm]),
      sprintf("`%s` argument of `janusplot\\(\\)`", nm)
    )
    expect_identical(out$style[[nm]], values[[nm]], info = nm)
    expect_s3_class(out$style, "janusplot_style")
    expect_length(out$fit_args, 0L)
  }
})

test_that("a shimmed style knob is still validated", {
  lifecycle::expect_deprecated(
    expect_error(shim(label_srt = "45"), "numeric")
  )
  lifecycle::expect_deprecated(
    expect_error(shim(compact_threshold = 0L), "integer >= 2")
  )
})

test_that("labels = 'diagonal' maps to 'border' with a message", {
  lifecycle::expect_deprecated(
    expect_message(out <- shim(labels = "diagonal"), "border")
  )
  expect_identical(out$style$labels, "border")
})

test_that("fill_by, show_asymmetry and signif_glyph map to the view arguments", {
  lifecycle::expect_deprecated(out <- shim(fill_by = "pearson"), "fill_by")
  expect_identical(out$view_args$colour_by, "pearson")

  lifecycle::expect_deprecated(out <- shim(show_asymmetry = FALSE),
                               "show_asymmetry")
  expect_identical(out$view_args$annotations, "signif")
  lifecycle::expect_deprecated(out <- shim(show_asymmetry = TRUE))
  expect_identical(out$view_args$annotations, c("A", "signif"))

  lifecycle::expect_deprecated(out <- shim(signif_glyph = FALSE), "signif_glyph")
  expect_identical(out$view_args$annotations, "A")
  lifecycle::expect_deprecated(out <- shim(signif_glyph = TRUE))
  expect_identical(out$view_args$annotations, c("A", "signif"))
  lifecycle::expect_deprecated(expect_error(shim(signif_glyph = NA),
                                            "TRUE or FALSE"))
})

test_that("model arguments pass through to janusplot_fit() without a warning", {
  expect_no_warning(
    out <- shim(method = "GCV.Cp", k = 5L, engine = "gam",
                derivative_ci = "simultaneous", n_grid = 50L, gamma = 1.2)
  )
  expect_identical(out$fit_args, list(method = "GCV.Cp", k = 5L, engine = "gam",
                                      derivative_ci = "simultaneous",
                                      n_grid = 50L, gamma = 1.2))
  expect_identical(out$view_args, list(colour_by = "nonlinearity",
                                       annotations = c("A", "signif")))
  expect_false(out$post$with_data)
  expect_null(out$post$save_as)
})

test_that("unnamed arguments reaching ... are refused", {
  # The 0.2.0 fourth positional argument was `method`; today a fourth
  # positional value lands in `colour_by` and fails there, and anything
  # past the thirteenth formal reaches `...` unnamed.
  expect_error(janusplot(d_lin, c("x1", "x2"), NULL, "REML"), "colour_by")
  expect_error(
    janusplot(d_lin, c("x1", "x2"), NULL, "nonlinearity", c("A", "signif"),
              "original", "fit", NULL, NA, "q90", "original",
              janusplot_style(), "REML"),
    "must be named"
  )
})

test_that("with_data = TRUE returns list(plot, data) with the summary table", {
  lifecycle::expect_deprecated(
    out <- janusplot(d_lin, vars = c("x1", "x2", "x3"), engine = "gam",
                     with_data = TRUE),
    "with_data"
  )
  expect_named(out, c("plot", "data"))
  expect_s3_class(out$plot, "ggplot")
  fit <- janusplot_fit(d_lin, vars = c("x1", "x2", "x3"), engine = "gam")
  expect_identical(out$data, summary(fit))
  lifecycle::expect_deprecated(
    p <- janusplot(d_lin, vars = c("x1", "x2"), engine = "gam",
                   with_data = FALSE)
  )
  expect_s3_class(p, "ggplot")
  lifecycle::expect_deprecated(
    expect_error(janusplot(d_lin, with_data = "yes"), "TRUE or FALSE")
  )
})

test_that("save_as writes a file once with the device from the extension", {
  tmpdir <- withr::local_tempdir()
  for (ext in c("png", "pdf")) {
    path <- file.path(tmpdir, paste0("matrix.", ext))
    lifecycle::expect_deprecated(
      p <- janusplot(d_lin, vars = c("x1", "x2", "x3"), engine = "gam",
                     save_as = path),
      "save_as"
    )
    expect_true(file.exists(path))
    expect_gt(file.size(path), 100)
    expect_s3_class(p, "ggplot")
  }
})

test_that("save_as honours width / height / dpi and validates them", {
  tmpdir <- withr::local_tempdir()
  path <- file.path(tmpdir, "matrix.png")
  withr::local_options(lifecycle_verbosity = "quiet")
  janusplot(d_lin, vars = c("x1", "x2"), engine = "gam",
            save_as = path, save_width = 4, save_height = 4, save_dpi = 96)
  expect_true(file.exists(path))
  expect_gt(file.size(path), 100)
  expect_error(janusplot(d_lin, save_as = "matrix.xyz"),
               "Cannot infer image device")
  expect_error(janusplot(d_lin, save_as = "matrix_no_extension"),
               "Cannot infer image device")
  expect_error(janusplot(d_lin, save_as = path, save_width = -1),
               "save_width")
  expect_error(janusplot(d_lin, save_as = path, save_dpi = 0), "save_dpi")
})

test_that("a legacy call end to end draws the mapped view", {
  lifecycle::expect_deprecated(
    p <- janusplot(d_lin, vars = c("x1", "x2"), engine = "gam",
                   fill_by = "none"),
    "fill_by"
  )
  expect_s3_class(p, "ggplot")
  withr::local_options(lifecycle_verbosity = "quiet")
  p <- janusplot(d_lin, vars = c("x1", "x2"), engine = "gam",
                 show_data = FALSE, show_ci = FALSE, palette = "magma",
                 labels = "none", show_shape_legend = FALSE,
                 show_glossary = FALSE, glyph_style = "unicode",
                 text_scale_diag = 0.5, text_scale_off_diag = 1.2,
                 glossary_scale = 0.7, compact = "never",
                 focus_dim_alpha = 0.5, label_srt = 0, label_cex = 1.2,
                 diagonal = "name", show_asymmetry = TRUE,
                 signif_glyph = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("colour_by = 'edf' through janusplot() names the caller, not the package", {
  withr::local_options(lifecycle_verbosity = "warning")
  w <- testthat::capture_warnings(
    p <- janusplot(d_lin, vars = c("x1", "x2"), engine = "gam",
                   colour_by = "edf")
  )
  expect_s3_class(p, "ggplot")
  expect_length(w, 1L)
  expect_match(w, 'colour_by = "edf"', fixed = TRUE)
  expect_false(any(grepl("likely used in the janusplot package", w)))
})
