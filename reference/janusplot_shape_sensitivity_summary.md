# Summarise a shape-sensitivity sweep

**\[experimental\]**

Aggregate the raw output of
[`janusplot_shape_sensitivity()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md)
into a per-cell mean-accuracy table at either the fine (24-category) or
archetype (7-family) level.

## Usage

``` r
janusplot_shape_sensitivity_summary(results, level = c("fine", "archetype"))
```

## Arguments

- results:

  Data frame returned by
  [`janusplot_shape_sensitivity()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md).

- level:

  One of `"fine"` (default) or `"archetype"`.

## Value

A data frame with columns `truth`, `n`, `sigma`, `accuracy`.

## See also

Other shape-sensitivity:
[`janusplot_shape_sensitivity()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity.md),
[`janusplot_shape_sensitivity_plot()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_plot.md),
[`janusplot_shape_sensitivity_shapes()`](https://max578.github.io/janusplot/reference/janusplot_shape_sensitivity_shapes.md)

## Examples

``` r
data("shape_sensitivity_demo", package = "janusplot")
head(janusplot_shape_sensitivity_summary(shape_sensitivity_demo,
                                         level = "archetype"))
#>        truth   n sigma  accuracy
#> 1    bimodal 100  0.05 1.0000000
#> 2 concave_up 100  0.05 1.0000000
#> 3 inverted_u 100  0.05 1.0000000
#> 4  linear_up 100  0.05 0.6666667
#> 5    u_shape 100  0.05 1.0000000
#> 6       wave 100  0.05 0.0000000
```
