# Shape metrics for a fitted univariate smooth

**\[experimental\]**

Compute the continuous monotonicity and convexity indices, inflection
and turning-point counts, and rule-based shape category for a fitted
univariate smooth. Works on either a per-pair fit object returned from
the janusplot internal machinery or a freshly fitted
[`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) with a single
`s()` term.

Both indices are bounded in `[-1, 1]` and weighted by the empirical
density of the predictor:

- `monotonicity_index` (paper symbol `M`). Let `f` be the fitted smooth
  evaluated on a dense grid of `n_grid` equally-spaced points across the
  predictor range, `f'` its numerical first derivative, and `w` the
  empirical density of the predictor on the same grid with `sum(w) = 1`.
  Then `monotonicity_index = sum(w * f') / sum(w * |f'|) in [-1, 1]`.
  `+1` is strictly increasing, `-1` strictly decreasing, `0`
  non-monotone.

- `convexity_index` (paper symbol `C`). With `f''` the numerical second
  derivative on the same grid,
  `convexity_index = sum(w * f'') / sum(w * |f''|) in [-1, 1]`. `+1` is
  globally convex (bowl-up), `-1` globally concave (bowl-down), `0`
  inflection-dominated (S-curve, sine, flat).

Both indices are scale-invariant (replacing `y -> a*y + b` leaves them
unchanged) and density-weighted so they describe the smooth *where the
data actually live*, not extrapolated tails.

## Usage

``` r
janusplot_shape_metrics(
  fit,
  x_name = NULL,
  newdata = NULL,
  n_grid = 200L,
  cutoffs = janusplot_shape_cutoffs()
)
```

## Arguments

- fit:

  Either a list returned by a janusplot pair-fit helper (must contain
  `pred` and `raw`), or a fitted
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) with a single
  `s(x)` term.

- x_name:

  Character. Column name of the predictor when `fit` is a
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) object. Ignored
  for pair-fit lists.

- newdata:

  Optional data frame supplying the raw predictor values used for
  density weighting when `fit` is a
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) object. If
  `NULL`, the model frame is used.

- n_grid:

  Integer. Prediction grid length when `fit` is a
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) object. Default
  `200L`.

- cutoffs:

  Named list of classification thresholds; see
  [`janusplot_shape_cutoffs()`](https://max578.github.io/janusplot/reference/janusplot_shape_cutoffs.md).
  Default uses package defaults.

## Value

A named list with components:

- `monotonicity_index`:

  `M` in `[-1, 1]`. See Description.

- `convexity_index`:

  `C` in `[-1, 1]`. See Description.

- `n_turning_points`:

  Integer count of lobe-mass-weighted sign changes of `f'`. Equals the
  number of interior extrema.

- `n_inflections`:

  Integer count of lobe-mass-weighted sign changes of `f''`.

- `flat_range_ratio`:

  `range(f) / sd(y)` — small values indicate a degenerate flat smooth.

- `shape_category`:

  One of 24 labels from
  [`janusplot_shape_hierarchy()`](https://max578.github.io/janusplot/reference/janusplot_shape_hierarchy.md)
  dispatched on `(n_turning_points, n_inflections)` with
  `(monotonicity_index, convexity_index)` disambiguation for the
  monotone case.

## See also

[`janusplot_shape_cutoffs()`](https://max578.github.io/janusplot/reference/janusplot_shape_cutoffs.md),
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md),
[`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md).

## Examples

``` r
# On a fitted gam
set.seed(2026L)
n  <- 200L
x  <- stats::runif(n, 0, 10)
y  <- log1p(x) + stats::rnorm(n, sd = 0.3)
d  <- data.frame(x = x, y = y)
fit <- mgcv::gam(y ~ s(x), data = d, method = "REML")
janusplot_shape_metrics(fit, x_name = "x", newdata = d)
#> $monotonicity_index
#> [1] 1
#> 
#> $convexity_index
#> [1] -0.9342494
#> 
#> $n_turning_points
#> [1] 0
#> 
#> $n_inflections
#> [1] 0
#> 
#> $flat_range_ratio
#> [1] 3.161499
#> 
#> $shape_category
#> [1] "concave_up"
#> 
```
