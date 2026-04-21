#' Precomputed shape-recognition sensitivity results (demo)
#'
#' @description
#' Raw output from a small-footprint invocation of
#' [janusplot_shape_sensitivity()]. Shipped so users can explore the
#' sensitivity API and regenerate every figure in the
#' `shape-recognition-sensitivity` vignette without having to re-run
#' the sweep themselves. Regenerated via
#' `data-raw/shape_sensitivity_demo.R`.
#'
#' Design:
#' \itemize{
#'   \item **Shapes** (6, one per non-degenerate archetype):
#'     `linear_up`, `concave_up`, `u_shape`, `inverted_u`, `wave`,
#'     `bimodal`.
#'   \item **Sample sizes** (3): `c(100, 200, 500)`.
#'   \item **Noise levels** (4): `c(0.05, 0.10, 0.20, 0.40)` fraction
#'     of y-range.
#'   \item **Replicates**: 30.
#'   \item **Total fits**: 2160.
#'   \item **Seed**: 2026.
#' }
#'
#' @format A data frame with 2160 rows and 14 columns — see the
#'   "Value" section of [janusplot_shape_sensitivity()] for the
#'   column schema.
#'
#' @seealso [janusplot_shape_sensitivity()],
#'   [janusplot_shape_sensitivity_plot()],
#'   [janusplot_shape_sensitivity_summary()].
#'
#' @examples
#' data("shape_sensitivity_demo", package = "janusplot")
#' head(shape_sensitivity_demo)
#' janusplot_shape_sensitivity_plot(shape_sensitivity_demo,
#'                                  "recovery_curves")
"shape_sensitivity_demo"
