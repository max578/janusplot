# janusplot

Asymmetric, GAM-based smoothed-association matrices for continuous
variables. Each off-diagonal cell shows a directional
`mgcv::gam(y ~ s(x))` fit, so the upper and lower triangles tell
different stories whenever the relationship is genuinely asymmetric —
precisely where a scalar Pearson correlation loses information.

Two novelties, paired with the asymmetry story:

1.  **Asymmetry index**
    `A = |EDF_yx − EDF_xy| / (EDF_yx + EDF_xy) ∈ [0, 1]` — a
    single-number summary of the directional disparity per pair.
2.  **24-category shape taxonomy** — each fitted smooth is classified
    into one of 24 named shapes (`linear_up`, `skewed_peak`, `bimodal`,
    `bi_wave`, `rippled_monotone`, …) via a `(T, I)` dispatch on
    turning-point and inflection counts, with monotonicity/convexity
    indices for disambiguation. The taxonomy rolls up through three
    broader tiers: `archetype` (7), `monotonic` (3), `linear` (2) —
    grounded in shape-constrained regression (Pya & Wood 2015),
    dose-response pharmacology (Calabrese 2008), and Morse critical-
    point classification (Milnor 1963).

## Install

``` r
# development version from GitHub
pak::pak("max578/janusplot")

# or, with vignettes built locally (recommended):
pak::pak("max578/janusplot", dependencies = TRUE)
```

## Quick start

``` r
library(janusplot)

# Palmer penguins — four continuous traits
d <- na.omit(palmerpenguins::penguins[,
       c("bill_length_mm", "bill_depth_mm",
         "flipper_length_mm", "body_mass_g")])
janusplot(d)
```

Default encoding:

- **Cell colour** — Pearson correlation on a diverging `RdBu` palette
  symmetric around zero (override via `colour_by = "spearman"` /
  `"kendall"` / `"edf"` / `"deviance_gap"` / `"none"`).
- **Bottom-left** — `A = ...` (asymmetry index) stacked over
  `EDF = ...`.
- **Top-right** — significance glyph for the smooth’s F-test
  (`· * ** ***`).
- **Below the matrix** — a standing reference legend illustrating all 24
  shape categories as canonical thumbnail splines, labelled
  `<name> (<code>)`.

Opt into a per-cell shape marker via `annotations`:

``` r
# Two-letter shape code, top-left (ASCII — safe on any font / PDF):
janusplot(d, annotations = c("edf", "A", "code"))

# Unicode shape glyph, bottom-right:
janusplot(d, annotations = c("edf", "A", "shape"),
          glyph_style = "unicode")
```

## Shape taxonomy — what gets classified

| Archetype (7)     | Categories                                                                         | Example                          |
|-------------------|------------------------------------------------------------------------------------|----------------------------------|
| `monotone_linear` | `linear_up` `linear_down`                                                          | `y = x`                          |
| `monotone_curved` | `convex_up` `concave_up` `convex_down` `concave_down` `s_shape` `rippled_monotone` | `tanh`, `sqrt`, `exp(−x)`        |
| `unimodal`        | `u_shape` `inverted_u` `skewed_peak` `broad_peak` `rippled_peak`                   | `(x−.5)²`, `x·exp(−3x)`, plateau |
| `wave`            | `wave` `warped_wave` `rippled_wave` `complex_wave`                                 | `sin(2πx)` family                |
| `multimodal`      | `bimodal` `bimodal_ripple` `bi_wave` `bi_wave_ripple`                              | two-peak mix, `sin(4πx)`         |
| `chaotic`         | `complex`                                                                          | ≥ 5 extrema / inflections        |
| `degenerate`      | `flat` `indeterminate`                                                             | constant / fit failure           |

Full table (with 2-letter codes + monotonic / linear rollups + glyph +
gloss) via
[`janusplot_shape_hierarchy()`](https://max578.github.io/janusplot/reference/janusplot_shape_hierarchy.md).

## Sensitivity study — built-in

The classifier’s recovery behaviour is characterised across a full
factorial of sample sizes × noise levels × ground-truth shapes:

``` r
# Precomputed 2160-fit demo sweep — zero wait
data("shape_sensitivity_demo")
janusplot_shape_sensitivity_plot(shape_sensitivity_demo, "recovery_curves")
janusplot_shape_sensitivity_plot(shape_sensitivity_demo, "confusion_archetype")

# Run your own — full grid in parallel
future::plan(future::multisession, workers = 4L)
res <- janusplot_shape_sensitivity(parallel = TRUE)
```

Four diagnostic plots (`"confusion_fine"` / `"confusion_archetype"` /
`"accuracy_grid"` / `"recovery_curves"`) + summary aggregations at fine
and archetype levels. Design, pre-registered hypotheses, and full
walk-through in the
[`shape-recognition-sensitivity`](https://max578.github.io/janusplot/articles/shape-recognition-sensitivity.html)
vignette.

## Key features

- **Real GAM fits** via `mgcv` — EDF, F-test p-values, confidence
  envelopes, random effects via `s(g, bs = "re")`.
- **Asymmetric matrix** — upper / lower triangles carry the two
  directional regressions.
- **Three correlation flavours** computed per pair — Pearson (default),
  Spearman, Kendall — surfaced in
  [`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md)
  output.
- **`adjust =` formula** — propagate covariates and random effects into
  every cell’s smooth.
- **[`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md)**
  — per-pair raw fits, correlations, EDFs, p-values, shape metrics +
  hierarchy columns, without the plot.
- **`janusplot(..., with_data = TRUE)`** — plot + tidy data frame in one
  call.
- **Parallel dispatch** via `future.apply` for large matrices and
  sensitivity sweeps.
- **Deterministic** — seed `2026L` pins the shipped demo + vignette
  figures; user sweeps accept `seed =`.

## Why asymmetric?

A Pearson correlation discards both the **shape** of an association and
the **direction** information that a non-linear data-generating process
leaves in its residuals. Under the additive-noise causal discovery
setting (Hoyer et al. 2009; Peters et al. 2014) the forward regression
`y ~ s(x)` and its inverse `x ~ s(y)` are generically asymmetric when
the underlying DGP is non-linear, and that asymmetry identifies the
causal direction under mild conditions. `janusplot` surfaces this
asymmetry as a **visual pre-discovery diagnostic** — not a causal
inference procedure. See the vignette and the accompanying paper for
scope and explicit non-claims.

## Documentation

- [Reference + articles](https://max578.github.io/janusplot/) (pkgdown
  site)
- [`vignette("janusplot")`](https://max578.github.io/janusplot/articles/janusplot.md)
  — quickstart + feature tour
- [`vignette("shape-recognition-sensitivity")`](https://max578.github.io/janusplot/articles/shape-recognition-sensitivity.md)
  — design, hypotheses, every diagnostic plot
- Paper: *Beyond Pearson: Visualising Asymmetric Non-linear Associations
  with Generalised Additive Models* (Moldovan, in preparation; target
  venue *R Journal*).

## Status

`R CMD check --as-cran` clean (0 errors, 0 warnings, 3 cosmetic NOTEs —
new submission / local env); 190 test expectations; 88.5 % coverage.

## Citation

``` r
citation("janusplot")
```
