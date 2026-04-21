test_that("janusplot_shape_sensitivity_shapes returns 14 canonical names", {
  shapes <- janusplot_shape_sensitivity_shapes()
  expect_type(shapes, "character")
  expect_length(shapes, 14L)
  expect_true(all(shapes %in% janusplot_shape_hierarchy()$category))
})

test_that("janusplot_shape_sensitivity runs and returns a well-formed data frame", {
  res <- janusplot_shape_sensitivity(
    shapes     = c("linear_up", "u_shape", "wave"),
    n_grid     = c(100L, 200L),
    sigma_grid = c(0.05, 0.20),
    n_rep      = 3L,
    verbose    = FALSE
  )
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 3L * 2L * 2L * 3L)
  expect_true(all(c("truth", "n", "sigma", "seed", "predicted",
                    "correct", "archetype_truth", "archetype_pred",
                    "archetype_correct", "M", "C",
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

test_that("summary returns the expected accuracy table", {
  res <- janusplot_shape_sensitivity(
    shapes     = c("linear_up", "u_shape"),
    n_grid     = c(100L),
    sigma_grid = c(0.05, 0.20),
    n_rep      = 3L,
    verbose    = FALSE
  )
  fine <- janusplot_shape_sensitivity_summary(res, "fine")
  arch <- janusplot_shape_sensitivity_summary(res, "archetype")
  expect_true(all(c("truth", "n", "sigma", "accuracy") %in% names(fine)))
  expect_true(all(c("truth", "n", "sigma", "accuracy") %in% names(arch)))
  expect_equal(nrow(fine), 2L * 1L * 2L)
  expect_true(all(fine$accuracy    >= 0 & fine$accuracy    <= 1))
  expect_true(all(arch$accuracy    >= 0 & arch$accuracy    <= 1))
})

test_that("all four plot types render to ggplot objects", {
  data("shape_sensitivity_demo", package = "janusplot",
       envir = environment())
  for (tp in c("confusion_fine", "confusion_archetype",
               "accuracy_grid", "recovery_curves")) {
    p <- janusplot_shape_sensitivity_plot(shape_sensitivity_demo, tp)
    expect_s3_class(p, "ggplot")
  }
})

test_that("plot rejects unknown types", {
  data("shape_sensitivity_demo", package = "janusplot",
       envir = environment())
  expect_error(
    janusplot_shape_sensitivity_plot(shape_sensitivity_demo, "bogus"),
    class = "rlang_error"
  )
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
