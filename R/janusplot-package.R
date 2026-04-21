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
#' * [janusplot()] — returns a ggplot of the matrix.
#' * [janusplot_data()] — returns the raw GAM fits + per-cell metrics
#'   (for custom plotting or downstream analysis).
#'
#' # Asymmetry index
#'
#' For each pair, the asymmetry index `A_ij = |EDF_yx - EDF_xy| /
#' (EDF_yx + EDF_xy)` is bounded in \[0, 1\]. Values near 0 indicate
#' symmetric complexity; values near 1 indicate the two directional
#' fits differ sharply in effective degrees of freedom.
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
#'
#' @keywords internal
#' @aliases janusplot-package
#' @importFrom stats as.formula complete.cases predict quantile sd cor as.dist hclust
#' @importFrom rlang arg_match check_installed is_installed .data
"_PACKAGE"
