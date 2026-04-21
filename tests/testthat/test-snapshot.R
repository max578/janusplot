# Snapshot tests for stable text surfaces. If the glossary caption
# wording drifts (which it shouldn't without a NEWS entry), this
# test fails and prompts a regeneration via
# testthat::snapshot_accept("snapshot").

test_that("p-value glyph ladder matches snapshot", {
  expect_snapshot({
    lapply(
      c(0.0001, 0.005, 0.03, 0.08, 0.5, NA_real_),
      janusplot:::.pvalue_to_glyph
    )
  })
})

test_that("palette choice vector matches snapshot", {
  expect_snapshot(janusplot:::.palette_choices())
})

test_that(".cell_text_sizes output at k = 3 matches snapshot", {
  expect_snapshot(janusplot:::.cell_text_sizes(3L))
})

test_that(".cell_text_sizes output at k = 10 matches snapshot", {
  expect_snapshot(janusplot:::.cell_text_sizes(10L))
})
