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
  derivatives = integer(),
  derivative_ci = c("pointwise", "none", "simultaneous"),
  derivative_ci_nsim = 1000L,
  n_grid = NULL,
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

- derivatives:

  Integer vector of derivative orders to compute on every pair (subset
  of `1:2`). Default [`integer()`](https://rdrr.io/r/base/integer.html)
  — no derivatives. Unlike
  [`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md),
  the data companion can return multiple orders from a single call for
  programmatic analysis; pass `c(1L, 2L)` to surface both.

- derivative_ci:

  One of `"none"` (default), `"pointwise"`, or `"simultaneous"`.
  Controls whether — and how — a 95% confidence ribbon is drawn
  underneath the derivative curve when `display %in% c("d1", "d2")`.
  Ignored when `display = "fit"`.

  - `"none"` — no ribbon. The curve and the zero reference line are all
    you see. Default, because pointwise ribbons overshoot nominal
    coverage as a joint region and can invite over-reading of local
    features.

  - `"pointwise"` — 95% pointwise ribbon from \\\sqrt{\mathrm{diag}(D
    V_p D^\top)}\\ (Wood 2017 §7.2.4). Valid marginally; not a
    simultaneous statement.

  - `"simultaneous"` — 95% simultaneous band via the Monte Carlo
    construction of Ruppert, Wand & Carroll (2003) popularised for GAMs
    by Simpson (2018, *Frontiers Ecol. Evol.* 6:149): draw \\B\\ samples
    \\\tilde{\boldsymbol\beta} \sim \mathcal{N}(\hat{\boldsymbol\beta},
    V_p)\\, compute \\\max_x \|D_i(\tilde{\boldsymbol\beta} -
    \hat{\boldsymbol\beta})\| / \mathrm{se}\_i\\, and use the
    \\(1-\alpha)\\ quantile as a critical multiplier on the pointwise
    SE. Valid for feature localisation ("where is \\\hat f'(x)\\
    significantly non-zero").

- derivative_ci_nsim:

  Integer. Number of Monte Carlo samples used when
  `derivative_ci = "simultaneous"`. Default `1000L` — a compromise
  between coverage accuracy (Simpson 2018 uses 10000) and CPU budget
  across every pair in a medium-sized matrix. Ignored for any other
  `derivative_ci`.

- n_grid:

  Integer or `NULL`. Number of equally-spaced points used to evaluate
  each fitted smooth (and its derivatives). Default `NULL` resolves to
  `100` when `display = "fit"` and `200` otherwise, because
  finite-difference second derivatives visibly degrade below \\\sim
  150\\ points on moderate-`k` smooths. Supplying `n_grid` directly
  overrides both defaults. Larger grids shift the numerical shape-metric
  values (\\M\\, \\C\\, turning / inflection counts) slightly because
  they are computed on this same grid. Shapes and asymmetry are the
  primary reading; `M`, `C` and the counts are secondary diagnostics and
  the grid-induced drift is tolerable.

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
  `shape_xy`). When `derivatives` is non-empty, each pair additionally
  carries `deriv_yx` and `deriv_xy`, each a named list keyed by order
  (`"1"`, `"2"`) whose entries are data frames with columns `x`, `fit`,
  `se`, `lo`, `hi`, `ci_type` matching the schema of `pred_yx` /
  `pred_xy`. The `ci_type` column records whether the `lo` / `hi`
  columns are `"pointwise"` (default), `"simultaneous"`
  (Ruppert–Wand–Carroll / Simpson 2018 critical-multiplier bands), or
  `"none"`. When `derivative_ci = "simultaneous"`, each derivative frame
  also carries a `"crit_multiplier"` attribute giving the MC-derived
  critical multiplier used. See
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
