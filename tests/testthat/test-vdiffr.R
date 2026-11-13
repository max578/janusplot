# Visual regression tests via vdiffr.
# Snapshots live under tests/testthat/_snaps/vdiffr/. The 1.0.0 default
# cell (thick coloured border, Pearson background, strip above the data,
# blank diagonal, every cell row ~ s(column), corner key) replaced the
# 0.2.0 fill look on 2026-10-29. Regenerate with
# `testthat::snapshot_accept("vdiffr")` on a trusted machine, after
# looking at each case.
#
# Every fit below pins `engine = "gam"`. v0.1.1 switched the default
# engine to `bam` (fREML), which shifts EDFs by ~1-3% vs v0.1.0 REML and
# thus the border colours derived from EDF. Pinning gam locks the
# snapshots to the v0.1.0 fitting contract, so the suite acts as a
# regression gate on the documented "engine = 'gam'" escape.

skip_if_not_installed("vdiffr")

test_that("diagonal cell matches snapshot", {
  skip_on_cran()
  p <- janusplot:::.build_diagonal_cell("my_var")
  vdiffr::expect_doppelganger("diagonal-cell-label", p)
})

test_that("linear 3-var matrix (default look) matches snapshot", {
  skip_on_cran()
  d <- make_linear_data(n = 150L, seed = 1L)
  fit <- janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam")
  vdiffr::expect_doppelganger("matrix-3var-linear-default", plot(fit))
})

test_that("non-linear 3-var matrix with unicode shape glyphs matches snapshot", {
  skip_on_cran()
  d <- make_nonlinear_data(n = 200L, seed = 2L)
  fit <- janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam")
  p <- plot(fit, annotations = c("edf", "A", "shape"),
            style = janusplot_style(glyph_style = "unicode"))
  vdiffr::expect_doppelganger("matrix-3var-nonlinear-shape", p)
})

test_that("fill channel with Pearson r (the 0.2.0 look) matches snapshot", {
  skip_on_cran()
  d <- make_nonlinear_data(n = 200L, seed = 2L)
  fit <- janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam")
  p <- plot(fit, colour_by = "pearson", background_by = "none",
            style = janusplot_style(colour_channel = "fill"))
  vdiffr::expect_doppelganger("matrix-3var-nonlinear-fill-pearson", p)
})

test_that("colour_by = 'none' matrix matches snapshot", {
  skip_on_cran()
  d <- make_linear_data(n = 150L, seed = 1L)
  fit <- janusplot_fit(d, vars = c("x1", "x2"), engine = "gam")
  vdiffr::expect_doppelganger("matrix-colour-none",
                              plot(fit, colour_by = "none"))
})

test_that("ASCII glyph fallback matches snapshot", {
  skip_on_cran()
  d <- make_nonlinear_data(n = 150L, seed = 2L)
  fit <- janusplot_fit(d, vars = c("x1", "x2", "x3"), engine = "gam")
  p <- plot(fit, annotations = c("edf", "A", "shape"),
            style = janusplot_style(glyph_style = "ascii"))
  vdiffr::expect_doppelganger("matrix-3var-nonlinear-ascii-glyphs", p)
})
