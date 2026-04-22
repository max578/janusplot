# Package index

## Matrix rendering

Render an asymmetric smoothed-association matrix.

- [`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
  **\[experimental\]** : Asymmetric smoothed-association matrix
- [`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md)
  **\[experimental\]** : Raw GAM fits and per-cell metrics for a
  smoothed-association matrix

## Shape taxonomy

The 24-category objective shape descriptor. Public helpers for computing
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

Characterise how reliably the classifier recovers ground-truth shapes
across sample-size and noise regimes. Ships with a precomputed demo
sweep and four diagnostic plots.

- [`janusplot_shape_sensitivity()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md)
  **\[experimental\]** : Shape-recognition sensitivity study
- [`janusplot_shape_sensitivity_shapes()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_shapes.md)
  **\[experimental\]** : Canonical ground-truth shapes for the
  sensitivity study
- [`janusplot_shape_sensitivity_summary()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_summary.md)
  **\[experimental\]** : Summarise a shape-sensitivity sweep
- [`janusplot_shape_sensitivity_plot()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_plot.md)
  **\[experimental\]** : Visualise a shape-sensitivity sweep
- [`shape_sensitivity_demo`](https://max578.github.io/janusplot/reference/shape_sensitivity_demo.md)
  : Precomputed shape-recognition sensitivity results (demo)
