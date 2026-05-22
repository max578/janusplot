# Visual regression tests via vdiffr.
# Snapshots live under tests/testthat/_snaps/vdiffr/. After visual
# redesign (2026-04-21) old snapshots were retired. Regenerate with
# `testthat::snapshot_accept("vdiffr")` on a trusted machine.
#
# All janusplot() calls below pin `engine = "gam"`. v0.1.1 switched
# the default engine to `bam` (fREML), which shifts EDFs by ~1-3%
# vs v0.1.0 REML and thus invalidates colour fills derived from
# EDF. Pinning gam locks the snapshots to the v0.1.0 visual
# contract, so the suite acts as a regression gate on the
# documented "engine = 'gam'" backward-compat escape.

skip_if_not_installed("vdiffr")

test_that("diagonal cell matches snapshot", {
  p <- janusplot:::.build_diagonal_cell("my_var")
  vdiffr::expect_doppelganger("diagonal-cell-label", p)
})

test_that("linear 3-var matrix (Spearman colour) matches snapshot", {
  d <- make_linear_data(n = 150L, seed = 1L)
  p <- janusplot(d, vars = c("x1", "x2", "x3"), engine = "gam")
  vdiffr::expect_doppelganger("matrix-3var-linear-spearman", p)
})

test_that("non-linear 3-var matrix with shape glyphs matches snapshot", {
  d <- make_nonlinear_data(n = 200L, seed = 2L)
  p <- janusplot(d, vars = c("x1", "x2", "x3"),
                 annotations = c("edf", "A", "shape"), engine = "gam")
  vdiffr::expect_doppelganger("matrix-3var-nonlinear-shape", p)
})

test_that("EDF-coloured matrix (legacy encoding) matches snapshot", {
  d <- make_nonlinear_data(n = 200L, seed = 2L)
  p <- janusplot(d, vars = c("x1", "x2", "x3"), colour_by = "edf",
                 engine = "gam")
  vdiffr::expect_doppelganger("matrix-3var-nonlinear-edf-colour", p)
})

test_that("colour_by = 'none' matrix matches snapshot", {
  d <- make_linear_data(n = 150L, seed = 1L)
  p <- janusplot(d, vars = c("x1", "x2"), colour_by = "none",
                 engine = "gam")
  vdiffr::expect_doppelganger("matrix-colour-none", p)
})

test_that("ASCII glyph fallback matches snapshot", {
  d <- make_nonlinear_data(n = 150L, seed = 2L)
  p <- janusplot(d, vars = c("x1", "x2", "x3"),
                 glyph_style = "ascii", engine = "gam")
  vdiffr::expect_doppelganger("matrix-3var-nonlinear-ascii-glyphs", p)
})
