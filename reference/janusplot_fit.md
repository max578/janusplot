# Fit every ordered pair of a smoothed-association matrix

**\[stable\]**

Fits `gam(x_j ~ s(x_i) + <adjust>)` once for every ordered pair of
numeric variables and returns a `janusplot_fit` object holding the
per-pair results, a per-cell summary table, a cleaned copy of the data
used and the fit settings.
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
draws the matrix; [`summary()`](https://rdrr.io/r/base/summary.html)
returns the per-cell table.

## Usage

``` r
janusplot_fit(
  data,
  vars = NULL,
  adjust = NULL,
  k = -1L,
  bs = "tp",
  engine = c("bam", "gam"),
  method = NULL,
  na_action = c("pairwise", "complete"),
  n_grid = NULL,
  derivatives = 1:2,
  derivative_ci = c("pointwise", "none", "simultaneous"),
  derivative_ci_nsim = 1000L,
  p_adjust = c("none", "BH", "holm"),
  shape_cutoffs = janusplot_shape_cutoffs(),
  k_check_thresholds = NULL,
  auto_refit_k = FALSE,
  k_max_iter = 2L,
  discrete = FALSE,
  nthreads = 1L,
  parallel = FALSE,
  keep_fits = FALSE,
  ...
)

# S3 method for class 'janusplot_fit'
print(x, ...)

# S3 method for class 'janusplot_fit'
summary(object, ...)
```

## Arguments

- data:

  A data frame. Column names need not be syntactic; fits run under
  internal aliases and every result reports the original names.

- vars:

  Character vector of numeric column names to fit, in matrix order.
  `NULL` (the default) takes every numeric column of `data`. Identical
  or exactly collinear columns are not fitted against each other; their
  cells are listed in `flags$failed`.

- adjust:

  One-sided formula of covariates and random effects added to every
  pairwise model, for example `~ s(age) + s(site, bs = "re")`. `NULL`
  (the default) fits unadjusted smooths. Character and logical `adjust`
  columns are converted to factor before fitting. Random-effect smooths
  are excluded from prediction, so the curve and its band are
  population-level. With the identity link (the Gaussian default) the
  curve is the smooth averaged over the adjustment covariates of the
  data, and the plots draw each point as a partial residual: the
  observation with its own adjustment replaced by that average, so
  points and curve share one level (`style$adjusted_points`). With
  another link, numeric covariates are held at their mean and fixed
  factors at their most frequent level, and points stay raw.

- k:

  Basis dimension for `s()`: a single integer, or a named list of
  integers keyed by variable name. `-1L` (the default) leaves the choice
  to mgcv. Each cell's basis is capped at the number of distinct
  predictor values in its rows, and an `auto_refit_k` refit stops one
  below that number; capped cells are listed in `flags$k_capped` and
  recorded as `k_requested`, `k_used` and `k_capped`.

- bs:

  Basis type for `s()`; `"tp"` (thin plate) by default.

- engine:

  `"bam"` (the default) fits with
  [`mgcv::bam()`](https://rdrr.io/pkg/mgcv/man/bam.html), `"gam"` with
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html). The two differ
  in their default `method` and by about one to three percent in EDF on
  the same data.

- method:

  Smoothing-parameter estimation method passed to mgcv. `NULL` (the
  default) resolves to `"fREML"` for `engine = "bam"` and `"REML"` for
  `engine = "gam"`.

- na_action:

  `"pairwise"` (the default) fits each cell on the rows complete for its
  own variables and the `adjust` columns; `"complete"` first drops every
  row with a missing value in any fitted or adjusting column. Infinite
  values count as missing and are reported in a warning. A pair sharing
  fewer than 5 complete rows is not fitted and is listed in
  `flags$sparse`; an error is raised only when no pair reaches 5 rows.

- n_grid:

  Number of equally spaced points at which each smooth and its
  derivatives are evaluated, at least 10. `NULL` (the default) resolves
  to `200L` when `derivatives` is non-empty and `100L` otherwise.

- derivatives:

  Integer vector of derivative orders to compute for every cell, a
  subset of `1:2`. The default `1:2` computes both;
  [`integer()`](https://rdrr.io/r/base/integer.html) computes none.

- derivative_ci:

  The band stored with each derivative curve: `"pointwise"` (the
  default), `"none"` or `"simultaneous"`. Simultaneous bands use the
  Monte Carlo critical multiplier of Ruppert, Wand and Carroll (2003) as
  applied to GAMs by Simpson (2018).

- derivative_ci_nsim:

  Number of Monte Carlo draws for `derivative_ci = "simultaneous"`;
  `1000L` by default and at least 100.

- p_adjust:

  Multiplicity adjustment of the smooth F-test p-values across the
  `k(k - 1)` directed cells: `"none"` (the default), `"BH"` or `"holm"`,
  applied once with
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html). Raw and
  adjusted values are both kept.

- shape_cutoffs:

  Named list of classification thresholds, from
  [`janusplot_shape_cutoffs()`](https://max578.github.io/janusplot/reference/janusplot_shape_cutoffs.md),
  mapping the shape indices to a `shape_category` label.

- k_check_thresholds:

  Named list with entries `edf_ratio`, `k_index` and `p` for the
  basis-dimension diagnostic that follows
  [`mgcv::k.check()`](https://rdrr.io/pkg/mgcv/man/k.check.html). `NULL`
  (the default) uses `edf_ratio = 0.9`, `k_index = 1` and `p = 0.05`.

- auto_refit_k:

  Logical. When `TRUE`, a cell flagged by the k-check is refitted with a
  doubled basis until the flag clears, the distinct-value cap is reached
  or `k_max_iter` doublings have run. The diagnostic is computed either
  way; the default is `FALSE`.

- k_max_iter:

  Maximum number of doublings per cell when `auto_refit_k = TRUE`; `2L`
  by default.

- discrete:

  Logical. Passes mgcv's covariate discretisation to
  [`mgcv::bam()`](https://rdrr.io/pkg/mgcv/man/bam.html); `FALSE` by
  default and ignored for `engine = "gam"`.

- nthreads:

  Integer. Threads used inside each
  [`mgcv::bam()`](https://rdrr.io/pkg/mgcv/man/bam.html) fit; `1L` by
  default, which avoids oversubscription under `parallel = TRUE`.
  Ignored for `engine = "gam"`.

- parallel:

  Logical. When `TRUE`, pairs are fitted with
  [`future.apply::future_mapply()`](https://future.apply.futureverse.org/reference/future_mapply.html)
  under the user's
  [`future::plan()`](https://future.futureverse.org/reference/plan.html);
  `FALSE` by default.

- keep_fits:

  Logical. When `TRUE`, the mgcv model objects are kept in `$fits` and
  as `fit_yx` / `fit_xy` of every pair; `FALSE` (the default) keeps
  metrics and prediction grids only.

- ...:

  Further arguments passed to
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) or
  [`mgcv::bam()`](https://rdrr.io/pkg/mgcv/man/bam.html). The
  [`print()`](https://rdrr.io/r/base/print.html) and
  [`summary()`](https://rdrr.io/r/base/summary.html) methods ignore
  them. Under a `family` with a non-identity link the curve and its band
  are drawn on the response scale, while the derivatives, the shape
  indices and the shape label describe the linear predictor (the link
  scale). The two agree on monotone labels; a curvature label can
  differ, for example a log-linear Poisson mean is `linear_up` on the
  link scale and convex on the response scale. A `family` applies to
  every cell of the matrix, so fit count or binary columns in their own
  call, not beside continuous ones.

- x:

  A `janusplot_fit` object.

- object:

  A `janusplot_fit` object.

## Value

A list of class `janusplot_fit` with components, in order:

- `vars`:

  Character vector of the variables fitted, in matrix order.

- `pairs`:

  List with one element per unordered pair `i < j`. Each element carries
  `i`, `j`, `var_i`, `var_j`, `fit_yx`, `fit_xy` (`NULL` unless
  `keep_fits = TRUE`), the prediction grids `pred_yx`, `pred_xy` (data
  frames with `x`, `fit`, `se`, `lo`, `hi` on the response scale, `se`
  on the link scale, and `fit_link` when the link is not the identity),
  the partial residuals `partial_yx`, `partial_xy` (numeric, one per row
  the cell was fitted on; `NULL` without `adjust` or with a non-identity
  link), `edf_yx`, `edf_xy`, `association_p_yx`, `association_p_xy`,
  `association_p_adj_yx`, `association_p_adj_xy`, `dev_exp_yx`,
  `dev_exp_xy`, `deviance_gap_yx`, `deviance_gap_xy`, `n_used`,
  `asymmetry_index`, `k_capped_yx`, `k_capped_xy`,
  `directional_complexity_yx`, `directional_complexity_xy`, the
  correlations `cor_pearson`, `cor_spearman`, `cor_kendall` and
  `tie_ratio`, the shape indices `monotonicity_index_*`,
  `convexity_index_*`, the counts `n_turning_*`, `n_inflect_*`, the
  labels `shape_*`, `shape_code_*`, `shape_archetype_*`,
  `shape_monotonic_*`, `shape_linear_*`, the margins
  `shape_borderline_yx`, `shape_borderline_xy` (`NA` for an
  `indeterminate` or count-decided label), the derivative curves
  `deriv_yx`, `deriv_xy` (lists keyed `"1"`, `"2"` of data frames with
  `x`, `fit`, `se`, `lo`, `hi`, `ci_type`), the prediction references
  `prediction_reference_yx`, `prediction_reference_xy`, the k-check
  lists `k_check_yx`, `k_check_xy`, `k_requested_*`, `k_used_*`,
  `engine`, `method`, `error_yx` and `error_xy`.

- `table`:

  Data frame with one row per directed cell: `var_x`, `var_y`,
  `position` (`"upper"` if `var_y` is first), `n_used`, `edf`,
  `association_p`, `association_p_adj`, `signif` (glyph from the
  adjusted p-value), `dev_exp`, `deviance_gap`, `asymmetry_index`,
  `k_capped_yx`, `k_capped_xy`, `directional_complexity` (signed for
  this cell), the correlations, the shape indices, counts and labels,
  `shape_borderline`, the k-check columns `k_prime`, `k_index`, `k_p`,
  `k_flag`, `k_check_status`, `k_initial`, `k_final`, `k_iterations`,
  `k_at_cap`, `k_requested`, `k_used`, `k_capped`, `engine`, `method`
  and `error`. [`summary()`](https://rdrr.io/r/base/summary.html)
  returns this table.

- `data`:

  The cleaned copy of the columns used, as described in Details.

- `adjust`:

  The `adjust` formula, or `NULL`.

- `settings`:

  Named list of the fit settings as resolved: `engine`, `method`, `k`,
  `bs`, `na_action`, `n_grid`, `derivatives`, `derivative_ci`,
  `derivative_ci_nsim`, `p_adjust`, `shape_cutoffs`,
  `k_check_thresholds`, `auto_refit_k`, `k_max_iter`, `family` and
  `link` (names, as in
  [`stats::family()`](https://rdrr.io/r/stats/family.html)), `discrete`
  and `nthreads`.

- `flags`:

  List with `failed` (data frame of `var_x`, `var_y`, `reason` for cells
  that carry no fit), `k_capped` and `k_flagged` (character vectors of
  cells as `"var_y ~ s(var_x)"`) and `sparse` (data frame of `var_i`,
  `var_j`, `n_shared` for pairs with fewer than 5 shared rows).

- `fits`:

  When `keep_fits = TRUE`, the list of mgcv objects keyed `"i_j"` for
  the cell `vars[j] ~ s(vars[i])`; otherwise `NULL`.

- `call`:

  The matched call.

[`print()`](https://rdrr.io/r/base/print.html) returns `x` invisibly;
[`summary()`](https://rdrr.io/r/base/summary.html) returns the `table`
component.

## Details

Suffixes name the direction of fit. `_xy` is `vars[i] ~ s(vars[j])` for
`i < j`, the upper-triangle cell at row `i`, column `j`; `_yx` is
`vars[j] ~ s(vars[i])`, the lower-triangle cell. In `$table` each row is
one directed cell with `var_x` the predictor and `var_y` the response.

First and second derivatives of every smooth are computed at fit time by
default, so `n_grid = NULL` resolves to 200 evaluation points. The shape
indices `M` and `C`, the turning-point and inflection counts and the
flat-range ratio are computed on this grid.

The smooth F-test p-values of the directed cells form one family.
`p_adjust` adjusts them once with
[`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) and the
result is stored beside the raw values as `association_p_adj`. A failed
cell has no p-value and stays out of the family, so the family is the
cells that produced a p-value, at most `k(k - 1)`. Under `"none"` the
adjusted columns equal the raw ones.

`directional_complexity_yx` is `(EDF_yx - EDF_xy) / (EDF_yx + EDF_xy)`
in `[-1, 1]`, positive when the fit of `var_j` on `var_i` is the more
complex direction; `directional_complexity_xy` is its negative and
`asymmetry_index` its magnitude. A is unreliable when either direction
had its basis dimension capped (`k_capped_yx` or `k_capped_xy`), either
at the first fit or when an `auto_refit_k` refit reached the cap
(`k_at_cap` in the k-check columns).

`shape_borderline` is the smallest absolute gap between a shape index
and a classification cutoff whose crossing by that index alone would
change the `shape_category` label, on the index's own scale: `M` and `C`
against the monotonicity and curvature cutoffs, the flat-range ratio
against the `flat` cutoff. A small value marks a label that a slightly
different smooth would have moved. Only `flat` and the monotone labels
of a curve with no turning point and no inflection carry a margin. Every
other label is decided by the turning-point and inflection counts and
has `NA`: the margin does not measure how near a count is to changing.

`$data` is the cleaned copy of the columns used: the fitted variables,
the `adjust` variables and every factor, character or logical column of
`data`, under the original column names, after infinite values are set
to `NA` and character or logical `adjust` columns are converted to
factor. It keeps every row under `na_action = "pairwise"` and the
listwise-complete rows under `"complete"`; a cell's raw points are its
two columns on the rows complete for them and the `adjust` columns.

## See also

[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
for the matrix,
[`janusplot_shape_metrics()`](https://max578.github.io/janusplot/reference/janusplot_shape_metrics.md)
for the shape indices,
[`janusplot_shape_cutoffs()`](https://max578.github.io/janusplot/reference/janusplot_shape_cutoffs.md)
for the classification thresholds.

Other smooth-associations:
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md),
[`janusplot_compare()`](https://max578.github.io/janusplot/reference/janusplot_compare.md),
[`janusplot_curves()`](https://max578.github.io/janusplot/reference/janusplot_curves.md),
[`janusplot_direction()`](https://max578.github.io/janusplot/reference/janusplot_direction.md),
[`janusplot_pair()`](https://max578.github.io/janusplot/reference/janusplot_pair.md),
[`janusplot_reference()`](https://max578.github.io/janusplot/reference/janusplot_reference.md),
[`janusplot_style()`](https://max578.github.io/janusplot/reference/janusplot_style.md),
[`plot.janusplot_compare()`](https://max578.github.io/janusplot/reference/plot.janusplot_compare.md),
[`plot.janusplot_fit()`](https://max578.github.io/janusplot/reference/plot.janusplot_fit.md)

## Examples

``` r
fit <- janusplot_fit(mtcars[, c("mpg", "hp", "wt")], engine = "gam")
fit
#> janusplot fit: 3 variables (mpg, hp, wt)
#> 3 pairs, 6 directed cells
#> engine = gam, method = REML, adjust = none
#> no flags
#> Largest asymmetries:
#>   hp <-> wt  A = 0.45  wt ~ hp: EDF 3.1, p < 0.001, inverted_u | hp ~ wt: EDF 1.2, p < 0.001, concave_up
#>   mpg <-> wt  A = 0.02  wt ~ mpg: EDF 2.3, p < 0.001, convex_down | mpg ~ wt: EDF 2.4, p < 0.001, convex_down
#>   mpg <-> hp  A = 0.01  hp ~ mpg: EDF 3.0, p < 0.001, s_shape | mpg ~ hp: EDF 3.0, p < 0.001, convex_down
#> Use summary() for the per-cell table and plot() for the matrix.
summary(fit)[, c("var_x", "var_y", "edf", "association_p",
                 "shape_category")]
#>   var_x var_y      edf association_p shape_category
#> 1    hp   mpg 3.011654  0.000000e+00    convex_down
#> 2    wt   mpg 2.400250  0.000000e+00    convex_down
#> 3   mpg    hp 3.048184  1.304169e-06        s_shape
#> 4    wt    hp 1.179943  1.087684e-04     concave_up
#> 5   mpg    wt 2.324136  0.000000e+00    convex_down
#> 6    hp    wt 3.086728  1.966037e-05     inverted_u
fit$pairs[[1L]]$asymmetry_index
#> [1] 0.006028176
```
