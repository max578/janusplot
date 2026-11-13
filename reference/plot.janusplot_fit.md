# Draw the matrix of a janusplot fit

**\[stable\]**

Draws the asymmetric matrix of a
[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
object: one cell per directed pair, the fitted curve with its band over
the raw points, the variable names along the top and left borders.
Nothing is refitted; every number on the plot is in the object.

## Usage

``` r
# S3 method for class 'janusplot_fit'
plot(
  x,
  colour_by = c("nonlinearity", "asymmetry", "pearson", "spearman", "kendall",
    "deviance_gap", "none"),
  background_by = c("pearson", "spearman", "kendall", "none"),
  annotations = NULL,
  order = c("original", "hclust", "alphabetical"),
  display = c("fit", "d1", "d2"),
  group = NULL,
  focus_by = NA_character_,
  focus_threshold = "q90",
  axes = c("original", "standardised", "centred", "rank"),
  style = janusplot_style(),
  ...
)
```

## Arguments

- x:

  A `janusplot_fit` object.

- colour_by:

  The quantity painted on each cell: `"nonlinearity"` (the default; EDF
  minus 1 of the cell's smooth, sequential from 0), `"asymmetry"` (the
  pair's index A in `[0, 1]`, the same in both cells), `"pearson"`,
  `"spearman"` or `"kendall"` (the pair's correlation on a diverging
  scale over `[-1, 1]`), `"deviance_gap"` (deviance explained by the
  smooth minus the straight line's) or `"none"`.

- background_by:

  The correlation that tints each cell's background: `"pearson"`,
  `"spearman"`, `"kendall"`, or `"none"` for no background. Left unset,
  it is `"pearson"` for a marginal fit and `"none"` for a fit with
  `adjust`, whose curves are adjusted while the correlations are
  marginal; set it to show the marginal correlation behind adjusted
  curves. Independent of `colour_by`. It cannot be combined with
  `janusplot_style(colour_channel = "fill")`, which paints the same
  area.

- annotations:

  Character vector, a subset of
  `c("A", "edf", "signif", "code", "shape", "k_warn", "n", "r", "formula")`,
  written in the strip of every cell (or in its corners under
  `janusplot_style(annotation_position = "corners")`): the asymmetry
  index, the EDF, the significance glyph of the smooth F-test (`***` p
  \< .001, `**` p \< .01, `*` p \< .05, `.` p \< .1, from the adjusted
  p-value when the fit has `p_adjust` other than `"none"`), the
  two-letter shape code, the shape glyph, a warning sign on cells
  flagged by the k-check or capped at the distinct predictor count, the
  rows used, the `background_by` correlation of the pair (Pearson when
  `background_by = "none"`), printed `"r -0.03"` (`"marginal r -0.03"`
  for a fit with `adjust`), and the cell's formula, printed
  `Temp ~ Ozone`. `NULL` (the default) picks by matrix size:
  `c("A", "signif")` up to twelve variables, `"signif"` from thirteen,
  where 5-point strips of neighbouring cells would touch;
  [`character()`](https://rdrr.io/r/base/character.html) writes none.

- order:

  Order of the variables in the matrix: `"original"` (the default, the
  order of `x$vars`), `"hclust"` (hierarchical clustering of absolute
  Pearson correlations) or `"alphabetical"`. Drawing only; the fit is
  unchanged.

- display:

  What every off-diagonal cell shows: `"fit"` (the default), `"d1"` (the
  first derivative of the smooth, whose zero crossings are turning
  points) or `"d2"` (the second derivative, whose zero crossings are
  inflections). A derivative view needs the fit to carry that order in
  `x$settings$derivatives`.

- group:

  Name of a factor, character or logical column of `x$data` whose levels
  colour the raw points, with one legend below the matrix, or `NULL`
  (the default). Drawing only; the column never enters the model. The
  column must exist in `x$data` and have at most
  `style$group_max_levels` levels.

- focus_by:

  `NA` (the default, no filter) or one of `"asymmetry"`, `"edf"`,
  `"non_linearity"` (EDF minus 1) and `"k_flag"`. Cells whose metric
  falls below `focus_threshold` are washed in grey at
  `style$focus_dim_alpha`; the matrix keeps its shape. A visual filter
  only; the fit and its table are unchanged.

- focus_threshold:

  A quantile string, `"q90"` by default (taken over the off-diagonal
  cells), or a single numeric cutoff. Ignored when `focus_by` is `NA`.

- axes:

  Scale of the drawn axes: `"original"` (the default), `"standardised"`
  (`(x - mean) / sd` per variable, border label `"var (z)"`),
  `"centred"` (`x - mean`, label `"var (centred)"`) or `"rank"`
  (empirical rank, label `"rank(var)"`). Drawing only; the same
  transform is applied to the points, the curve and the band.

- style:

  A
  [`janusplot_style()`](https://max578.github.io/janusplot/reference/janusplot_style.md)
  object holding every appearance setting.

- ...:

  Must be empty. An unknown name is an error, so a misspelt style knob
  cannot pass silently.

## Value

A
[patchwork](https://patchwork.data-imaginist.com/reference/patchwork-package.html)
object, which is a ggplot: the matrix with its border labels and corner
key, the colour bar when `colour_by` is not `"none"`, the background
colour bar when `background_by` is not `"none"`, the group legend when
`group` is given, the shape-categories legend when
`style$show_shape_legend` is `TRUE`, or `"auto"` and `annotations`
include `"code"`, a title naming the displayed quantity and the glossary
caption when `style$show_glossary` is `TRUE`.

## Details

Every off-diagonal cell `[r, c]` shows `vars[r] ~ s(vars[c])`: the
variable named left of the row is the response on the vertical axis and
the variable named above the column is the predictor on the horizontal
axis, as in
[`graphics::pairs()`](https://rdrr.io/r/graphics/pairs.html). Cells
`[r, c]` and `[c, r]` are the two directions of one pair and differ by
design. A key in the top-left corner shows the convention with the first
two variables (`style$show_key`).

The `colour_by` value is painted on the border, a corner tile or the
whole cell per `style$colour_channel`, with one colour bar per matrix.
The `background_by` correlation tints the panel behind the points, band
and curve: white at zero and `style$background_strength` of the way to
the negative or positive end of `style$background_palette` at minus or
plus one, with its own colour bar over `[-1, 1]`. A strip above each
cell carries the `annotations`; the asymmetry index belongs to the pair
and is written once, above the cell in the upper triangle. The diagonal
shows the kernel density of each variable with a rug of its values, and
with `group` one density per level, scaled by the level's share of the
rows so the coloured curves sum to the grey pooled density
(`style$diagonal`).

The default sizes are set for a figure one page wide (170 mm). At one
journal column (85 mm), draw at most four variables with
`janusplot_style(text_size = 6, show_shape_legend = FALSE, show_glossary = FALSE)`.

The colour bars sit in a column to the right of the matrix, which suits
a wide screen. For a printed page,
`janusplot_style(legend_position = "bottom", label_srt = 0)` puts the
bars and the key under the matrix, so the cells take the full width, and
`show_glossary = FALSE` leaves the explanation to the figure caption.

`colour_by = "edf"` is accepted for one release and mapped to
`"nonlinearity"` with a deprecation message.

## See also

[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md)
for the object,
[`janusplot_style()`](https://max578.github.io/janusplot/reference/janusplot_style.md)
for the appearance settings,
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md)
for the one-call form.

Other smooth-associations:
[`janusplot()`](https://max578.github.io/janusplot/reference/janusplot.md),
[`janusplot_compare()`](https://max578.github.io/janusplot/reference/janusplot_compare.md),
[`janusplot_curves()`](https://max578.github.io/janusplot/reference/janusplot_curves.md),
[`janusplot_direction()`](https://max578.github.io/janusplot/reference/janusplot_direction.md),
[`janusplot_fit()`](https://max578.github.io/janusplot/reference/janusplot_fit.md),
[`janusplot_pair()`](https://max578.github.io/janusplot/reference/janusplot_pair.md),
[`janusplot_reference()`](https://max578.github.io/janusplot/reference/janusplot_reference.md),
[`janusplot_style()`](https://max578.github.io/janusplot/reference/janusplot_style.md),
[`plot.janusplot_compare()`](https://max578.github.io/janusplot/reference/plot.janusplot_compare.md)

## Examples

``` r
fit <- janusplot_fit(mtcars[, c("mpg", "hp", "wt")], engine = "gam")
plot(fit)


# \donttest{
plot(fit, colour_by = "asymmetry", annotations = c("A", "edf", "signif"))

plot(fit, background_by = "none", annotations = c("formula", "r"))


# Points coloured by a factor column of the data; never in the model.
pp <- transform(mtcars[, c("mpg", "hp", "wt", "am")],
                am = factor(am, labels = c("auto", "manual")))
plot(janusplot_fit(pp, vars = c("mpg", "hp", "wt"), engine = "gam"),
     group = "am")


# The first derivative of every smooth, computed at fit time.
plot(fit, display = "d1")

# }
```
