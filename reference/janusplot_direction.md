# Test whether the residual-independence condition licenses a direction

**\[experimental\]**

[`janusplot_pair()`](https://max578.github.io/janusplot/reference/janusplot_pair.md)
draws a pair twice – `y ~ s(x)` on the left and `x ~ s(y)` on the right
– and the fit summarises the difference between the two directions as an
asymmetry index. That index is a *diagnostic*: it says the two
directions of fit are not interchangeable, not that either one is the
causal direction.

This function runs the test that turns the picture into a claim. Under
the additive-noise model `y = f(x) + e` with `e` independent of `x`, the
model holds in at most one direction for all but a small set of
exceptional joint distributions. So a direction is supported when

- the residuals of the fit in that direction are independent of the
  putative cause, **and**

- the residuals of the fit in the opposite direction are not.

Independence is assessed with the kernel (HSIC) permutation test in
[`kernR::hsic_test()`](https://max578.github.io/kernR/reference/hsic_test.html).
Anything other than the clean one-sided pattern – both directions
admitting an additive-noise model, neither doing so, or the known
non-identifiable linear-Gaussian case – returns `"undecided"`. The
smaller of the two p-values is never read as a direction.

## Usage

``` r
janusplot_direction(
  fit,
  x,
  y,
  alpha = 0.05,
  n_permutations = 500L,
  linear_tol = 0.01,
  gaussian_alpha = 0.01,
  seed = NULL,
  n_min = 30L,
  n_max = 2000L
)

# S3 method for class 'janusplot_direction'
print(x, ...)
```

## Arguments

- fit:

  A `janusplot_fit` object from
  [`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md).

- x:

  Character. Name of the first variable, one of `fit$vars` – the
  putative cause under the forward hypothesis. For
  [`print()`](https://rdrr.io/r/base/print.html), a
  `janusplot_direction` object.

- y:

  Character. Name of the second variable, one of `fit$vars` – the
  putative effect under the forward hypothesis. Names need not be
  syntactic: names with spaces or symbols are returned and reported as
  supplied.

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

- ...:

  Ignored.

## Value

A list of class `janusplot_direction`, printed as the verdict, its
reason, the two p-values and the rows used:

- `verdict`:

  One of `"forward"` (`x` drives `y`), `"reverse"` (`y` drives `x`), or
  `"undecided"`.

- `reason_code`:

  Machine-readable ground for the verdict: `"forward_only"`,
  `"reverse_only"`, `"both_independent"`, `"neither_independent"`,
  `"linear_gaussian"`, or `"n_below_min"`. For `"n_below_min"` the
  p-values, statistics, EDFs, curvatures and normality p-values are
  `NA`.

- `reason`:

  One-paragraph statement of the same ground.

- `x`, `y`:

  The variable names, as supplied.

- `forward`, `reverse`:

  The two hypotheses as printable strings, e.g. `"x -> y"`.

- `p_forward`, `p_reverse`:

  HSIC permutation p-values for residual-versus-cause independence in
  each direction.

- `statistic_forward`, `statistic_reverse`:

  The two observed HSIC statistics.

- `independent_forward`, `independent_reverse`:

  Whether each p-value exceeds `alpha`.

- `edf_forward`, `edf_reverse`:

  Effective degrees of freedom of each fitted smooth.

- `curvature_forward`, `curvature_reverse`:

  Departure of each smooth from a straight line; see Details.

- `normality_p`:

  Named numeric vector of the four Shapiro-Wilk p-values (`x`, `y`,
  `residuals_forward`, `residuals_reverse`).

- `linear_gaussian`:

  `TRUE` when the non-identifiable linear-Gaussian case was detected.

- `n`:

  Complete cases on `x` and `y`.

- `n_used`:

  Rows used for the fits and tests: `n`, or `n_max` when `n` exceeds it.

- `alpha`, `gaussian_alpha`, `linear_tol`, `n_permutations`, `n_min`,
  `n_max`:

  The settings the verdict was reached under.

- `method`:

  The [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html)
  smoothing-parameter method of the two direction fits.

[`print()`](https://rdrr.io/r/base/print.html) returns its argument
invisibly.

## Details

### What the fit supplies

The rows are those the pair was fitted on in `fit`: complete on `x`, `y`
and the `adjust` variables, so `n` equals the pair's `n_used`. Each
direction is fitted with the basis dimension that direction used in
`fit` (`k_used_yx` or `k_used_xy` of the pair) and the basis type
`fit$settings$bs`, so the verdict rests on the smooths the matrix draws.

Both directions are fitted with
[`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html). A fit made with
`engine = "gam"` passes its `method`; a fit made with `engine = "bam"`
carries a [`mgcv::bam()`](https://rdrr.io/pkg/mgcv/man/bam.html) method
(`"fREML"` by default), so the test uses the
[`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) default `"REML"`
instead. The method used is returned as `method`.

The test is bivariate. When `fit` was made with an `adjust` formula, the
adjust terms do not enter the two direction fits and a message says so;
only the rows they select carry over.

When `fit` keeps its models (`keep_fits = TRUE`), was made with
`engine = "gam"` and no `adjust` formula, and `n` does not exceed
`n_max`, the residuals, EDFs and fitted values of the two kept models
are used without refitting. The result is the same as a refit.

### The linear-Gaussian exception

Identifiability fails exactly when the relationship is linear and both
the cause and the noise are Gaussian: a bivariate Gaussian is reproduced
perfectly by a linear model with Gaussian noise in either direction, so
the residual-independence condition holds both ways and carries no
directional information. This case is detected before the two
independence tests are read, and returns `"undecided"` with
`reason_code = "linear_gaussian"`. It is flagged when *both* of the
following hold:

- **Linearity.** Each fitted smooth departs from a straight line by less
  than `linear_tol`, measured as `1 - cor(fitted, x)^2` – the share of
  the fitted variation that no straight line in the predictor can
  reproduce.

- **Gaussianity.** Shapiro-Wilk applied to `x`, `y`, and both residual
  vectors fails to reject normality at `gaussian_alpha` in all four
  cases.

`gaussian_alpha` defaults to `0.01`, not `0.05`: the consequence of the
flag is abstention, so the threshold is set to withhold a directional
claim unless the data argue clearly against Gaussianity.

### Reading the result

A `"forward"` or `"reverse"` verdict states that the condition licensing
that direction holds on this sample. It is not a proof of causation: the
additive-noise model assumes no unobserved common cause, no feedback,
and additive noise, and none of those assumptions is testable from the
pair alone.

## References

Hoyer, P. O., Janzing, D., Mooij, J. M., Peters, J., & Scholkopf, B.
(2009). Nonlinear causal discovery with additive noise models. *Advances
in Neural Information Processing Systems*, **21**, 689-696.

Gretton, A., Fukumizu, K., Teo, C. H., Song, L., Scholkopf, B., & Smola,
A. J. (2008). A kernel statistical test of independence. *Advances in
Neural Information Processing Systems*, **20**, 585-592.

Shimizu, S., Hoyer, P. O., Hyvarinen, A., & Kerminen, A. (2006). A
linear non-Gaussian acyclic model for causal discovery. *Journal of
Machine Learning Research*, **7**, 2003-2030.

## See also

[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
for the fit,
[`janusplot_pair()`](https://max578.github.io/janusplot/reference/janusplot_pair.md)
for the two directions drawn side by side.

Other smooth-associations:
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md),
[`janusplot_compare()`](https://max578.github.io/janusplot/reference/janusplot_compare.md),
[`janusplot_curves()`](https://max578.github.io/janusplot/reference/janusplot_curves.md),
[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md),
[`janusplot_pair()`](https://max578.github.io/janusplot/reference/janusplot_pair.md),
[`janusplot_reference()`](https://max578.github.io/janusplot/reference/janusplot_reference.md),
[`janusplot_style()`](https://max578.github.io/janusplot/reference/janusplot_style.md),
[`plot.janusplot_compare()`](https://max578.github.io/janusplot/reference/plot.janusplot_compare.md),
[`plot.janusplot_fit()`](https://max578.github.io/janusplot/reference/plot.janusplot_fit.md)

## Examples

``` r
if (requireNamespace("kernR", quietly = TRUE)) {
  # x drives y through a non-linear function with non-Gaussian noise:
  # the additive-noise model is identifiable here.
  set.seed(2026L)
  n <- 200L
  x <- stats::runif(n, -3, 3)
  y <- x^3 / 5 + stats::runif(n, -1, 1)
  fit <- janusplot_fit(data.frame(x = x, y = y), engine = "gam")

  res <- janusplot_direction(fit, "x", "y", n_permutations = 199L,
                             seed = 2026L)
  res
  c(forward = res$p_forward, reverse = res$p_reverse)

  # The same pair read the other way round names the other direction.
  janusplot_direction(fit, "y", "x", n_permutations = 199L,
                      seed = 2026L)$verdict
}
#> [1] "reverse"
```
