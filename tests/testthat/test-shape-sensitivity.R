skip_on_cran()  # heavy GAM-fit suite: full on CI, skipped on CRAN for time budget

test_that(".sensitivity_shapes() lists the 14 canonical names and is the runner's default", {
  shapes <- janusplot:::.sensitivity_shapes()
  expect_type(shapes, "character")
  expect_length(shapes, 14L)
  expect_true(all(shapes %in% janusplot_shape_hierarchy()$category))
  # The literal default of `shapes` must track the generator list.
  expect_identical(eval(formals(janusplot_shape_sensitivity)$shapes), shapes)
})

test_that("the default and NULL both run every canonical shape", {
  res_default <- janusplot_shape_sensitivity(
    n_grid = 50L, sigma_grid = 0.05, n_rep = 1L, verbose = FALSE
  )
  res_null <- janusplot_shape_sensitivity(
    shapes = NULL, n_grid = 50L, sigma_grid = 0.05, n_rep = 1L,
    verbose = FALSE
  )
  expect_setequal(unique(res_default$truth), janusplot:::.sensitivity_shapes())
  expect_identical(res_default, res_null)
})

test_that("janusplot_shape_sensitivity runs and returns a well-formed classed data frame", {
  res <- janusplot_shape_sensitivity(
    shapes     = c("linear_up", "u_shape", "wave"),
    n_grid     = c(100L, 200L),
    sigma_grid = c(0.05, 0.20),
    n_rep      = 3L,
    verbose    = FALSE
  )
  expect_s3_class(res, c("janusplot_sensitivity", "data.frame"),
                  exact = TRUE)
  expect_equal(nrow(res), 3L * 2L * 2L * 3L)
  expect_true(all(c("truth", "n", "sigma", "seed", "predicted",
                    "correct", "archetype_truth", "archetype_pred",
                    "archetype_correct",
                    "monotonicity_index", "convexity_index",
                    "n_turn", "n_inflect", "error") %in% names(res)))
  # Every truth in, every truth accounted for
  expect_setequal(unique(res$truth), c("linear_up", "u_shape", "wave"))
})

test_that("rejects unknown shapes / malformed grids", {
  expect_error(
    janusplot_shape_sensitivity(shapes = "not_a_shape", n_rep = 2L,
                                verbose = FALSE),
    regexp = "Unknown"
  )
  expect_error(
    janusplot_shape_sensitivity(n_grid = c(3L), n_rep = 2L,
                                verbose = FALSE),
    regexp = "n_grid"
  )
  expect_error(
    janusplot_shape_sensitivity(sigma_grid = c(-0.1), n_rep = 2L,
                                verbose = FALSE),
    regexp = "sigma_grid"
  )
  expect_error(
    janusplot_shape_sensitivity(n_rep = 0L, verbose = FALSE),
    regexp = "n_rep"
  )
})

test_that("summary() returns the expected accuracy table", {
  res <- janusplot_shape_sensitivity(
    shapes     = c("linear_up", "u_shape"),
    n_grid     = c(100L),
    sigma_grid = c(0.05, 0.20),
    n_rep      = 3L,
    verbose    = FALSE
  )
  fine <- summary(res, level = "fine")
  arch <- summary(res, level = "archetype")
  expect_true(all(c("truth", "n", "sigma", "accuracy") %in% names(fine)))
  expect_true(all(c("truth", "n", "sigma", "accuracy") %in% names(arch)))
  expect_equal(nrow(fine), 2L * 1L * 2L)
  expect_true(all(fine$accuracy    >= 0 & fine$accuracy    <= 1))
  expect_true(all(arch$accuracy    >= 0 & arch$accuracy    <= 1))
  expect_identical(summary(res), fine)
  expect_error(summary(res, level = "bogus"), class = "rlang_error")
})

test_that("the shipped demo data carry the class", {
  data("shape_sensitivity_demo", package = "janusplot",
       envir = environment())
  expect_s3_class(shape_sensitivity_demo,
                  c("janusplot_sensitivity", "data.frame"), exact = TRUE)
  expect_identical(nrow(shape_sensitivity_demo), 2160L)
})

test_that("all four plot types render to ggplot objects", {
  data("shape_sensitivity_demo", package = "janusplot",
       envir = environment())
  for (tp in c("confusion_fine", "confusion_archetype",
               "accuracy_grid", "recovery_curves")) {
    p <- plot(shape_sensitivity_demo, tp)
    expect_s3_class(p, "ggplot")
  }
})

test_that("plot() rejects unknown types", {
  data("shape_sensitivity_demo", package = "janusplot",
       envir = environment())
  expect_error(
    plot(shape_sensitivity_demo, "bogus"),
    class = "rlang_error"
  )
})

test_that("the methods accept a plain data frame with the result columns", {
  data("shape_sensitivity_demo", package = "janusplot",
       envir = environment())
  plain <- as.data.frame(shape_sensitivity_demo)
  expect_identical(class(plain), "data.frame")
  expect_identical(
    janusplot:::summary.janusplot_sensitivity(plain, level = "archetype"),
    summary(shape_sensitivity_demo, level = "archetype")
  )
  p <- janusplot:::plot.janusplot_sensitivity(plain, "confusion_fine")
  expect_s3_class(p, "ggplot")
})

test_that("summary() and plot() reject a data frame without the result columns", {
  bad <- structure(data.frame(truth = "linear_up"),
                   class = c("janusplot_sensitivity", "data.frame"))
  expect_error(summary(bad), regexp = "janusplot_shape_sensitivity")
  expect_error(plot(bad, "recovery_curves"),
               regexp = "janusplot_shape_sensitivity")
})

test_that("the 0.2.0 sensitivity helpers are gone", {
  ns <- asNamespace("janusplot")
  for (nm in c("janusplot_shape_sensitivity_shapes",
               "janusplot_shape_sensitivity_summary",
               "janusplot_shape_sensitivity_plot")) {
    expect_false(exists(nm, envir = ns, inherits = FALSE), label = nm)
  }
})

test_that("linear_up is recognised as monotone at moderate n, low noise", {
  # Sanity bound on H1-style behaviour for the easiest shape. The
  # REML spline may pick up tiny curvature from noisy linear data
  # (landing on convex_up / concave_up — still monotone increasing),
  # so we test the coarser `shape_monotonic` tier: the classifier
  # must at least recognise the truth as monotone.
  res <- janusplot_shape_sensitivity(
    shapes     = "linear_up",
    n_grid     = 500L,
    sigma_grid = 0.05,
    n_rep      = 20L,
    verbose    = FALSE
  )
  monot_pred <- janusplot:::.shape_lookup(res$predicted, "monotonic")
  expect_gte(mean(monot_pred == "monotone", na.rm = TRUE), 0.95)
})

test_that("wave and bi_wave generators have the extrema their categories need", {
  gens <- janusplot:::.shape_sensitivity_generators()
  x <- seq(0, 1, length.out = 400L)
  turning <- function(y) {
    m <- janusplot:::.compute_shape_metrics(list(
      x_name = "x", y_name = "y",
      pred = data.frame(x = x, fit = y), raw = data.frame(x = x, y = y)
    ))
    m
  }
  w <- turning(gens$wave(x))
  expect_equal(w$n_turning_points, 2L)
  expect_equal(w$shape_category, "wave")
  bw <- turning(gens$bi_wave(x))
  expect_equal(bw$n_turning_points, 4L)
  # Four interior extrema force at least three inflections, so the
  # noiseless bi-wave lands in the bi_wave_ripple cell of its archetype.
  expect_equal(janusplot:::.shape_lookup(bw$shape_category, "archetype"),
               "multimodal")
  expect_true(bw$shape_category %in% c("bi_wave", "bi_wave_ripple"))
})
