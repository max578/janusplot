# Test whether the residual-independence condition licenses a direction

**\[experimental\]**

[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
renders a pair twice – `y ~ s(x)` in one triangle and `x ~ s(y)` in the
other – and summarises the difference between the two fits as an
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
[`kernR::hsic_test()`](https://rdrr.io/pkg/kernR/man/hsic_test.html).
Anything other than the clean one-sided pattern – both directions
admitting an additive-noise model, neither doing so, or the known
non-identifiable linear-Gaussian case – returns `"undecided"`. The
smaller of the two p-values is never read as a direction.

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
  seed = NULL
)
```

## Arguments

- data:

  A data frame containing both variables.

- x:

  Character. Column name of the first variable – the putative cause
  under the forward hypothesis.

- y:

  Character. Column name of the second variable – the putative effect
  under the forward hypothesis.

- k:

  Basis dimension passed to
  [`mgcv::s()`](https://rdrr.io/pkg/mgcv/man/s.html). Default `-1L` lets
  `mgcv` choose.

- bs:

  Character. Spline basis passed to
  [`mgcv::s()`](https://rdrr.io/pkg/mgcv/man/s.html). Default `"tp"`
  (thin-plate regression spline).

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
  not drawn from the same permutation sequence.

## Value

A named list:

- `verdict`:

  One of `"forward"` (`x` drives `y`), `"reverse"` (`y` drives `x`), or
  `"undecided"`.

- `reason_code`:

  Machine-readable ground for the verdict: `"forward_only"`,
  `"reverse_only"`, `"both_independent"`, `"neither_independent"`, or
  `"linear_gaussian"`.

- `reason`:

  One-paragraph statement of the same ground.

- `x`, `y`:

  The column names, as supplied.

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

  Complete cases used.

- `alpha`, `gaussian_alpha`, `linear_tol`, `n_permutations`:

  The settings the verdict was reached under.

## Details

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

[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md),
[`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md).

## Examples

``` r
if (requireNamespace("kernR", quietly = TRUE)) {
  # x drives y through a non-linear function with non-Gaussian noise:
  # the additive-noise model is identifiable here.
  set.seed(2026L)
  n <- 200L
  x <- stats::runif(n, -3, 3)
  y <- x^3 / 5 + stats::runif(n, -1, 1)
  d <- data.frame(x = x, y = y)

  res <- janusplot_direction_test(d, "x", "y", n_permutations = 199L,
                                  seed = 1L)
  res$verdict      # "forward"
  res$reason
  c(forward = res$p_forward, reverse = res$p_reverse)

  # The same pair read the other way round returns "reverse".
  janusplot_direction_test(d, "y", "x", n_permutations = 199L,
                           seed = 1L)$verdict
}
#> [1] "reverse"
```
