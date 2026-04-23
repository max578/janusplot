# Canonical ground-truth shapes for the sensitivity study

**\[experimental\]**

Return the names of every canonical ground-truth shape that
[`janusplot_shape_sensitivity()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md)
can simulate from. Fourteen shapes spanning five archetypes
(`monotone_linear`, `monotone_curved`, `unimodal`, `wave`,
`multimodal`). The `chaotic` and `degenerate` archetypes are out of
scope (no realistic deterministic generator).

## Usage

``` r
janusplot_shape_sensitivity_shapes()
```

## Value

Character vector of length 14 — the generator names.

## See also

[`janusplot_shape_sensitivity()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md),
[`janusplot_shape_hierarchy()`](https://max578.github.io/janusplot/reference/janusplot_shape_hierarchy.md).

Other shape-sensitivity:
[`janusplot_shape_sensitivity()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md),
[`janusplot_shape_sensitivity_plot()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_plot.md),
[`janusplot_shape_sensitivity_summary()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_summary.md)

## Examples

``` r
janusplot_shape_sensitivity_shapes()
#>  [1] "linear_up"    "linear_down"  "convex_up"    "concave_up"   "convex_down" 
#>  [6] "concave_down" "s_shape"      "u_shape"      "inverted_u"   "skewed_peak" 
#> [11] "broad_peak"   "wave"         "bimodal"      "bi_wave"     
```
