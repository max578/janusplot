# janusplot: Asymmetric Smoothed-Association Matrices via GAM Fits

`janusplot` draws pairwise, asymmetric smoothed-association matrices of
continuous variables. Each off-diagonal cell `[r, c]` shows the fitted
spline of `x_r ~ s(x_c)` from an
[`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) or
[`mgcv::bam()`](https://rdrr.io/pkg/mgcv/man/bam.html) model, so the two
cells of a pair hold the two directional regressions `y ~ s(x)` and
`x ~ s(y)`.

Unlike a Pearson correlation matrix (one scalar per pair, symmetric), a
smoothed-association matrix gives two curves per pair and is
intentionally asymmetric. Heteroscedasticity, leverage, and directional
non-linearity become visually evident.

## Main functions

The model is fitted once and every view reads the fitted object.

- [`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
  fits every ordered pair once and returns a `janusplot_fit` object;
  [`print()`](https://rdrr.io/r/base/print.html) gives an overview,
  [`summary()`](https://rdrr.io/r/base/summary.html) the per-cell table
  and [`plot()`](https://rdrr.io/r/graphics/plot.default.html) the
  matrix
  ([`plot.janusplot_fit()`](https://max578.github.io/janusplot/reference/plot.janusplot_fit.md)).

- [`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
  fits and draws the matrix in one call.

- [`janusplot_pair()`](https://max578.github.io/janusplot/reference/janusplot_pair.md)
  draws the two directions of one or more pairs side by side, or
  overlaid in one z-score panel.

- [`janusplot_compare()`](https://max578.github.io/janusplot/reference/janusplot_compare.md)
  matches two fits of the same variables cell by cell, typically a
  marginal fit against an adjusted one.

- [`janusplot_direction()`](https://max578.github.io/janusplot/reference/janusplot_direction.md)
  runs the residual-independence test that licenses a directional
  reading of a pair, and abstains where the additive noise model cannot
  decide.

- [`janusplot_style()`](https://max578.github.io/janusplot/reference/janusplot_style.md)
  holds every appearance setting of the views.

## Asymmetry index

For each pair, the asymmetry index
`A_ij = |EDF_yx - EDF_xy| / (EDF_yx + EDF_xy)` is bounded in \[0, 1\],
where `EDF_xy` is the EDF of `x_i ~ s(x_j)` (upper triangle, `i < j`)
and `EDF_yx` that of `x_j ~ s(x_i)` (lower triangle). Values near 0
indicate symmetric complexity; values near 1 indicate the two
directional fits differ sharply in effective degrees of freedom. A is
unreliable when either direction of the pair had its basis dimension
capped at the number of distinct predictor values (`k_capped_yx` or
`k_capped_xy` is `TRUE`).

Under the additive noise model (Hoyer et al. 2009; Peters et al. 2014),
the two directional regressions are generally asymmetric when the
data-generating process is non-linear, and this asymmetry identifies the
causal direction under mild conditions. The asymmetry index is offered
here as a *visual pre-discovery diagnostic* rather than a causal
inference procedure; see the package vignette and accompanying paper for
full scope and limitations (in particular the failure modes under
heteroscedasticity, confounding, and Gaussian-linear DGPs).
[`janusplot_direction()`](https://max578.github.io/janusplot/reference/janusplot_direction.md)
supplies the missing half of that procedure: the residual-independence
test whose one-sided outcome is what actually licenses a directional
claim.

## See also

Useful links:

- <https://github.com/max578/janusplot>

- <https://max578.github.io/janusplot/>

- Report bugs at <https://github.com/max578/janusplot/issues>

## Author

**Maintainer**: Max Moldovan <max.moldovan@adelaide.edu.au>
([ORCID](https://orcid.org/0000-0001-9680-8474)) \[copyright holder\]

Authors:

- Max Moldovan <max.moldovan@adelaide.edu.au>
  ([ORCID](https://orcid.org/0000-0001-9680-8474)) \[copyright holder\]
