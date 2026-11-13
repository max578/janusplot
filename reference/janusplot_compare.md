# Compare two fits of the same variables cell by cell

**\[stable\]**

Matches every directed cell of two
[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
objects over the same variables and reports how the EDF, the asymmetry
index and the shape labels move from the first fit to the second. The
typical use puts a marginal fit against one adjusted for a grouping
variable, which shows how sensitive each fitted shape is to that
adjustment. Nothing is refitted.

## Usage

``` r
janusplot_compare(fit_a, fit_b, labels = c("A", "B"))

# S3 method for class 'janusplot_compare'
print(x, ...)
```

## Arguments

- fit_a, fit_b:

  `janusplot_fit` objects over the same set of variables. `fit_a` is the
  reference (often the marginal fit), `fit_b` the comparison (often the
  adjusted fit).

- labels:

  Character vector of length 2 naming `fit_a` and `fit_b` in printed and
  plotted output; two different, non-empty strings. `c("A", "B")` by
  default.

- x:

  A `janusplot_compare` object.

- ...:

  Ignored by the [`print()`](https://rdrr.io/r/base/print.html) method.

## Value

A list of class `janusplot_compare` with components:

- `table`:

  Data frame with one row per directed cell, in the row order of
  `summary(fit_a)`: `var_x` (predictor), `var_y` (response), `position`
  (`"upper"` or `"lower"` in `fit_a`), `n_used_a`, `n_used_b`, `edf_a`,
  `edf_b`, `delta_edf`, `A_a`, `A_b`, `delta_A` (the pair's asymmetry
  index), `shape_a`, `shape_b`, `shape_changed` (logical),
  `archetype_a`, `archetype_b`, `archetype_changed` (logical),
  `trend_a`, `trend_b` and `trend_changed` (logical). The trend is
  `"increasing"` or `"decreasing"` for a monotone shape (by the sign of
  the monotonicity index), otherwise `"non_monotone"` or `"degenerate"`.

- `fit_a`, `fit_b`:

  The two fits as given.

- `labels`:

  The two labels.

[`print()`](https://rdrr.io/r/base/print.html) returns `x` invisibly.

## Details

Cells are matched by variable names, so the two fits may store their
variables and pairs in different orders. Differences are the second fit
minus the first. A shape or archetype change is `NA` when the fit failed
on either side, where the label is `"indeterminate"` or `NA`.

The comparison reports sensitivity to adjustment. A changed label says
the fitted shape depends on the adjustment; it does not by itself say
why.

## See also

[`plot.janusplot_compare()`](https://max578.github.io/janusplot/reference/plot.janusplot_compare.md)
for the matrix with both curves,
[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
for the fits.

Other smooth-associations:
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md),
[`janusplot_curves()`](https://max578.github.io/janusplot/reference/janusplot_curves.md),
[`janusplot_direction()`](https://max578.github.io/janusplot/reference/janusplot_direction.md),
[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md),
[`janusplot_pair()`](https://max578.github.io/janusplot/reference/janusplot_pair.md),
[`janusplot_reference()`](https://max578.github.io/janusplot/reference/janusplot_reference.md),
[`janusplot_style()`](https://max578.github.io/janusplot/reference/janusplot_style.md),
[`plot.janusplot_compare()`](https://max578.github.io/janusplot/reference/plot.janusplot_compare.md),
[`plot.janusplot_fit()`](https://max578.github.io/janusplot/reference/plot.janusplot_fit.md)

## Examples

``` r
set.seed(2026L)
g <- rep(c("g1", "g2", "g3"), each = 40L)
mu <- c(g1 = 0, g2 = 2, g3 = 4)[g]
d <- data.frame(x = mu + stats::rnorm(120L), g = factor(g))
d$y <- -1.5 * mu + 0.8 * (d$x - mu) + stats::rnorm(120L, sd = 0.4)
d$z <- sin(d$x) + stats::rnorm(120L, sd = 0.3)
vars <- c("x", "y", "z")
fit_a <- janusplot_fit(d, vars, engine = "gam", derivatives = integer())
fit_b <- janusplot_fit(d, vars, adjust = ~ g, engine = "gam",
                       derivatives = integer())
cmp <- janusplot_compare(fit_a, fit_b,
                         labels = c("marginal", "group-adjusted"))
cmp
#> janusplot comparison: marginal against group-adjusted
#> 3 variables (x, y, z), 3 pairs, 6 directed cells
#> adjust: marginal = none, group-adjusted = ~g
#> From marginal to group-adjusted, the shape changed in 4 of 6 directed cells (3 of 3 pairs), the archetype in 3 and the trend in 3.
#> Cells whose shape changed:
#>   x ~ s(y): shape rippled_wave -> convex_up, EDF 7.14 -> 1.91, A 0.22 -> 0.14
#>   x ~ s(z): shape linear_down -> s_shape, EDF 1.00 -> 1.00, A 0.78 -> 0.78
#>   y ~ s(x): shape wave -> s_shape, EDF 4.54 -> 2.51, A 0.22 -> 0.14
#>   y ~ s(z): shape linear_up -> linear_down, EDF 1.00 -> 1.00, A 0.78 -> 0.77
cmp$table[, c("var_x", "var_y", "edf_a", "edf_b", "shape_changed")]
#>   var_x var_y    edf_a    edf_b shape_changed
#> 1     y     x 7.143071 1.908503          TRUE
#> 2     z     x 1.000060 1.000900          TRUE
#> 3     x     y 4.538976 2.507604          TRUE
#> 4     z     y 1.000176 1.000168          TRUE
#> 5     x     z 7.994207 7.969067         FALSE
#> 6     y     z 8.077788 7.643365         FALSE
```
