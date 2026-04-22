# Shape-category taxonomy table

**\[experimental\]**

Return the full janusplot shape taxonomy as a data frame with four
hierarchy columns plus presentation fields. The taxonomy is the single
source of truth consumed by the classifier, the cell renderer, the
legend plate, and the
[`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md)
output.

Hierarchy columns (finest → coarsest):

- `category`:

  24-way fine label (`linear_up`, `skewed_peak`, `bimodal`, …). Computed
  per cell by
  [`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md).

- `code`:

  Unique two-letter ASCII shorthand (safe on any font or typesetting
  pipeline) — e.g. `lu` for `linear_up`.

- `archetype`:

  Seven-family grouping: `monotone_linear`, `monotone_curved`,
  `unimodal`, `wave`, `multimodal`, `chaotic`, `degenerate`.

- `monotonic`:

  Three-way coarse classification: `monotone` / `non_monotone` /
  `degenerate`.

- `linear`:

  Binary: `linear` / `non_linear` / `degenerate`.

The broader tiers (linear/non-linear, monotone/non-monotone) are
textbook calculus; the archetype layer maps cleanly to shape-constrained
regression vocabulary (Pya & Wood 2015; Meyer 2008) and to dose-response
shape categories (Calabrese 2008; Calabrese & Baldwin 2001). The
`(T, I)` dispatch underlying each fine category is a coarsened
Morse-theoretic critical-point classification (Milnor 1963).

## Usage

``` r
janusplot_shape_hierarchy()
```

## Value

A data frame with 24 rows and columns `category`, `code`, `archetype`,
`monotonic`, `linear`, `glyph`, `ascii`, `label`, `gloss`.

## References

Calabrese, E. J. (2008). Hormesis: why it is important to toxicology and
toxicologists. *Environmental Toxicology and Chemistry*, **27**(7),
1451–1474.

Meyer, M. C. (2008). Inference using shape-restricted regression
splines. *Annals of Applied Statistics*, **2**(3), 1013–1033.

Milnor, J. (1963). *Morse Theory*. Princeton University Press.

Pya, N., & Wood, S. N. (2015). Shape constrained additive models.
*Statistics and Computing*, **25**(3), 543–559.

## Examples

``` r
tax <- janusplot_shape_hierarchy()
head(tax[, c("category", "code", "archetype", "monotonic", "linear")])
#>       category code       archetype monotonic     linear
#> 1    linear_up   lu monotone_linear  monotone     linear
#> 2  linear_down   ld monotone_linear  monotone     linear
#> 3    convex_up   vu monotone_curved  monotone non_linear
#> 4   concave_up   cu monotone_curved  monotone non_linear
#> 5  convex_down   vd monotone_curved  monotone non_linear
#> 6 concave_down   cd monotone_curved  monotone non_linear
# Count how many categories live in each archetype
table(tax$archetype)
#> 
#>         chaotic      degenerate monotone_curved monotone_linear      multimodal 
#>               1               2               6               2               4 
#>        unimodal            wave 
#>               5               4 
```
