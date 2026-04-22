# Shape-recognition sensitivity study

**\[experimental\]**

Run a full-factorial sensitivity sweep for the janusplot 24-category
shape classifier. For each combination of ground-truth shape, sample
size `n`, noise level `sigma`, and replicate, the sweep:

1.  Generates `n` points from the noiseless canonical curve on
    `[0, 1]` + Gaussian noise with SD = `sigma` (fraction of the
    y-range, so signal-to-noise is comparable across shapes).

2.  Fits `mgcv::gam(y ~ s(x), method = "REML")`.

3.  Runs
    [`janusplot_shape_metrics()`](https://max578.github.io/janusplot/reference/janusplot_shape_metrics.md)
    to classify the fitted smooth.

4.  Records correctness at both the fine (24-category) and archetype
    (7-family) levels.

The function is the package-native implementation of
`simulation/scripts/scenario_4_shape_recognition.R`. A small precomputed
dataset is shipped as
[shape_sensitivity_demo](https://max578.github.io/janusplot/reference/shape_sensitivity_demo.md)
for downstream examples without requiring users to re-run the sweep.

## Usage

``` r
janusplot_shape_sensitivity(
  shapes = NULL,
  n_grid = c(50L, 100L, 200L, 500L),
  sigma_grid = c(0.02, 0.05, 0.1, 0.2, 0.4),
  n_rep = 200L,
  cutoffs = janusplot_shape_cutoffs(),
  parallel = FALSE,
  seed = 2026L,
  verbose = interactive()
)
```

## Arguments

- shapes:

  Character vector of ground-truth names from
  [`janusplot_shape_sensitivity_shapes()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_shapes.md).
  Default `NULL` → all 14.

- n_grid:

  Integer vector of sample sizes. Default `c(50L, 100L, 200L, 500L)`.

- sigma_grid:

  Numeric vector of noise levels (fraction of the y-range). Default
  `c(0.02, 0.05, 0.10, 0.20, 0.40)`.

- n_rep:

  Integer. Replicates per cell. Default `200L`.

- cutoffs:

  Named list of classification thresholds; see
  [`janusplot_shape_cutoffs()`](https://max578.github.io/janusplot/reference/janusplot_shape_cutoffs.md).

- parallel:

  Logical. If `TRUE` and `future.apply` is installed, dispatch
  replicates in parallel. The caller is responsible for configuring
  [`future::plan()`](https://future.futureverse.org/reference/plan.html)
  (e.g. `future::plan(future::multisession)`).

- seed:

  Integer. Base seed — each fit uses `seed + row_index` so results are
  reproducible and cell-permutation-invariant.

- verbose:

  Logical. Print progress messages to the console. Default is
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

## Value

A data frame with one row per fit. Columns:

- `truth`:

  Ground-truth shape name.

- `n`:

  Sample size for this fit.

- `sigma`:

  Noise level for this fit.

- `seed`:

  RNG seed used.

- `predicted`:

  Classifier output at the fine (24-category) level.

- `correct`:

  Logical — does `predicted == truth`?

- `archetype_truth`:

  Expected archetype for `truth`.

- `archetype_pred`:

  Archetype of `predicted`.

- `archetype_correct`:

  Logical — archetype-level correctness.

- `monotonicity_index`:

  Monotonicity index `M` (see
  [`janusplot_shape_metrics()`](https://max578.github.io/janusplot/reference/janusplot_shape_metrics.md)).

- `convexity_index`:

  Convexity index `C` (see
  [`janusplot_shape_metrics()`](https://max578.github.io/janusplot/reference/janusplot_shape_metrics.md)).

- `n_turn`, `n_inflect`:

  Recovered turning-point and inflection counts.

- `error`:

  `"gam_fit_failed"` when
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) errored; `NA`
  otherwise.

## See also

[`janusplot_shape_sensitivity_summary()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_summary.md),
[`janusplot_shape_sensitivity_plot()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_plot.md),
[`janusplot_shape_sensitivity_shapes()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_shapes.md),
[shape_sensitivity_demo](https://max578.github.io/janusplot/reference/shape_sensitivity_demo.md).

## Examples

``` r
# Tiny-run smoke test (< 2 seconds): 3 shapes x 2 n x 2 sigma x 5 reps.
res <- janusplot_shape_sensitivity(
  shapes     = c("linear_up", "u_shape", "wave"),
  n_grid     = c(100L, 200L),
  sigma_grid = c(0.05, 0.20),
  n_rep      = 5L,
  verbose    = FALSE
)
head(res)
#>       truth   n sigma seed  predicted correct archetype_truth  archetype_pred
#> 1 linear_up 100  0.05 2027  linear_up    TRUE monotone_linear monotone_linear
#> 2   u_shape 100  0.05 2028    u_shape    TRUE        unimodal        unimodal
#> 3      wave 100  0.05 2029 broad_peak   FALSE            wave        unimodal
#> 4 linear_up 200  0.05 2030  linear_up    TRUE monotone_linear monotone_linear
#> 5   u_shape 200  0.05 2031    u_shape    TRUE        unimodal        unimodal
#> 6      wave 200  0.05 2032 broad_peak   FALSE            wave        unimodal
#>   archetype_correct monotonicity_index convexity_index n_turn n_inflect error
#> 1              TRUE         1.00000000       0.0000000      0         0  <NA>
#> 2              TRUE         0.02660353       0.9768746      1         0  <NA>
#> 3             FALSE        -0.10849908      -0.2416725      1         2  <NA>
#> 4              TRUE         1.00000000       0.0000000      0         0  <NA>
#> 5              TRUE         0.06946110       0.9999646      1         0  <NA>
#> 6             FALSE        -0.07133879      -0.2442866      1         2  <NA>
janusplot_shape_sensitivity_summary(res, level = "archetype")
#>        truth   n sigma accuracy
#> 1  linear_up 100  0.05      0.8
#> 2    u_shape 100  0.05      1.0
#> 3       wave 100  0.05      0.0
#> 4  linear_up 200  0.05      0.8
#> 5    u_shape 200  0.05      1.0
#> 6       wave 200  0.05      0.0
#> 7  linear_up 100  0.20      0.6
#> 8    u_shape 100  0.20      1.0
#> 9       wave 100  0.20      0.0
#> 10 linear_up 200  0.20      0.8
#> 11   u_shape 200  0.20      1.0
#> 12      wave 200  0.20      0.0
```
