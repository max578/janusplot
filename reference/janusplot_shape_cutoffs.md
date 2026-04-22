# Default cutoff thresholds for `shape_category` classification

**\[experimental\]**

Returns the named list of thresholds used to map the continuous
monotonicity (`M`) and convexity (`C`) indices (plus inflection counts)
into a discrete `shape_category`. Expose so callers can override
individual thresholds or pass a fully custom list to
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
/
[`janusplot_shape_metrics()`](https://max578.github.io/janusplot/reference/janusplot_shape_metrics.md).

## Usage

``` r
janusplot_shape_cutoffs(...)
```

## Arguments

- ...:

  Optional named overrides to merge into the defaults.

## Value

A named list with numeric thresholds:

- `mono_strong`:

  `|M|` threshold for a strictly monotone smooth (default `0.9`).

- `mono_mod`:

  `|M|` threshold for a curved-but-monotone smooth (default `0.5`).

- `mono_nonmono`:

  `|M|` below this is considered non-monotone (default `0.3`).

- `mono_s`:

  `|M|` threshold for labelling an S-shape (default `0.5`).

- `curv_low`:

  `|C|` below this is considered near-linear curvature (default `0.2`).

- `curv_mod`:

  `|C|` threshold for a clearly curved monotone (default `0.5`).

- `curv_strong`:

  `|C|` threshold for a U-shape / inverted-U shape (default `0.5`).

- `flat`:

  `range(fit) / sd(y)` below this is called `flat` (default `0.05`).

## Examples

``` r
janusplot_shape_cutoffs()
#> $mono_strong
#> [1] 0.9
#> 
#> $mono_mod
#> [1] 0.5
#> 
#> $mono_nonmono
#> [1] 0.3
#> 
#> $mono_s
#> [1] 0.5
#> 
#> $curv_low
#> [1] 0.2
#> 
#> $curv_mod
#> [1] 0.5
#> 
#> $curv_strong
#> [1] 0.5
#> 
#> $flat
#> [1] 0.05
#> 
janusplot_shape_cutoffs(curv_mod = 0.6, flat = 0.02)
#> $mono_strong
#> [1] 0.9
#> 
#> $mono_mod
#> [1] 0.5
#> 
#> $mono_nonmono
#> [1] 0.3
#> 
#> $mono_s
#> [1] 0.5
#> 
#> $curv_low
#> [1] 0.2
#> 
#> $curv_mod
#> [1] 0.6
#> 
#> $curv_strong
#> [1] 0.5
#> 
#> $flat
#> [1] 0.02
#> 
```
