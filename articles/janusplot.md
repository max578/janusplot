# Asymmetric Smoothed-Association Matrices

## Why Pearson is not enough

A Pearson correlation matrix gives one scalar per pair of variables. Two
numbers are discarded in that collapse:

1.  The *shape* of the association — linear, monotone non-linear,
    U-shaped, or irregular.
2.  The *direction* — whether $y$ is a smooth function of $x$ differs in
    general from whether $x$ is a smooth function of $y$, because
    leverage and noise are directional.

[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
renders both recoveries visually for every pair in a matrix layout,
using proper [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html) fits
(not loess) so EDF, F-tests, and random effects are available.

## Quick start

``` r
library(janusplot)

# Four numeric columns from mtcars (32 rows: small but illustrative)
janusplot(mtcars[, c("mpg", "hp", "wt", "qsec")])
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/quickstart-1.png)

Each off-diagonal cell shows:

- raw scatter (light grey),
- the fitted spline (blue line) and 95% CI ribbon,
- EDF (effective degrees of freedom) in the bottom-right,
- *n* used in the bottom-left,
- a signif-glyph in the top-right (`***` / `**` / `*` / `·`).

The cell fill is keyed to EDF: darker = more non-linear.

## Non-linear detection

A synthetic quadratic + sinusoidal example. The matrix makes it obvious
which variables are genuinely non-linearly related to which.

``` r
n <- 300
x1 <- runif(n, -3, 3)
x2 <- x1^2 + rnorm(n, sd = 0.6)   # quadratic on x1
x3 <- sin(x1) + rnorm(n, sd = 0.4) # sinusoidal on x1
x4 <- rnorm(n)                     # independent
d  <- data.frame(x1 = x1, x2 = x2, x3 = x3, x4 = x4)

janusplot(d)
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/nonlinear-1.png)

EDF for `x2 ~ s(x1)` and `x3 ~ s(x1)` should clearly exceed 1; the cell
fills reflect that. Cells involving `x4` should be close to EDF = 1
(linear / flat).

## Asymmetry — a heteroscedastic example

When the noise scale depends on a predictor, the two directional smooths
diverge: $y \sim s(x)$ recovers the mean relationship; $x \sim s(y)$ is
distorted by the variance asymmetry.

``` r
n <- 400
x <- runif(n, 0, 5)
y <- 0.5 * x + rnorm(n, sd = 0.3 + 0.4 * x)   # variance grows with x
d <- data.frame(x = x, y = y, z = rnorm(n))

janusplot(d)
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/asym-1.png)

The `A = ...` label per cell reports the asymmetry index
$A_{ij} = \left| EDF_{y|x} - EDF_{x|y} \right|/\left( EDF_{y|x} + EDF_{x|y} \right) \in \lbrack 0,1\rbrack$,
shown by default in the bottom-left corner alongside `EDF = ...`.

## Partial smooths (controlling for covariates)

Pass `adjust =` as a one-sided formula RHS to include fixed covariates
and/or random effects in every pairwise GAM.

``` r
library(palmerpenguins)
#> 
#> Attaching package: 'palmerpenguins'
#> The following objects are masked from 'package:datasets':
#> 
#>     penguins, penguins_raw
pp <- na.omit(penguins)

# Without covariate
janusplot(pp[, c("bill_length_mm", "bill_depth_mm",
                 "flipper_length_mm", "body_mass_g")])
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/adjust-1.png)

``` r

# With species as a fixed effect — resolves Simpson's-paradox geometry
janusplot(pp, vars = c("bill_length_mm", "bill_depth_mm",
                       "flipper_length_mm", "body_mass_g"),
         adjust = ~ species)
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/adjust-2.png)

## Changing the palette

The cell fill encodes the EDF (or deviance-explained) of the smooth and
is accompanied by a shared colourbar legend. Choose a palette with
`palette =`.

``` r
d <- data.frame(
  x1 = runif(200, -3, 3),
  x2 = rnorm(200),
  x3 = rnorm(200)
)
d$x2 <- d$x1^2 + rnorm(200, sd = 0.8)  # non-linear

janusplot(d, palette = "viridis")  # default, colourblind-safe
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/palette-viridis-1.png)

``` r
janusplot(d, palette = "RdYlBu")   # diverging, colourblind-safe
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/palette-brewer-1.png)

``` r
janusplot(d, palette = "turbo")    # high-contrast, NOT colourblind-safe
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/palette-turbo-1.png)

**Colourblind-safe choices:**

- *Sequential:* `viridis` (default), `magma`, `inferno`, `plasma`,
  `cividis`, `mako`, `rocket`, `YlOrRd`, `YlGnBu`, `Blues`, `Greens`.
- *Diverging:* `RdYlBu`, `RdBu`, `PuOr`.

**High-contrast but not colourblind-safe:** `turbo`, `Spectral`.

## Handling missing data

``` r
# airquality has genuine NAs in Ozone and Solar.R
janusplot(airquality[, c("Ozone", "Solar.R", "Wind", "Temp")],
          na_action = "pairwise")
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/missing-1.png)

`na_action = "pairwise"` uses all rows for which *that* pair is
complete; `"complete"` restricts to rows complete across every variable
(matching listwise deletion).

## Scaling up — `order = "hclust"`

For k large, reorder the axes by hierarchical clustering on
\|correlation\|:

``` r
data(Boston, package = "MASS")
janusplot(Boston[, c("medv", "lstat", "rm", "age",
                     "indus", "nox", "dis")],
          order = "hclust")
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/hclust-1.png)

## Programmatic access — `janusplot_data()`

Returns raw GAM fits and per-cell metrics without constructing a ggplot
— useful for custom rendering or downstream analysis.

``` r
# Re-create the heteroscedastic example
n <- 400
het <- data.frame(
  x = runif(n, 0, 5),
  y = NA_real_
)
het$y <- 0.5 * het$x + rnorm(n, sd = 0.3 + 0.4 * het$x)

out <- janusplot_data(het, vars = c("x", "y"))
out$pairs[[1L]]$edf_yx
#> [1] 1.00021
out$pairs[[1L]]$edf_xy
#> [1] 6.157621
out$pairs[[1L]]$asymmetry_index
#> [1] 0.720527
```

## Shape metrics explained

Every fitted smooth is summarised by two continuous indices and two
discrete counts. These drive the 24-category classifier and appear as
columns in `janusplot(..., with_data = TRUE)$data` and as fields on each
entry of `janusplot_data()$pairs`.

Let `f(x)` be the fitted smooth on a dense grid of 200 equally-spaced
points across the predictor range, with `f'` and `f''` the numerical
first and second derivatives. Let `w(x)` be the empirical density of the
predictor on the same grid, normalised to `sum(w) = 1`.

- **`monotonicity_index`** (paper symbol `M`):

  `M = sum(w * f') / sum(w * |f'|) in [-1, 1]`

  `+1` means strictly increasing, `-1` strictly decreasing, `0` a
  non-monotone curve (bowl, dome, wave).

- **`convexity_index`** (paper symbol `C`):

  `C = sum(w * f'') / sum(w * |f''|) in [-1, 1]`

  `+1` means globally convex (bowl-up), `-1` globally concave
  (bowl-down), `0` inflection-dominated (S-curve, sine, flat).

Both indices are density-weighted so they describe the smooth *where the
data actually live*, not extrapolated tails, and are scale-invariant:
replacing `y` with `a * y + b` leaves them unchanged.

- **`n_turning_points`** — count of interior extrema (sign changes of
  `f'`), robust to noise via lobe-mass weighting.
- **`n_inflections`** — count of interior curvature flips (sign changes
  of `f''`), same robust counting.

Together the pair `(n_turning_points, n_inflections)` drives the primary
`shape_category` dispatch; `(monotonicity_index, convexity_index)`
disambiguate within the monotone `(0, 0)` and single-extremum `(1, 0)`
cells. The full taxonomy with 2-letter codes, archetypes, and thumbnail
curves is available from
[`janusplot_shape_hierarchy()`](https://max578.github.io/janusplot/reference/janusplot_shape_hierarchy.md)
and is rendered as the standing legend below every
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
call.

Tune the thresholds applied to these indices via
[`janusplot_shape_cutoffs()`](https://max578.github.io/janusplot/reference/janusplot_shape_cutoffs.md).
See the
[shape-recognition-sensitivity](https://max578.github.io/janusplot/articles/shape-recognition-sensitivity.md)
vignette for how faithfully the classifier recovers ground-truth shapes
across sample-size and noise regimes.

## Limitations

- Pairwise view, not conditional — always complement with a proper
  multivariate model.
- EDF depends on basis dimension `k`; defaults are sensible but
  domain-specific tuning is encouraged.
- The asymmetry index should not be interpreted causally without strong
  assumptions.
- `monotonicity_index` and `convexity_index` are scale-invariant in `y`
  but sensitive to the predictor-density weighting — they describe the
  smooth on the observed support of `x`, not outside it.

## Citation

``` r
citation("janusplot")
#> To cite janusplot in publications use:
#> 
#>   Moldovan M (2026). _janusplot: Asymmetric Smoothed-Association
#>   Matrices via GAM Fits_. R package version 0.0.0.9000,
#>   <https://github.com/max578/janusplot>.
#> 
#>   Moldovan M (2026). "Beyond Pearson: Visualising Asymmetric Non-linear
#>   Associations with Generalised Additive Models." _The R Journal_. In
#>   preparation.
#> 
#> To see these entries in BibTeX format, use 'print(<citation>,
#> bibtex=TRUE)', 'toBibtex(.)', or set
#> 'options(citation.bibtex.max=999)'.
```
