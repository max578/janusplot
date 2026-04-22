# Raw GAM fits and per-cell metrics for a smoothed-association matrix

**\[experimental\]**

Companion to
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
returning the raw list of GAM fits plus per-cell metrics (EDF, F-test
p-value, deviance explained, asymmetry index, pairwise correlations,
shape descriptors) without constructing the ggplot. Useful for custom
rendering or downstream analysis.

## Usage

``` r
janusplot_data(
  data,
  vars = NULL,
  adjust = NULL,
  method = "REML",
  k = -1L,
  bs = "tp",
  na_action = c("pairwise", "complete"),
  parallel = FALSE,
  keep_fits = FALSE,
  shape_cutoffs = janusplot_shape_cutoffs(),
  ...
)
```

## Arguments

- data:

  A data frame with numeric columns to include.

- vars:

  Character vector of column names to use. `NULL` (default) uses all
  numeric columns in `data`. Non-numeric columns trigger an error
  listing offenders.

- adjust:

  A one-sided formula RHS giving additional covariates and/or random
  effects to include in every pairwise GAM. For example,
  `adjust = ~ s(age) + s(site, bs = "re")` fits
  `gam(y ~ s(x) + s(age) + s(site, bs = "re"))` for each pair. Default
  `NULL` fits unadjusted pairwise smooths.

- method:

  Smoothing-parameter estimation method passed to
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html). Default
  `"REML"` per mgcv recommendation.

- k:

  Integer, or named list mapping variable names to integers. Basis
  dimension for `s()`. Default `-1L` (mgcv's automatic choice).

- bs:

  Basis type for `s()`. Default `"tp"` (thin plate).

- na_action:

  One of `"pairwise"` (default; per-cell complete observations) or
  `"complete"` (listwise; all cells use the same rows).

- parallel:

  Logical. If `TRUE`, use
  [`future.apply::future_mapply()`](https://future.apply.futureverse.org/reference/future_mapply.html)
  to fit pairs in parallel. Requires the `future.apply` package and a
  user-configured
  [`future::plan()`](https://future.futureverse.org/reference/plan.html).
  Default `FALSE`.

- keep_fits:

  Logical. If `TRUE`, retain full
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) model objects
  in the return (large memory footprint for `k` above ~15). Default
  `FALSE` — retains summary metrics and prediction grids only.

- shape_cutoffs:

  Named list of classification thresholds used to map the continuous
  shape indices (`monotonicity_index`, `convexity_index`) into discrete
  `shape_category` labels. Defaults from
  [`janusplot_shape_cutoffs()`](https://max578.github.io/janusplot/reference/janusplot_shape_cutoffs.md).

- ...:

  Additional arguments passed to
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html).

## Value

A list with components:

- `vars`:

  Character vector of variables used, in plotted order.

- `pairs`:

  List of per-pair results. Each element has `i`, `j`, `var_i`, `var_j`,
  `fit_yx`, `fit_xy` (NULL if `keep_fits = FALSE`), `pred_yx`, `pred_xy`
  (data frames with `x`, `fit`, `se`, `lo`, `hi`), `edf_yx`, `edf_xy`,
  `pvalue_yx`, `pvalue_xy`, `dev_exp_yx`, `dev_exp_xy`, `n_used`,
  `asymmetry_index`, plus Pearson / Spearman / Kendall correlations
  (`cor_pearson`, `cor_spearman`, `cor_kendall`), the maximum tie ratio
  across `x` and `y` (`tie_ratio`), and per-direction shape descriptors
  (`monotonicity_index_yx`, `convexity_index_yx`,
  `monotonicity_index_xy`, `convexity_index_xy`, `n_turning_yx`,
  `n_inflect_yx`, `n_turning_xy`, `n_inflect_xy`, `shape_yx`,
  `shape_xy`). See
  [`janusplot_shape_metrics()`](https://max578.github.io/janusplot/reference/janusplot_shape_metrics.md)
  for the definition of the monotonicity and convexity indices.

- `call`:

  Match call.

## See also

[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
for the ggplot front-end,
[`janusplot_shape_metrics()`](https://max578.github.io/janusplot/reference/janusplot_shape_metrics.md)
for the shape-metric primitives.

Other smooth-associations:
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)

## Examples

``` r
# Per-pair fits + metrics on a small mtcars slice
out <- janusplot_data(mtcars[, c("mpg", "hp", "wt")])
out$pairs[[1L]]$asymmetry_index
#> [1] 0.006028176
out$pairs[[1L]]$cor_spearman
#> [1] -0.8946646
out$pairs[[1L]]$shape_yx
#> [1] "s_shape"
```
