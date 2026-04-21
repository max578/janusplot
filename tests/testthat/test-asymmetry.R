test_that("asymmetry index is zero when EDFs match", {
  expect_equal(janusplot:::.compute_asymmetry_index(1.5, 1.5), 0)
})

test_that("asymmetry index is one when one EDF is zero", {
  expect_equal(janusplot:::.compute_asymmetry_index(0, 3), 1)
})

test_that("asymmetry index lies in [0, 1]", {
  vals <- vapply(1:50, function(i) {
    a <- stats::runif(1, 0.5, 8)
    b <- stats::runif(1, 0.5, 8)
    janusplot:::.compute_asymmetry_index(a, b)
  }, numeric(1L))
  expect_true(all(vals >= 0 & vals <= 1))
})

test_that("asymmetry index is NA when either input is NA", {
  expect_true(is.na(janusplot:::.compute_asymmetry_index(NA_real_, 1)))
  expect_true(is.na(janusplot:::.compute_asymmetry_index(1, NA_real_)))
})

test_that("p-value glyphs follow conventional cutoffs", {
  expect_equal(janusplot:::.pvalue_to_glyph(0.0001), "***")
  expect_equal(janusplot:::.pvalue_to_glyph(0.005),  "**")
  expect_equal(janusplot:::.pvalue_to_glyph(0.03),   "*")
  expect_equal(janusplot:::.pvalue_to_glyph(0.08),   "\u00b7")
  expect_equal(janusplot:::.pvalue_to_glyph(0.5),    "")
  expect_equal(janusplot:::.pvalue_to_glyph(NA_real_), "")
})
