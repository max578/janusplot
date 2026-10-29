#' janusplot: Asymmetric Smoothed-Association Matrices via GAM Fits
#'
#' @description
#' `janusplot` renders pairwise, asymmetric smoothed-association matrices
#' of continuous variables. Each cell shows the fitted spline from an
#' [mgcv::gam()] model, with upper and lower triangles encoding the two
#' directional regressions `y ~ s(x)` and `x ~ s(y)` respectively.
#'
#' Unlike a Pearson correlation matrix (one scalar per pair, symmetric),
#' a smoothed-association matrix gives two curves per pair and is
#' intentionally asymmetric. Heteroscedasticity, leverage, and directional
#' non-linearity become visually evident.
#'
#' # Main functions
#'
#' * [janusplot()] -- returns a ggplot of the matrix.
#' * [janusplot_fit()] -- fits every ordered pair once and returns the
#'   fit object (per-pair metrics, per-cell table via `summary()`, flags)
#'   for custom plotting or downstream analysis.
#' * [janusplot_direction_test()] -- runs the residual-independence test
#'   that licenses a directional reading of a pair's asymmetry, and
#'   abstains where the additive noise model cannot decide.
#'
#' # Asymmetry index
#'
#' For each pair, the asymmetry index `A_ij = |EDF_yx - EDF_xy| /
#' (EDF_yx + EDF_xy)` is bounded in \[0, 1\], where `EDF_yx` is the EDF
#' of `x_j ~ s(x_i)` (upper triangle, `i < j`) and `EDF_xy` that of
#' `x_i ~ s(x_j)` (lower triangle). Values near 0 indicate
#' symmetric complexity; values near 1 indicate the two directional
#' fits differ sharply in effective degrees of freedom. A is unreliable
#' when either direction of the pair had its basis dimension capped at
#' the number of distinct predictor values (`k_capped_yx` or
#' `k_capped_xy` is `TRUE`).
#'
#' Under the additive noise model (Hoyer et al. 2009; Peters et al.
#' 2014), the two directional regressions are generally asymmetric
#' when the data-generating process is non-linear, and this
#' asymmetry identifies the causal direction under mild conditions.
#' The asymmetry index is offered here as a *visual pre-discovery
#' diagnostic* rather than a causal inference procedure; see the
#' package vignette and accompanying paper for full scope and
#' limitations (in particular the failure modes under
#' heteroscedasticity, confounding, and Gaussian-linear DGPs).
#' [janusplot_direction_test()] supplies the missing half of that
#' procedure: the residual-independence test whose one-sided outcome
#' is what actually licenses a directional claim.
#'
#' @keywords internal
#' @aliases janusplot-package
#' @importFrom stats as.formula complete.cases predict quantile sd cor as.dist hclust
#' @importFrom stats residuals fitted shapiro.test
#' @importFrom rlang arg_match check_installed is_installed .data
"_PACKAGE"
