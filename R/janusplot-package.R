#' janusplot: Asymmetric Smoothed-Association Matrices via GAM Fits
#'
#' @description
#' `janusplot` draws pairwise, asymmetric smoothed-association matrices
#' of continuous variables. Each off-diagonal cell `[r, c]` shows the
#' fitted spline of `x_r ~ s(x_c)` from an [mgcv::gam()] or [mgcv::bam()]
#' model, so the two cells of a pair hold the two directional regressions
#' `y ~ s(x)` and `x ~ s(y)`.
#'
#' Unlike a Pearson correlation matrix (one scalar per pair, symmetric),
#' a smoothed-association matrix gives two curves per pair and is
#' intentionally asymmetric. Heteroscedasticity, leverage, and directional
#' non-linearity become visually evident.
#'
#' # Main functions
#'
#' The model is fitted once and every view reads the fitted object.
#'
#' * [janusplot_fit()] fits every ordered pair once and returns a
#'   `janusplot_fit` object; `print()` gives an overview, `summary()` the
#'   per-cell table and `plot()` the matrix ([plot.janusplot_fit()]).
#' * [janusplot()] fits and draws the matrix in one call.
#' * [janusplot_pair()] draws the two directions of one or more pairs
#'   side by side, or overlaid in one z-score panel.
#' * [janusplot_compare()] matches two fits of the same variables cell by
#'   cell, typically a marginal fit against an adjusted one.
#' * [janusplot_direction()] runs the residual-independence test that
#'   licenses a directional reading of a pair, and abstains where the
#'   additive noise model cannot decide.
#' * [janusplot_style()] holds every appearance setting of the views.
#'
#' # Asymmetry index
#'
#' For each pair, the asymmetry index `A_ij = |EDF_yx - EDF_xy| /
#' (EDF_yx + EDF_xy)` is bounded in \[0, 1\], where `EDF_xy` is the EDF
#' of `x_i ~ s(x_j)` (upper triangle, `i < j`) and `EDF_yx` that of
#' `x_j ~ s(x_i)` (lower triangle). Values near 0 indicate
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
#' [janusplot_direction()] supplies the missing half of that
#' procedure: the residual-independence test whose one-sided outcome
#' is what actually licenses a directional claim.
#'
#' @keywords internal
#' @aliases janusplot-package
#' @importFrom stats as.formula complete.cases predict quantile sd cor as.dist hclust
#' @importFrom stats residuals fitted shapiro.test
#' @importFrom rlang arg_match check_installed is_installed .data
"_PACKAGE"
