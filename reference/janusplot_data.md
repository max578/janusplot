# Deprecated: raw GAM fits and per-cell metrics

**\[deprecated\]**

`janusplot_data()` was renamed
[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
in janusplot 1.0.0 and forwards every argument to it. The result is the
`janusplot_fit` object described there: `pvalue_yx` and `pvalue_xy` are
now `association_p_yx` and `association_p_xy`, and first and second
derivatives are computed by default.

## Usage

``` r
janusplot_data(...)
```

## Arguments

- ...:

  Arguments passed on to
  [`janusplot_fit`](https://max578.github.io/janusplot/reference/janusplot_fit.md)

  `data`

  :   A data frame. Column names need not be syntactic; fits run under
      internal aliases and every result reports the original names.

  `vars`

  :   Character vector of numeric column names to fit, in matrix order.
      `NULL` (the default) takes every numeric column of `data`.
      Identical or exactly collinear columns are not fitted against each
      other; their cells are listed in `flags$failed`.

  `adjust`

  :   One-sided formula of covariates and random effects added to every
      pairwise model, for example `~ s(age) + s(site, bs = "re")`.
      `NULL` (the default) fits unadjusted smooths. Character and
      logical `adjust` columns are converted to factor before fitting.
      Random-effect smooths are excluded from prediction, so the curve
      and its band are population-level. With the identity link (the
      Gaussian default) the curve is the smooth averaged over the
      adjustment covariates of the data, and the plots draw each point
      as a partial residual: the observation with its own adjustment
      replaced by that average, so points and curve share one level
      (`style$adjusted_points`). With another link, numeric covariates
      are held at their mean and fixed factors at their most frequent
      level, and points stay raw.

  `k`

  :   Basis dimension for `s()`: a single integer, or a named list of
      integers keyed by variable name. `-1L` (the default) leaves the
      choice to mgcv. Each cell's basis is capped at the number of
      distinct predictor values in its rows, and an `auto_refit_k` refit
      stops one below that number; capped cells are listed in
      `flags$k_capped` and recorded as `k_requested`, `k_used` and
      `k_capped`.

  `bs`

  :   Basis type for `s()`; `"tp"` (thin plate) by default.

  `engine`

  :   `"bam"` (the default) fits with
      [`mgcv::bam()`](https://rdrr.io/pkg/mgcv/man/bam.html), `"gam"`
      with [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html). The
      two differ in their default `method` and by about one to three
      percent in EDF on the same data.

  `method`

  :   Smoothing-parameter estimation method passed to mgcv. `NULL` (the
      default) resolves to `"fREML"` for `engine = "bam"` and `"REML"`
      for `engine = "gam"`.

  `na_action`

  :   `"pairwise"` (the default) fits each cell on the rows complete for
      its own variables and the `adjust` columns; `"complete"` first
      drops every row with a missing value in any fitted or adjusting
      column. Infinite values count as missing and are reported in a
      warning. A pair sharing fewer than 5 complete rows is not fitted
      and is listed in `flags$sparse`; an error is raised only when no
      pair reaches 5 rows.

  `n_grid`

  :   Number of equally spaced points at which each smooth and its
      derivatives are evaluated, at least 10. `NULL` (the default)
      resolves to `200L` when `derivatives` is non-empty and `100L`
      otherwise.

  `derivatives`

  :   Integer vector of derivative orders to compute for every cell, a
      subset of `1:2`. The default `1:2` computes both;
      [`integer()`](https://rdrr.io/r/base/integer.html) computes none.

  `derivative_ci`

  :   The band stored with each derivative curve: `"pointwise"` (the
      default), `"none"` or `"simultaneous"`. Simultaneous bands use the
      Monte Carlo critical multiplier of Ruppert, Wand and
      Carroll (2003) as applied to GAMs by Simpson (2018).

  `derivative_ci_nsim`

  :   Number of Monte Carlo draws for `derivative_ci = "simultaneous"`;
      `1000L` by default and at least 100.

  `p_adjust`

  :   Multiplicity adjustment of the smooth F-test p-values across the
      `k(k - 1)` directed cells: `"none"` (the default), `"BH"` or
      `"holm"`, applied once with
      [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html). Raw
      and adjusted values are both kept.

  `shape_cutoffs`

  :   Named list of classification thresholds, from
      [`janusplot_shape_cutoffs()`](https://max578.github.io/janusplot/reference/janusplot_shape_cutoffs.md),
      mapping the shape indices to a `shape_category` label.

  `k_check_thresholds`

  :   Named list with entries `edf_ratio`, `k_index` and `p` for the
      basis-dimension diagnostic that follows
      [`mgcv::k.check()`](https://rdrr.io/pkg/mgcv/man/k.check.html).
      `NULL` (the default) uses `edf_ratio = 0.9`, `k_index = 1` and
      `p = 0.05`.

  `auto_refit_k`

  :   Logical. When `TRUE`, a cell flagged by the k-check is refitted
      with a doubled basis until the flag clears, the distinct-value cap
      is reached or `k_max_iter` doublings have run. The diagnostic is
      computed either way; the default is `FALSE`.

  `k_max_iter`

  :   Maximum number of doublings per cell when `auto_refit_k = TRUE`;
      `2L` by default.

  `discrete`

  :   Logical. Passes mgcv's covariate discretisation to
      [`mgcv::bam()`](https://rdrr.io/pkg/mgcv/man/bam.html); `FALSE` by
      default and ignored for `engine = "gam"`.

  `nthreads`

  :   Integer. Threads used inside each
      [`mgcv::bam()`](https://rdrr.io/pkg/mgcv/man/bam.html) fit; `1L`
      by default, which avoids oversubscription under `parallel = TRUE`.
      Ignored for `engine = "gam"`.

  `parallel`

  :   Logical. When `TRUE`, pairs are fitted with
      [`future.apply::future_mapply()`](https://future.apply.futureverse.org/reference/future_mapply.html)
      under the user's
      [`future::plan()`](https://future.futureverse.org/reference/plan.html);
      `FALSE` by default.

  `keep_fits`

  :   Logical. When `TRUE`, the mgcv model objects are kept in `$fits`
      and as `fit_yx` / `fit_xy` of every pair; `FALSE` (the default)
      keeps metrics and prediction grids only.

## Value

A `janusplot_fit` object; see
[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md).
Its `call` component records the `janusplot_data()` call as made.
