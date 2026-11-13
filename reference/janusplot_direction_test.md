# Deprecated: residual-independence direction test on a data frame

**\[deprecated\]**

`janusplot_direction_test()` was replaced by
[`janusplot_direction()`](https://max578.github.io/janusplot/reference/janusplot_direction.md)
in janusplot 1.0.0, which takes the rows, basis dimension and method
from a
[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
object. This alias runs the same test on the complete cases of two
columns of `data` for one more release.

## Usage

``` r
janusplot_direction_test(
  data,
  x,
  y,
  k = -1L,
  bs = "tp",
  method = NULL,
  alpha = 0.05,
  n_permutations = 500L,
  linear_tol = 0.01,
  gaussian_alpha = 0.01,
  seed = NULL,
  n_min = 30L,
  n_max = 2000L
)
```

## Arguments

- data:

  A data frame containing both variables.

- x:

  Character. Column name of the putative cause under the forward
  hypothesis.

- y:

  Character. Column name of the putative effect under the forward
  hypothesis.

- k:

  Basis dimension passed to
  [`mgcv::s()`](https://rdrr.io/pkg/mgcv/man/s.html). Default `-1L` lets
  mgcv choose.

- bs:

  Character. Spline basis passed to
  [`mgcv::s()`](https://rdrr.io/pkg/mgcv/man/s.html). Default `"tp"`.

- method:

  Smoothing-parameter selection method passed to
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html). `NULL`
  (default) uses `"REML"`.

- alpha:

  Numeric in `(0, 1)`. Significance level for the two
  residual-independence tests. Residuals are called independent when the
  HSIC p-value exceeds `alpha`. Default `0.05`.

- n_permutations:

  Integer. Permutations used to build each HSIC null distribution. Must
  be at least `99` – the smallest attainable p-value is
  `1 / (n_permutations + 1)`. Default `500L`.

- linear_tol:

  Numeric in `(0, 1)`. A fitted smooth counts as a straight line when
  `1 - cor(fitted, x)^2` falls below this value. Default `0.01`.

- gaussian_alpha:

  Numeric in `(0, 1)`. Significance level for the four Shapiro-Wilk
  normality tests used by the linear-Gaussian detector. Default `0.01`.

- seed:

  Integer or `NULL`. Seed for the HSIC permutation draws. The reverse
  direction is seeded at `seed + 1` so the two null distributions are
  not drawn from the same permutation sequence. Also seeds the row
  subsample taken when the complete cases exceed `n_max`; with
  `seed = NULL` that subsample uses seed `2026`, so it is reproducible
  in both cases. The subsample does not change the global random-number
  state.

- n_min:

  Integer. Smallest number of complete cases on which a verdict is
  given. Below it the function returns `"undecided"` with
  `reason_code = "n_below_min"` and `reason = "n below n_min"`, without
  fitting or testing. Default `30L`. Samples below 20 complete cases are
  refused with an error whatever `n_min` is.

- n_max:

  Integer. Largest number of rows used for the fits and the HSIC tests,
  which build `n` by `n` kernel matrices. Above it a random subsample of
  `n_max` rows is drawn (see `seed`). Default `2000L`. The HSIC verdict
  depends on `n`: with more rows the test detects smaller departures
  from independence, so verdicts at different `n` are not directly
  comparable.

## Value

A `janusplot_direction` object; see
[`janusplot_direction()`](https://max578.github.io/janusplot/reference/janusplot_direction.md).
