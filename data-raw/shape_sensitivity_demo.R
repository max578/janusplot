# Reproducible regenerator for data/shape_sensitivity_demo.rda.
#
# Small-enough footprint to compile the vignette quickly while still
# covering every archetype and showing meaningful accuracy variation.
# Run with devtools::load_all() then source this file, or run
# directly once janusplot is installed.

library(janusplot)

shape_sensitivity_demo <- janusplot_shape_sensitivity(
  shapes     = c("linear_up", "concave_up",
                 "u_shape", "inverted_u",
                 "wave", "bimodal"),
  n_grid     = c(100L, 200L, 500L),
  sigma_grid = c(0.05, 0.10, 0.20, 0.40),
  n_rep      = 30L,
  seed       = 2026L,
  parallel   = FALSE,
  verbose    = TRUE
)

stopifnot(
  nrow(shape_sensitivity_demo) == 6L * 3L * 4L * 30L,
  all(c("truth", "predicted", "archetype_correct") %in%
        names(shape_sensitivity_demo))
)

usethis::use_data(shape_sensitivity_demo, overwrite = TRUE,
                  compress = "xz")
