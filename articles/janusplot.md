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

## Derivative views: theoretical justification and applied use

Each matrix renders one quantity. `display = "fit"` (default) shows the
fitted smooth; `display = "d1"` shows ; `display = "d2"` shows . A
top-of-matrix title names the mode, so side-by-side calls compare
unambiguously. Orders beyond two are not exposed — see *Noise
amplification* below. Derivative CI rendering is **off by default**; opt
in with `derivative_ci = "pointwise"` or `"simultaneous"`.

``` r
set.seed(2026L)
n  <- 300L
xs <- runif(n, -pi, pi)
df <- data.frame(
  x  = xs,
  y1 = xs + sin(3 * xs) + rnorm(n, sd = 0.15),
  y2 = 0.5 * xs^2       + rnorm(n, sd = 0.8)
)
janusplot(df, display = "fit", show_shape_legend = FALSE)
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/derivs-fit-1.png)

``` r
janusplot(df, display = "d1", show_shape_legend = FALSE)
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/derivs-d1-1.png)

``` r
janusplot(df, display = "d2", show_shape_legend = FALSE)
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/derivs-d2-1.png)

Turn on simultaneous bands — a single call gets the Monte Carlo critical
multiplier per Simpson (2018):

``` r
janusplot(df, display = "d1",
          derivative_ci = "simultaneous",
          derivative_ci_nsim = 2000L,
          show_shape_legend = FALSE)
```

![Asymmetric smoothed-association matrix produced by janusplot();
diagonal cells hold variable labels, off-diagonal cells show the fitted
mgcv::gam spline with a 95% confidence envelope, raw-data scatter, and
per-cell annotations for n, EDF, and smooth significance
glyph.](janusplot_files/figure-html/derivs-sim-1.png)

### What derivatives reveal that the fit hides

The fitted smooth $\widehat{f}(x) = {\mathbb{E}}\lbrack y \mid x\rbrack$
is a level description. Its derivatives are different statistical
objects with their own interpretations:

- $\widehat{f}\prime(x)$ — the **local rate of change** of $y$ in $x$.
  Zero crossings localise the turning points of $\widehat{f}$; the sign
  of $\widehat{f}\prime$ gives the direction of monotonicity; the
  magnitude gives the sensitivity at the operating point $x$. In control
  engineering this is literally the process gain
  $K(x) = \partial y/\partial u$ that gain-scheduled controllers are
  built around (Rugh & Shamma, 2000; Leith & Leithead, 2000). In causal
  analysis of a continuous treatment it is the derivative of the
  dose–response curve
  $\mu\prime(t) = \partial{\mathbb{E}}\left\lbrack Y(t) \right\rbrack/\partial t$,
  which Zhang & Chen (2025) argue is often *the* treatment-effect object
  of interest, not the curve itself.
- $\widehat{f}''(x)$ — the **local curvature**. Zero crossings localise
  the inflection points of $\widehat{f}$; a persistently positive second
  derivative flags accelerating growth, persistently negative flags
  saturation (diminishing returns). $\widehat{f}''$ is the input to the
  convexity index $C$ defined earlier in this vignette, so the
  derivative panel exposes the *local* signal behind that scalar
  summary.

The asymmetric matrix layout sharpens this.
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
fits both ${\widehat{f}}_{y \mid x}(x)$ and
${\widehat{f}}_{x \mid y}(y)$, so derivative panels on the two triangles
answer genuinely different questions: the upper triangle is “how steeply
does $y$ respond to a nudge in $x$ at this operating point” (forward
gain); the lower triangle is “how steeply must $x$ change to induce a
unit change in $y$” (inverse sensitivity). For an asymmetric process
these do not transpose into each other, and the directional asymmetry is
a diagnostic the symmetric correlation matrix cannot expose (Janzing &
Schölkopf, 2010).

### Estimation — the LP matrix

Let $X_{p} = X_{p}\left( \mathbf{x}_{g} \right)$ denote the design
(linear predictor) matrix of the fitted GAM evaluated on the plotting
grid $\mathbf{x}_{g}$, obtained from
`predict(gam_fit, newdata = ..., type = "lpmatrix")` (Wood, 2017,
§7.2.4). With penalised posterior mean
$\widehat{\mathbf{β}} = {\mathtt{c}\mathtt{o}\mathtt{e}\mathtt{f}\left( \mathtt{g}\mathtt{a}\mathtt{m}\mathtt{\_}\mathtt{f}\mathtt{i}\mathtt{t} \right)}$
and posterior covariance
$V_{p} = {\mathtt{g}\mathtt{a}\mathtt{m}\mathtt{\_}\mathtt{f}\mathtt{i}\mathtt{t}\mathtt{\$}\mathtt{V}\mathtt{p}}$,
we construct a finite-difference operator $D^{(k)}$ on the *rows* of
$X_{p}$ (central differences in the interior, second-order forward /
backward stencils at the endpoints) and read off

$${\widehat{f}}^{(k)}\left( x_{i} \right) = \lbrack D^{(k)}\widehat{\mathbf{β}}\rbrack_{i},\qquad\widehat{Var}({\widehat{f}}^{(k)}\left( x_{i} \right)) = \lbrack D^{(k)}V_{p}(D^{(k)})^{\!\top}\rbrack_{ii}.$$

Pointwise $95\%$ intervals are
${\widehat{f}}^{(k)}(x) \pm 1.96\,\sqrt{\cdot}$. This is the standard
Wood (2017) construction, and is what `gratia::derivatives()` implements
in its default mode (Simpson, 2014; Simpson, 2018). Columns of $X_{p}$
corresponding to `adjust` terms held at typical values contribute
identical rows across the grid, so their finite differences are zero and
they drop out of both ${\widehat{f}}^{(k)}$ and its variance — the
derivative in the panel is therefore the derivative of the *partial
smooth actually shown in the fit panel*, as expected.

For simultaneous intervals over the full grid (a stricter question than
pointwise, and what you want for formal feature localisation),
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
implements the Monte Carlo construction of Ruppert, Wand & Carroll
(2003, §6.5), popularised for GAMs by Simpson (2018): draw
${\widetilde{\mathbf{β}}}_{b} \sim \mathcal{N}\left( \widehat{\mathbf{β}},V_{p} \right)$
for $b = 1,\ldots,B$ and take the $(1 - \alpha)$ quantile of
$\max_{i}\left| D_{i}^{(k)}\left( {\widetilde{\mathbf{β}}}_{b} - \widehat{\mathbf{β}} \right) \right|/{\mathtt{s}\mathtt{e}}_{i}$
across the plotting grid as a critical multiplier $c_{\alpha}$ on the
pointwise SE, so the simultaneous band is
${\widehat{f}}^{(k)}(x) \pm c_{\alpha}\,{\mathtt{s}\mathtt{e}}(x)$. Opt
in via `derivative_ci = "simultaneous"` on either
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
or
[`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md);
the default is `derivative_ci = "none"` so that no CI is drawn by
default — derivative ribbons invite over-reading of local features and
should be a deliberate choice, not a default. The implementation uses
$B = 1000$ (see `derivative_ci_nsim`); Simpson (2018) uses $10\, 000$,
which is affordable if you need tighter quantile estimation.

### Noise amplification and why we cap at $k = 2$

Finite differencing of raw data amplifies noise; penalised splines do
not eliminate that amplification, they trade it against bias via the
REML-selected smoothing parameter. `mgcv`’s default thin-plate penalty
is on $\int(f'')^{2}$, which directly regularises $\widehat{f}\prime$
and bounds (but does not penalise) $\widehat{f}''$ only via the basis
rank (Wood, 2017, §5.3; Eilers & Marx, 1996). In practice we find
${\widehat{f}}^{(3)}$ is dominated by noise for $n < 10^{4}$ at moderate
$k$, and so janusplot refuses $k \geq 3$ by design. If you have a
domain-specific reason to need a higher-order derivative, specify a
matching-order P-spline penalty explicitly (Eilers, Marx & Durbán, 2015)
and extract it yourself from
[`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md).

### Applied use: gain estimation and dose–response

Two strands in which the asymmetric derivative view is not a cosmetic
add-on but the analytical primitive the practitioner actually wants.

- **Process-gain scheduling.** In adaptive and gain-scheduled control,
  the controller is indexed by the local process gain
  $K(x) = \partial y/\partial u$ (Rugh & Shamma, 2000). For a
  steady-state input-output dataset, ${\widehat{f}}_{y \mid u}\prime(u)$
  is a direct data-driven estimate of $K(u)$, and its simultaneous CI
  tells the engineer whether the local gain is distinguishable from a
  reference gain over an operating envelope. The inverse panel
  ${\widehat{f}}_{u \mid y}\prime(y)$ is the feedforward-linearisation
  sensitivity; a large divergence between the two panels flags that a
  naive inverse controller will under-perform (Korda & Mezić, 2018). The
  matrix view makes a fleet of such pairs inspectable at once.
- **Derivative of the dose–response curve as the causal estimand.** For
  a continuous treatment $T$ with unconfoundedness, the dose–response
  $\mu(t) = {\mathbb{E}}\left\lbrack Y(t) \right\rbrack$ and its
  derivative $\mu\prime(t)$ are both estimable, and recent work (Zhang &
  Chen, 2025) argues $\mu\prime(t)$ is often the more directly
  interpretable quantity — it answers “how much does the expected
  outcome change per unit shift in treatment at this dose?” This is
  structurally the same estimand as the process gain above; the
  asymmetric-matrix derivative panel delivers both forward and
  reverse-conditioned derivative curves in the same frame, which is a
  direct diagnostic for Simpson’s-paradox-style conditioning reversals
  (visible, for example, in the penguins `bill_depth_mm`
  $\times$`body_mass_g` pair once `species` is adjusted for).

### References cited in this section

Eilers, P. H. C., & Marx, B. D. (1996). Flexible smoothing with
B-splines and penalties. *Statistical Science*, **11**(2), 89–121.
<https://doi.org/10.1214/ss/1038425655>

Eilers, P. H. C., Marx, B. D., & Durbán, M. (2015). Twenty years of
P-splines. *SORT*, **39**(2), 149–186.

Janzing, D., & Schölkopf, B. (2010). Causal inference using the
algorithmic Markov condition. *IEEE Transactions on Information Theory*,
**56**(10), 5168–5194. <https://doi.org/10.1109/TIT.2010.2060095>

Korda, M., & Mezić, I. (2018). Linear predictors for nonlinear dynamical
systems: Koopman operator meets model predictive control. *Automatica*,
**93**, 149–160. <https://doi.org/10.1016/j.automatica.2018.03.046>

Leith, D. J., & Leithead, W. E. (2000). Survey of gain-scheduling
analysis and design. *International Journal of Control*, **73**(11),
1001–1025. <https://doi.org/10.1080/002071700411304>

Rugh, W. J., & Shamma, J. S. (2000). Research on gain scheduling.
*Automatica*, **36**(10), 1401–1425.
<https://doi.org/10.1016/S0005-1098(00)00058-3>

Ruppert, D., Wand, M. P., & Carroll, R. J. (2003). *Semiparametric
Regression*. Cambridge University Press.

Simpson, G. L. (2014). Simultaneous confidence intervals for derivatives
of smooth terms in a GAM. *From the Bottom of the Heap* (blog post).

Simpson, G. L. (2018). Modelling palaeoecological time series using
generalised additive models. *Frontiers in Ecology and Evolution*,
**6**, 149. <https://doi.org/10.3389/fevo.2018.00149>

Wood, S. N. (2017). *Generalized Additive Models: An Introduction with
R* (2nd ed.). Chapman and Hall/CRC.
<https://doi.org/10.1201/9781315370279>

Zhang, Y., & Chen, Y.-C. (2025). Doubly robust inference on causal
derivative effects for continuous treatments. arXiv preprint
\[2501.06969\].

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
- `display` is scalar — a single
  [`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
  call renders a single quantity (fit, d1, or d2). To compare fit
  against derivative, issue two or three calls; each carries its own
  matrix-level title and, when `with_data = TRUE`, its own
  `display`-tagged summary table.
- Derivative panels show **no confidence ribbon by default**
  (`derivative_ci = "none"`). Opt in explicitly: `"pointwise"` for
  marginally-valid pointwise 95% bands, `"simultaneous"` for
  Simpson (2018) Monte Carlo bands valid for feature localisation.
- Requesting `display %in% c("d1", "d2")` raises the default
  prediction-grid resolution from 100 to 200 points, which slightly
  shifts the numeric shape-metric values (`M`, `C`, turning and
  inflection counts) reported alongside the fit. Shapes and asymmetry —
  the primary reading of the matrix — are robust to this drift; `M`, `C`
  and the counts are secondary diagnostics. The precomputed
  `shape_sensitivity_demo` dataset was generated under `n_grid = 100`
  and is preserved as-is for reproducibility.

## Citation

``` r
citation("janusplot")
#> To cite janusplot in publications use:
#> 
#>   Moldovan M (2026). _janusplot: Asymmetric Smoothed-Association
#>   Matrices via GAM Fits_. R package version 0.0.0.9001,
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
