test_that("janusplot returns a ggplot", {
  d <- make_linear_data(n = 100L)
  p <- janusplot(d, vars = c("x1", "x2", "x3"))
  expect_s3_class(p, "ggplot")
})

test_that("janusplot respects order = 'alphabetical'", {
  d <- make_linear_data(n = 100L)
  names(d) <- c("zulu", "bravo", "alpha", "mike")
  p <- janusplot(d, order = "alphabetical")
  expect_s3_class(p, "ggplot")
})

test_that("janusplot respects order = 'hclust' with >= 3 vars", {
  d <- make_linear_data(n = 100L)
  p <- janusplot(d, order = "hclust")
  expect_s3_class(p, "ggplot")
})

test_that("janusplot runs with adjust formula", {
  d <- make_linear_data(n = 100L)
  d$z <- stats::rnorm(100L)
  p <- janusplot(d, vars = c("x1", "x2"), adjust = ~ s(z))
  expect_s3_class(p, "ggplot")
})

test_that("janusplot runs with colour_by = 'none'", {
  d <- make_linear_data(n = 100L)
  p <- janusplot(d, vars = c("x1", "x2"), colour_by = "none")
  expect_s3_class(p, "ggplot")
})

test_that("fill_by is a deprecated alias of colour_by (warns, still works)", {
  d <- make_linear_data(n = 100L)
  expect_warning(
    p <- janusplot(d, vars = c("x1", "x2"), fill_by = "none"),
    regexp = "deprecated"
  )
  expect_s3_class(p, "ggplot")
})

test_that("janusplot runs with show_data = FALSE and show_ci = FALSE", {
  d <- make_linear_data(n = 100L)
  p <- janusplot(d, vars = c("x1", "x2"),
                 show_data = FALSE, show_ci = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("annotations vector toggles A/edf/shape/code", {
  d <- make_nonlinear_data(n = 150L)
  expect_s3_class(
    janusplot(d, vars = c("x1", "x2", "x3"),
              annotations = c("A", "edf", "shape")),
    "ggplot"
  )
  expect_s3_class(
    janusplot(d, vars = c("x1", "x2", "x3"),
              annotations = c("A", "edf", "code")),
    "ggplot"
  )
  expect_s3_class(
    janusplot(d, vars = c("x1", "x2", "x3"), annotations = character()),
    "ggplot"
  )
})

test_that("annotations rejects unknown values", {
  d <- make_linear_data(n = 80L)
  expect_error(
    janusplot(d, annotations = c("edf", "bogus")),
    class = "rlang_error"
  )
})

test_that("show_asymmetry is a deprecated alias, forwards to annotations", {
  d <- make_nonlinear_data(n = 100L)
  expect_warning(
    p <- janusplot(d, vars = c("x1", "x2"), show_asymmetry = TRUE),
    regexp = "deprecated"
  )
  expect_s3_class(p, "ggplot")
})

test_that("janusplot accepts every advertised palette", {
  d <- make_linear_data(n = 80L)
  palettes <- c("viridis", "magma", "inferno", "plasma", "cividis",
                "mako", "rocket", "turbo",
                "RdYlBu", "RdBu", "PuOr", "Spectral",
                "YlOrRd", "YlGnBu", "Blues", "Greens")
  for (pal in palettes) {
    p <- janusplot(d, vars = c("x1", "x2"), palette = pal)
    expect_s3_class(p, "ggplot")
  }
})

test_that("janusplot rejects unknown palette", {
  d <- make_linear_data(n = 80L)
  expect_error(janusplot(d, palette = "not_a_palette"),
               class = "rlang_error")
})

test_that("janusplot accepts split text_scale_diag / text_scale_off_diag", {
  d <- make_linear_data(n = 80L)
  expect_s3_class(
    janusplot(d, vars = c("x1", "x2"),
              text_scale_diag = 0.5, text_scale_off_diag = 1.2),
    "ggplot"
  )
  expect_s3_class(
    janusplot(d, vars = c("x1", "x2"),
              text_scale_diag = 1.4, text_scale_off_diag = 0.7),
    "ggplot"
  )
})

test_that("janusplot text-scale args reject non-positive or invalid values", {
  d <- make_linear_data(n = 80L)
  expect_error(janusplot(d, text_scale_diag = 0), class = "rlang_error")
  expect_error(janusplot(d, text_scale_diag = -1), class = "rlang_error")
  expect_error(janusplot(d, text_scale_off_diag = "big"),
               class = "rlang_error")
  expect_error(janusplot(d, text_scale_off_diag = c(1, 2)),
               class = "rlang_error")
})

test_that(".check_parallel_plan informs on sequential plan", {
  skip_if_not_installed("future.apply")
  skip_if_not_installed("future")
  # .throttle = FALSE bypasses rlang's per-session message dedup so
  # the test is deterministic regardless of run order.
  withr::with_options(
    list(future.plan = "sequential"),
    expect_message(
      janusplot:::.check_parallel_plan(parallel = TRUE, .throttle = FALSE),
      regexp = "sequential"
    )
  )
})

test_that(".check_parallel_plan is silent when parallel = FALSE", {
  expect_silent(janusplot:::.check_parallel_plan(parallel = FALSE))
})

test_that("janusplot show_glossary = FALSE returns plot without caption", {
  d <- make_linear_data(n = 80L)
  p <- janusplot(d, vars = c("x1", "x2"), show_glossary = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("janusplot show_glossary validation", {
  d <- make_linear_data(n = 80L)
  expect_error(janusplot(d, show_glossary = "yes"), class = "rlang_error")
  expect_error(janusplot(d, show_glossary = NA), class = "rlang_error")
  expect_error(janusplot(d, show_glossary = c(TRUE, FALSE)),
               class = "rlang_error")
})

test_that("janusplot glossary_scale accepts positive multipliers", {
  d <- make_linear_data(n = 80L)
  expect_s3_class(janusplot(d, vars = c("x1", "x2"),
                            glossary_scale = 0.7), "ggplot")
  expect_s3_class(janusplot(d, vars = c("x1", "x2"),
                            glossary_scale = 1.5), "ggplot")
})

test_that("janusplot glossary_scale validation", {
  d <- make_linear_data(n = 80L)
  expect_error(janusplot(d, glossary_scale = 0), class = "rlang_error")
  expect_error(janusplot(d, glossary_scale = -1), class = "rlang_error")
  expect_error(janusplot(d, glossary_scale = "big"), class = "rlang_error")
})

test_that(".cell_text_sizes applies diag and off_diag scales independently", {
  base <- janusplot:::.cell_text_sizes(4)
  off2 <- janusplot:::.cell_text_sizes(4, text_scale_off_diag = 2)
  dia2 <- janusplot:::.cell_text_sizes(4, text_scale_diag = 2)
  # off_diag scale doubles n_edf / glyph but leaves diag untouched
  expect_equal(off2$n_edf, base$n_edf * 2)
  expect_equal(off2$glyph, base$glyph * 2)
  expect_equal(off2$diag,  base$diag)
  # diag scale doubles diag but leaves n_edf untouched
  expect_equal(dia2$diag,  base$diag * 2)
  expect_equal(dia2$n_edf, base$n_edf)
})

test_that("janusplot with_data = TRUE returns list(plot, data)", {
  d <- make_linear_data(n = 100L)
  out <- janusplot(d, vars = c("x1", "x2", "x3"), with_data = TRUE)
  expect_named(out, c("plot", "data"))
  expect_s3_class(out$plot, "ggplot")
  expect_equal(nrow(out$data), 6L)
  expect_true(all(c("var_x", "var_y", "position", "n_used",
                    "edf", "pvalue", "signif", "dev_exp",
                    "asymmetry_index",
                    "cor_pearson", "cor_spearman", "cor_kendall",
                    "tie_ratio",
                    "M", "C", "n_turning_points", "n_inflections",
                    "flat_range_ratio", "shape_category",
                    "shape_code", "shape_archetype",
                    "shape_monotonic", "shape_linear",
                    "colour_value") %in%
                    names(out$data)))
  expect_true(all(out$data$position %in% c("upper", "lower")))
})
