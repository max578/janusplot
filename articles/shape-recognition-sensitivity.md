# Shape-recognition sensitivity study

[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
assigns every fitted smooth to one of 27 shape categories via a
`(n_turning_points, n_inflections)` dispatch with additional
`(monotonicity_index, convexity_index)` disambiguation for the monotone
cases (see the `janusplot` vignette for the full definition of the
indices). How reliably does this classifier recover the ground-truth
shape of a noisy sample? This vignette answers the question with a
full-factorial sensitivity sweep.

## Design

For each combination of ground-truth shape, sample size `n`, and noise
level `sigma`, the sweep:

1.  Generates `n` points from the noiseless canonical curve on
    `x ∈ [0, 1]`, with `y` normalised to `[0, 1]` so that `sigma` is the
    fraction of y-range that Gaussian noise contributes – an
    SNR-comparable scale across shapes.
2.  Fits `mgcv::gam(y ~ s(x), method = "REML")`.
3.  Classifies the fit via
    [`janusplot_shape_metrics()`](https://max578.github.io/janusplot/reference/janusplot_shape_metrics.md).
4.  Records correctness at the **fine** (27-category) and **archetype**
    (7-family) levels.

The design factors are orthogonal and replicated. See
[`?janusplot_shape_sensitivity`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md)
for the function surface. The 14 canonical ground-truth shapes cover
five of the seven archetypes (`chaotic` and `degenerate` have no
realistic deterministic generator). They are the default of the runner’s
`shapes` argument, and any subset of them can be named.

``` r

library(janusplot)
library(ggplot2)

eval(formals(janusplot_shape_sensitivity)$shapes)
#>  [1] "linear_up"    "linear_down"  "convex_up"    "concave_up"   "convex_down" 
#>  [6] "concave_down" "s_shape"      "u_shape"      "inverted_u"   "skewed_peak" 
#> [11] "broad_peak"   "wave"         "bimodal"      "bi_wave"
```

## Pre-registered hypotheses

Four hypotheses were pinned before running the sweep:

- **H1.** At `n = 500`, `sigma = 0.05`, archetype accuracy exceeds 0.90
  for every shape.
- **H2.** Fine-category accuracy exceeds 0.75 at `n = 500`,
  `sigma = 0.05` for monotone + unimodal shapes; wave and multimodal
  tolerate less noise.
- **H3.** Rippled variants require `n >= 200` and `sigma <= 0.10` to
  resolve.
- **H4.** At `sigma = 0.40`, archetype accuracy collapses below 0.50 for
  all but the simplest shapes.

**Verdicts, evaluated against the precomputed demo below (`n = 500`,
`sigma = 0.05` for H1/H2; the demo’s grid runs `sigma` up to 0.40, which
covers H4):**

- **H1 – refuted by one shape.** `bimodal`, `concave_up`, `inverted_u`,
  `u_shape` and `wave` all hit 1.00; `linear_up` reaches only 0.70,
  because about 30% of its fits are labelled as a curved monotone shape
  (see the confusion matrix below).
- **H2 – partly supported.** `bimodal`, `inverted_u`, `u_shape` and
  `wave` reach 1.00 at the fine level. `linear_up` (0.70) and
  `concave_up` (0.63) fall short of 0.75; most `concave_up` misses are
  `s_shape` or `rippled_monotone`, which stay within the
  `monotone_curved` archetype. The second half of the hypothesis does
  not hold in this demo: `wave` and `bimodal` tolerate noise at least as
  well as the monotone shapes.
- **H3 – untestable with the shipped machinery.** No `rippled_*`
  generator exists among the canonical shapes exercised here, so the
  hypothesis has no data to be adjudicated against in this vignette.
- **H4 – refuted, in the other direction.** At `sigma = 0.40` archetype
  accuracy stays at 0.60 or above for every shape at every sample size
  (`wave` drops to 0.80 at `n = 100`) – well clear of the predicted
  sub-0.50 collapse. The classifier is markedly more noise-robust than
  pre-registered.

## Precomputed demo

The package ships a small-footprint precomputed sweep – 6 shapes across
5 of the 7 archetypes (`u_shape` and `inverted_u` both roll up to
`unimodal`) × 3 sample sizes × 4 noise levels × 30 replicates = 2160
fits – so you can explore the API without running the full sweep
yourself. It is a `janusplot_sensitivity` data frame, the class the
runner returns, so [`summary()`](https://rdrr.io/r/base/summary.html)
and [`plot()`](https://rdrr.io/r/graphics/plot.default.html) apply to it
directly.

``` r

data("shape_sensitivity_demo")
str(shape_sensitivity_demo, vec.len = 2)
#> Classes 'janusplot_sensitivity' and 'data.frame':    2160 obs. of  14 variables:
#>  $ truth             : chr  "linear_up" "concave_up" ...
#>  $ n                 : int  100 100 100 100 100 ...
#>  $ sigma             : num  0.05 0.05 0.05 0.05 0.05 ...
#>  $ seed              : int  2027 2028 2029 2030 2031 ...
#>  $ predicted         : chr  "linear_up" "concave_up" ...
#>  $ correct           : logi  TRUE TRUE TRUE ...
#>  $ archetype_truth   : chr  "monotone_linear" "monotone_curved" ...
#>  $ archetype_pred    : chr  "monotone_linear" "monotone_curved" ...
#>  $ archetype_correct : logi  TRUE TRUE TRUE ...
#>  $ monotonicity_index: num  1 1 ...
#>  $ convexity_index   : num  0 -0.847 ...
#>  $ n_turn            : int  0 0 1 1 2 ...
#>  $ n_inflect         : int  0 0 0 0 1 ...
#>  $ error             : chr  NA NA ...
```

### Recovery curves (headline figure)

``` r

plot(shape_sensitivity_demo, "recovery_curves")
```

![Line plot of archetype-recovery accuracy versus sigma, one line per
shape, faceted or coloured by sample size; five lines stay high across
the noise range and one (linear_up) sits near 0.7
throughout.](shape-recognition-sensitivity_files/figure-html/recovery-curves-1.png)

Archetype-recovery accuracy against noise level (sigma) for each of the
six ground-truth shapes, at each of the three sample sizes.

Five of the six shapes are recovered well across the whole noise range,
including at `sigma = 0.40` (see H4 above): `bimodal`, `concave_up`,
`inverted_u` and `wave` hold at 1.00 throughout at `n = 500`, and
`u_shape` only drops to 0.97 at the highest noise level. At `n = 100`
the highest noise level costs `wave` and `concave_up` the most (0.80 and
0.67). `linear_up` is the outlier – at `n = 500` it never exceeds 0.73
even at `sigma = 0.05`, so its curve is flat and mediocre rather than a
high-noise-tolerance decay.

### Archetype confusion

``` r

plot(shape_sensitivity_demo, "confusion_archetype")
```

![Archetype confusion matrix with true archetypes on the rows and
predicted archetypes on the columns; nearly all mass sits on the
diagonal, and linear_up truth splits between monotone_linear and
monotone_curved.](shape-recognition-sensitivity_files/figure-html/archetype-confusion-1.png)

Confusion matrix of true archetype (rows) against predicted archetype
(columns), pooled across all n, sigma and replicates in the demo.

One off-diagonal pattern dominates here. `linear_up` lands in
`monotone_curved` roughly 30% of the time, because sampling noise on a
short curve occasionally tips the fitted `monotonicity_index` below the
monotone-linear cutoff. `wave` is recovered as a wave on 352 of its 360
replicates; the remaining 8 lose a turning point to noise and are
labelled `unimodal`.

### Archetype-level accuracy grid

``` r

plot(shape_sensitivity_demo, "accuracy_grid")
```

![Grid of heatmap panels, one per ground-truth shape, with sample size
on one axis and noise level on the other, cells shaded by
archetype-recovery accuracy; five panels are dark (high accuracy) with
lighter cells at the highest noise level, and the linear_up panel is
uniformly
mid-toned.](shape-recognition-sensitivity_files/figure-html/accuracy-grid-1.png)

Heatmap of archetype-recovery accuracy across the full (n, sigma)
design, one panel per shape.

Per-shape heatmap of `P(archetype correct)` across the `(n, sigma)`
design. Reading across a row shows the noise-tolerance profile of one
sample size; reading up a column shows the sample-size sensitivity at
one noise level.

### Numerical summary

``` r

head(summary(shape_sensitivity_demo, level = "archetype"), 10)
#>         truth   n sigma  accuracy
#> 1     bimodal 100  0.05 1.0000000
#> 2  concave_up 100  0.05 1.0000000
#> 3  inverted_u 100  0.05 1.0000000
#> 4   linear_up 100  0.05 0.6666667
#> 5     u_shape 100  0.05 1.0000000
#> 6        wave 100  0.05 1.0000000
#> 7     bimodal 200  0.05 1.0000000
#> 8  concave_up 200  0.05 1.0000000
#> 9  inverted_u 200  0.05 1.0000000
#> 10  linear_up 200  0.05 0.7666667
```

## Running your own sweep

The demo is a starting point. For the publication-grade figure use the
full default grid (14 shapes × 4 sample sizes × 5 noise levels × 200
reps = 56 000 fits):

``` r

# Configure parallel execution (optional) -- you control the plan.
future::plan(future::multisession, workers = 4L)

res <- janusplot_shape_sensitivity(parallel = TRUE)

# Save for your paper
saveRDS(res, "shape_sensitivity_full.rds")
plot(res, "recovery_curves")
```

### Custom shape subsets + cutoffs

Every argument is tunable. `mono_strong` and `curv_low` are only read on
the monotone dispatch path (`n_turning_points == 0` and
`n_inflections == 0`), so a worked example needs a monotone shape family
to actually exercise them – `linear_up`, `concave_up` and `convex_up`
below, rather than the wave/multimodal family, where these two cutoffs
are never consulted. Tightening `mono_strong` raises the bar for calling
a curve “strictly monotone” (versus `s_shape`/rippled), and lowering
`curv_low` raises the bar for calling it “near-linear” (versus curved).

``` r

strict <- janusplot_shape_cutoffs(mono_strong = 0.95, curv_low = 0.1)

res_strict <- janusplot_shape_sensitivity(
  shapes     = c("linear_up", "concave_up", "convex_up"),
  n_grid     = c(200L, 500L),
  sigma_grid = c(0.05, 0.10, 0.20),
  n_rep      = 100L,
  cutoffs    = strict
)

summary(res_strict, level = "fine")
```

## References

- Pya, N., & Wood, S. N. (2015). Shape constrained additive models.
  *Statistics and Computing*, 25(3), 543–559.
- Calabrese, E. J. (2008). Hormesis: why it is important to toxicology
  and toxicologists. *Environmental Toxicology and Chemistry*, 27(7),
  1451–1474.
- Milnor, J. (1963). *Morse Theory*. Princeton University Press.
- Meyer, M. C. (2008). Inference using shape-restricted regression
  splines. *Annals of Applied Statistics*, 2(3), 1013–1033.

``` r

sessionInfo()
#> R version 4.6.2 (2026-10-29)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 26.04.1 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.32.so;  LAPACK version 3.12.0
#> 
#> locale:
#>  [1] LC_CTYPE=C.UTF-8       LC_NUMERIC=C           LC_TIME=C.UTF-8       
#>  [4] LC_COLLATE=C.UTF-8     LC_MONETARY=C.UTF-8    LC_MESSAGES=C.UTF-8   
#>  [7] LC_PAPER=C.UTF-8       LC_NAME=C              LC_ADDRESS=C          
#> [10] LC_TELEPHONE=C         LC_MEASUREMENT=C.UTF-8 LC_IDENTIFICATION=C   
#> 
#> time zone: UTC
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] ggplot2_4.0.3   janusplot_1.0.0
#> 
#> loaded via a namespace (and not attached):
#>  [1] vctrs_0.7.3        cli_3.6.6          knitr_1.52         rlang_1.3.0       
#>  [5] xfun_0.62          otel_0.3.0         S7_0.2.2           textshaping_1.0.5 
#>  [9] jsonlite_2.0.0     labeling_0.4.3     glue_1.8.1         htmltools_0.5.9   
#> [13] ragg_1.5.2         sass_0.4.10        scales_1.4.0       rmarkdown_2.32    
#> [17] grid_4.6.2         evaluate_1.0.5     jquerylib_0.1.4    fastmap_1.2.0     
#> [21] yaml_2.3.12        lifecycle_1.0.5    compiler_4.6.2     RColorBrewer_1.1-3
#> [25] fs_2.1.0           farver_2.1.2       systemfonts_1.3.2  digest_0.6.39     
#> [29] viridisLite_0.4.3  R6_2.6.1           bslib_0.12.0       withr_3.0.3       
#> [33] tools_4.6.2        gtable_0.3.6       pkgdown_2.2.1      cachem_1.1.0      
#> [37] desc_1.4.3
```
