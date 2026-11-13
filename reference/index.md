# Package index

## Fit and plot

Fit every ordered pair once, then print, summarise and draw the matrix
from the fitted object; or fit and draw in one call. The fitted curves
are also available as a data frame.

- [`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
  [`print(`*`<janusplot_fit>`*`)`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
  [`summary(`*`<janusplot_fit>`*`)`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
  **\[stable\]** : Fit every ordered pair of a smoothed-association
  matrix
- [`plot(`*`<janusplot_fit>`*`)`](https://max578.github.io/janusplot/reference/plot.janusplot_fit.md)
  **\[stable\]** : Draw the matrix of a janusplot fit
- [`janusplot_curves()`](https://max578.github.io/janusplot/reference/janusplot_curves.md)
  **\[experimental\]** : Fitted curves of a janusplot fit as a data
  frame
- [`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
  **\[stable\]** : Asymmetric smoothed-association matrix

## Pairs and direction

The two directions of a pair drawn side by side or overlaid, and the
residual-independence test that licenses a directional reading of a
pair, abstaining where the additive noise model cannot decide. A
bootstrap reference says how large the asymmetry index of a pair gets by
chance.

- [`janusplot_pair()`](https://max578.github.io/janusplot/reference/janusplot_pair.md)
  **\[stable\]** : Draw both directions of pairs of a janusplot fit
- [`janusplot_direction()`](https://max578.github.io/janusplot/reference/janusplot_direction.md)
  [`print(`*`<janusplot_direction>`*`)`](https://max578.github.io/janusplot/reference/janusplot_direction.md)
  **\[experimental\]** : Test whether the residual-independence
  condition licenses a direction
- [`janusplot_reference()`](https://max578.github.io/janusplot/reference/janusplot_reference.md)
  [`print(`*`<janusplot_reference>`*`)`](https://max578.github.io/janusplot/reference/janusplot_reference.md)
  [`plot(`*`<janusplot_reference>`*`)`](https://max578.github.io/janusplot/reference/janusplot_reference.md)
  **\[experimental\]** : Bootstrap reference for the asymmetry index of
  a pair

## Comparing fits

Two fits of the same variables matched cell by cell, typically a
marginal fit against an adjusted one.

- [`janusplot_compare()`](https://max578.github.io/janusplot/reference/janusplot_compare.md)
  [`print(`*`<janusplot_compare>`*`)`](https://max578.github.io/janusplot/reference/janusplot_compare.md)
  **\[stable\]** : Compare two fits of the same variables cell by cell
- [`plot(`*`<janusplot_compare>`*`)`](https://max578.github.io/janusplot/reference/plot.janusplot_compare.md)
  **\[stable\]** : Draw two fits of the same variables in one matrix

## Appearance

Every appearance setting of the views, in one object.

- [`janusplot_style()`](https://max578.github.io/janusplot/reference/janusplot_style.md)
  [`print(`*`<janusplot_style>`*`)`](https://max578.github.io/janusplot/reference/janusplot_style.md)
  **\[stable\]** : Appearance settings for janusplot views

## Shape taxonomy

The 27-category objective shape descriptor. Public helpers for computing
shape metrics on any mgcv smooth, tuning the classification cutoffs, and
inspecting the hierarchy table.

- [`janusplot_shape_metrics()`](https://max578.github.io/janusplot/reference/janusplot_shape_metrics.md)
  **\[experimental\]** : Shape metrics for a fitted univariate smooth

- [`janusplot_shape_cutoffs()`](https://max578.github.io/janusplot/reference/janusplot_shape_cutoffs.md)
  **\[experimental\]** :

  Default cutoff thresholds for `shape_category` classification

- [`janusplot_shape_hierarchy()`](https://max578.github.io/janusplot/reference/janusplot_shape_hierarchy.md)
  **\[experimental\]** : Shape-category taxonomy table

## Shape-recognition sensitivity study

How reliably the classifier recovers ground-truth shapes across
sample-size and noise regimes, with a precomputed demo sweep and four
diagnostic plots.

- [`janusplot_shape_sensitivity()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md)
  [`summary(`*`<janusplot_sensitivity>`*`)`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md)
  [`plot(`*`<janusplot_sensitivity>`*`)`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md)
  **\[experimental\]** : Shape-recognition sensitivity study
- [`shape_sensitivity_demo`](https://max578.github.io/janusplot/reference/shape_sensitivity_demo.md)
  : Precomputed shape-recognition sensitivity results (demo)

## Deprecated

Kept for one release with a deprecation warning; removed in 1.1.0.

- [`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md)
  **\[deprecated\]** : Deprecated: raw GAM fits and per-cell metrics
- [`janusplot_direction_test()`](https://max578.github.io/janusplot/reference/janusplot_direction_test.md)
  **\[deprecated\]** : Deprecated: residual-independence direction test
  on a data frame
