
<!-- README.md is auto-generated from README.Rmd — edit README.Rmd, then
     run rmarkdown::render("README.Rmd") to refresh README.md. -->

# janusplot <a href="https://github.com/AAGI-AUS/effectsurf"><img src="man/figures/logo.png" align="right" height="120" alt="janusplot logo" /></a>

<!-- badges: start -->

<!-- badges are re-activated post-merge into effectsurf; see ../merge-prep/ -->

<!-- badges: end -->

Asymmetric, GAM-based smoothed-association matrices for continuous
variables. A per-pair asymmetry index quantifies the directional
disparity between the two regressions in `[0, 1]`.

> **Scratch package, not for independent release.** `janusplot` is a
> development workspace for the `janusplot()` and `janusplot_data()`
> functions, which merge into `AAGI-AUS/effectsurf` once feature-
> complete. See `../BRAINSTORM.md` and `../PROJECT_LOG.md` in the
> surrounding dev workspace for full context.

## What it does

For each ordered pair of continuous variables $(X_i, X_j)$ with
$i \neq j$, `janusplot()` fits `mgcv::gam(X_j ~ s(X_i) + <adjust>)` and
renders the fitted spline (with 95% confidence envelope and raw scatter)
in matrix cell $[i, j]$. The upper and lower triangles carry the two
directional regressions; the diagonal carries variable labels. Fill
colour encodes the effective degrees of freedom (EDF); annotations carry
per-cell $n$, EDF, significance glyph, and optionally the asymmetry
index.

## Why asymmetric?

A Pearson correlation discards both the **shape** (linear, non-linear,
U-shaped) and the **direction** of an association. Under the additive
noise model of causal discovery (Hoyer et al. 2009; Peters et al. 2014),
the forward regression $y \sim s(x)$ and its inverse $x \sim s(y)$ are
generically asymmetric when the data-generating process is non-linear,
and that asymmetry identifies the causal direction under mild
conditions. `janusplot` surfaces this asymmetry as a **visual
pre-discovery diagnostic** — not a causal inference procedure. See the
vignette and paper for the scope and explicit non-claims.

## Install (pre-merge)

``` r
# Scratch package; install from the dev workspace tarball.
install.packages(
  "/path/to/janusplot_dev/janusplot_0.0.0.9000.tar.gz",
  repos = NULL, type = "source"
)
```

Post-merge, the function will be available via `effectsurf`:

``` r
pak::pak("AAGI-AUS/effectsurf")
```

## Quick start

``` r
library(janusplot)

# Four numeric columns from mtcars
janusplot(mtcars[, c("mpg", "hp", "wt", "qsec")])
```

## Key features

- **Real GAM fits** — not loess. Access EDF, smooth F-test p-values, and
  95% confidence envelopes via `janusplot_data()`.
- **Asymmetric matrix layout** — upper and lower triangles encode the
  two directional regressions.
- **Asymmetry index** — `|EDF_yx − EDF_xy| / (EDF_yx + EDF_xy)`, bounded
  in `[0, 1]`.
- **Partial smooths via `adjust =`** — covariates and random effects
  (`s(g, bs = "re")`) propagate to every cell.
- **16 palette choices** — viridis family, ColorBrewer sequential and
  diverging; 11 of 16 are colourblind-safe.
- **Shared right-margin colourbar legend** when `fill_by != "none"`.
- **Dynamic glossary caption** — only lists keys actually shown on the
  plot.
- **`with_data = TRUE`** returns a tidy per-cell `data.table` /
  `data.frame`.
- **Parallel fits via `future.apply`** for large matrices.

## Documentation

- Vignette: `vignette("janusplot", package = "janusplot")`.
- Paper: *Beyond Pearson: Visualising Asymmetric Non-linear Associations
  with Generalised Additive Models* (Moldovan, in preparation, R
  Journal). Source + replication bundle in `../paper/`.

## Status

Pre-merge scratch package. `R CMD check --as-cran` clean (0/0/2); 90+
tests pass (65 unit + 5 vdiffr + 20+ integration); 14-page paper PDF
compiles end-to-end.

## Citation

``` r
citation("janusplot")
```
