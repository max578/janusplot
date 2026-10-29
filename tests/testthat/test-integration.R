skip_on_cran()  # heavy GAM-fit suite: full on CI, skipped on CRAN for time budget

test_that("janusplot returns a ggplot", {
  d <- make_linear_data(n = 100L)
  p <- janusplot(d, vars = c("x1", "x2", "x3"))
  expect_s3_class(p, "ggplot")
})

test_that("labels = 'border' (default) produces a ggplot", {
  d <- make_linear_data(n = 80L)
  p <- janusplot(d, vars = c("x1", "x2", "x3"))
  expect_s3_class(p, "ggplot")
})

test_that("diagonal = 'name' writes the variable names on the diagonal", {
  d <- make_linear_data(n = 80L)
  p <- janusplot(d, vars = c("x1", "x2", "x3"),
                 style = janusplot_style(labels = "none", diagonal = "name"))
  expect_s3_class(p, "ggplot")
})

test_that("labels = 'none' suppresses variable names", {
  d <- make_linear_data(n = 80L)
  p <- janusplot(d, vars = c("x1", "x2", "x3"),
                 style = janusplot_style(labels = "none"))
  expect_s3_class(p, "ggplot")
})

test_that("labels accepts label_srt = 90 and label_srt = 0", {
  d <- make_linear_data(n = 80L)
  expect_s3_class(
    janusplot(d, vars = c("x1", "x2"), style = janusplot_style(label_srt = 90)),
    "ggplot"
  )
  expect_s3_class(
    janusplot(d, vars = c("x1", "x2"), style = janusplot_style(label_srt = 0)),
    "ggplot"
  )
})

test_that("labels rejects unknown value and non-numeric label_srt", {
  expect_error(janusplot_style(labels = "bogus"), class = "rlang_error")
  expect_error(janusplot_style(label_srt = "45"), regexp = "numeric")
  expect_error(janusplot_style(border_width = -1), regexp = "positive|> 0")
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

test_that("janusplot runs with show_data = FALSE and show_ci = FALSE", {
  d <- make_linear_data(n = 100L)
  p <- janusplot(d, vars = c("x1", "x2"),
                 style = janusplot_style(show_data = FALSE, show_ci = FALSE))
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

test_that("janusplot accepts every advertised palette", {
  d <- make_linear_data(n = 80L)
  fit <- janusplot_fit(d, vars = c("x1", "x2"))
  palettes <- c("viridis", "magma", "inferno", "plasma", "cividis",
                "mako", "rocket", "turbo",
                "RdYlBu", "RdBu", "PuOr", "Spectral",
                "YlOrRd", "YlGnBu", "Blues", "Greens")
  for (pal in palettes) {
    st <- janusplot_style(palette = pal, show_shape_legend = FALSE)
    expect_s3_class(plot(fit, style = st), "ggplot")
    expect_s3_class(plot(fit, colour_by = "pearson", style = st), "ggplot")
  }
})

test_that("janusplot rejects unknown palette", {
  expect_error(janusplot_style(palette = "not_a_palette"),
               class = "rlang_error")
})

test_that("janusplot accepts text_size as a number, a list or NULL", {
  d <- make_linear_data(n = 80L)
  for (ts in list(7, list(diagonal = 6, strip = 9), NULL)) {
    expect_s3_class(
      janusplot(d, vars = c("x1", "x2"),
                style = janusplot_style(text_size = ts, diagonal = "name")),
      "ggplot"
    )
  }
})

test_that("janusplot text_size rejects non-positive or invalid values", {
  expect_error(janusplot_style(text_size = 0), "text_size")
  expect_error(janusplot_style(text_size = -1), "text_size")
  expect_error(janusplot_style(text_size = "big"), "text_size")
  expect_error(janusplot_style(text_size = c(1, 2)), "text_size")
  expect_error(janusplot_style(text_size = list(diagonal = 0)), "diagonal")
})

test_that(".check_parallel_plan informs on sequential plan", {
  skip_if_not_installed("future.apply")
  skip_if_not_installed("future")
  # The sequential plan has to be installed, not merely requested via
  # the `future.plan` option: future consults that option only while
  # initialising its own plan, so setting it afterwards leaves an
  # already-established plan in place. On a machine whose startup
  # profile calls future::plan("multisession"), the old
  # with_options(future.plan = "sequential") wrapper therefore left two
  # workers active, .check_parallel_plan() correctly stayed silent, and
  # the expectation failed on ambient state the test believed it
  # controlled.
  # .throttle = FALSE bypasses rlang's per-session message dedup so
  # the test is deterministic regardless of run order.
  old_plan <- future::plan(future::sequential)
  withr::defer(future::plan(old_plan))
  expect_message(
    janusplot:::.check_parallel_plan(parallel = TRUE, .throttle = FALSE),
    regexp = "sequential"
  )
})

test_that(".check_parallel_plan is silent when parallel = FALSE", {
  expect_silent(janusplot:::.check_parallel_plan(parallel = FALSE))
})

test_that("janusplot show_glossary = FALSE returns plot without caption", {
  d <- make_linear_data(n = 80L)
  p <- janusplot(d, vars = c("x1", "x2"),
                 style = janusplot_style(show_glossary = FALSE))
  expect_s3_class(p, "ggplot")
})

test_that("janusplot show_glossary validation", {
  expect_error(janusplot_style(show_glossary = "yes"), class = "rlang_error")
  expect_error(janusplot_style(show_glossary = NA), class = "rlang_error")
  expect_error(janusplot_style(show_glossary = c(TRUE, FALSE)),
               class = "rlang_error")
})

test_that("janusplot glossary size accepts points or NULL", {
  d <- make_linear_data(n = 80L)
  expect_s3_class(janusplot(d, vars = c("x1", "x2"),
                            style = janusplot_style(
                              text_size = list(glossary = 6)
                            )),
                  "ggplot")
  p <- janusplot(d, vars = c("x1", "x2"),
                 style = janusplot_style(text_size = list(glossary = NULL)))
  expect_null(p$patches$annotation$caption)
})

test_that(".cell_text_sizes sets the strip and diagonal sizes independently", {
  base <- janusplot:::.cell_text_sizes(4)
  strip2 <- janusplot:::.cell_text_sizes(4, list(strip = 2 * base$pt$strip))
  diag2  <- janusplot:::.cell_text_sizes(
    4, list(diagonal = 2 * base$pt$diagonal)
  )
  # The strip size doubles n_edf / glyph but leaves diag untouched.
  expect_equal(strip2$n_edf, base$n_edf * 2)
  expect_equal(strip2$glyph, base$glyph * 2)
  expect_equal(strip2$diag,  base$diag)
  # The diagonal size doubles diag but leaves n_edf untouched.
  expect_equal(diag2$diag,  base$diag * 2)
  expect_equal(diag2$n_edf, base$n_edf)
})

test_that("summary(janusplot_fit()) is the per-cell table behind the plot", {
  d <- make_linear_data(n = 100L)
  fit <- janusplot_fit(d, vars = c("x1", "x2", "x3"))
  tbl <- summary(fit)
  expect_s3_class(plot(fit), "ggplot")
  expect_equal(nrow(tbl), 6L)
  expect_true(all(c("var_x", "var_y", "position", "n_used",
                    "edf", "association_p", "association_p_adj", "signif",
                    "dev_exp", "asymmetry_index",
                    "cor_pearson", "cor_spearman", "cor_kendall",
                    "tie_ratio",
                    "monotonicity_index", "convexity_index",
                    "n_turning_points", "n_inflections",
                    "flat_range_ratio", "shape_category",
                    "shape_code", "shape_archetype",
                    "shape_monotonic", "shape_linear") %in%
                    names(tbl)))
  expect_false(any(c("colour_value", "display") %in% names(tbl)))
  expect_true(all(tbl$position %in% c("upper", "lower")))
})
