# Asymmetric smoothed-association matrix

**\[experimental\]**

Render a pairwise, asymmetric matrix of smoothed associations between
numeric variables. Each cell \[i, j\] where `i != j` shows the fitted
spline from [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html):

- Upper triangle (`i < j`): `gam(x_j ~ s(x_i) + <adjust>)`.

- Lower triangle (`i > j`): `gam(x_i ~ s(x_j) + <adjust>)`.

- Diagonal: blank panel when labels live on the border (default), or a
  variable-name label when `labels = "diagonal"`.

The two triangles intentionally differ — the asymmetry reveals
heteroscedasticity, leverage, and directional non-linearity that a
single scalar correlation hides.

## Usage

``` r
janusplot(
  data,
  vars = NULL,
  adjust = NULL,
  method = "REML",
  k = -1L,
  bs = "tp",
  order = c("original", "hclust", "alphabetical"),
  show_data = TRUE,
  show_ci = TRUE,
  colour_by = c("pearson", "spearman", "kendall", "edf", "deviance_gap", "none"),
  fill_by = NULL,
  palette = NULL,
  annotations = c("edf", "A"),
  shape_cutoffs = janusplot_shape_cutoffs(),
  show_shape_legend = TRUE,
  glyph_style = c("ascii", "unicode"),
  labels = c("border", "diagonal", "none"),
  label_srt = 45,
  label_cex = 1,
  signif_glyph = TRUE,
  show_asymmetry = NULL,
  na_action = c("pairwise", "complete"),
  parallel = FALSE,
  with_data = FALSE,
  text_scale_diag = 1,
  text_scale_off_diag = 1,
  show_glossary = TRUE,
  glossary_scale = 1,
  ...
)
```

## Arguments

- data:

  A data frame with numeric columns to include.

- vars:

  Character vector of column names to use. `NULL` (default) uses all
  numeric columns in `data`. Non-numeric columns trigger an error
  listing offenders.

- adjust:

  A one-sided formula RHS giving additional covariates and/or random
  effects to include in every pairwise GAM. For example,
  `adjust = ~ s(age) + s(site, bs = "re")` fits
  `gam(y ~ s(x) + s(age) + s(site, bs = "re"))` for each pair. Default
  `NULL` fits unadjusted pairwise smooths.

- method:

  Smoothing-parameter estimation method passed to
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html). Default
  `"REML"` per mgcv recommendation.

- k:

  Integer, or named list mapping variable names to integers. Basis
  dimension for `s()`. Default `-1L` (mgcv's automatic choice).

- bs:

  Basis type for `s()`. Default `"tp"` (thin plate).

- order:

  One of `"original"` (default), `"hclust"` (reorder by hierarchical
  clustering of Pearson correlations), or `"alphabetical"`.

- show_data:

  Logical. If `TRUE` (default), overlay raw data points (low alpha)
  behind each spline.

- show_ci:

  Logical. If `TRUE` (default), overlay the 95% confidence envelope from
  `predict(gam, se.fit = TRUE)`.

- colour_by:

  One of `"pearson"` (default), `"spearman"`, `"kendall"`, `"edf"`,
  `"deviance_gap"`, or `"none"`. Encodes the per-cell fill colour by the
  chosen scalar. Correlation choices use a diverging palette with limits
  `c(-1, 1)` and a shared `corr` colour-bar title; `"edf"` and
  `"deviance_gap"` use a sequential palette labelled by the metric.

- fill_by:

  Deprecated alias for `colour_by`. If supplied emits a single soft
  deprecation warning and is forwarded to `colour_by`.

- palette:

  Character. Colour palette for the cell fill scale. Defaults to
  `"RdBu"` when `colour_by` is a correlation and `"viridis"` otherwise.
  Sequential choices: `"viridis"`, `"magma"`, `"inferno"`, `"plasma"`,
  `"cividis"`, `"mako"`, `"rocket"`, `"turbo"` (not CB-safe),
  `"YlOrRd"`, `"YlGnBu"`, `"Blues"`, `"Greens"`. Diverging choices:
  `"RdYlBu"`, `"RdBu"`, `"PuOr"`, `"Spectral"` (not CB-safe). Passing a
  sequential palette while `colour_by` is a correlation silently
  upgrades to the default diverging palette.

- annotations:

  Character vector, a subset of `c("edf", "A", "shape", "code")`.
  Controls which corner annotations appear on each off-diagonal cell:

  - `"code"` — 2-letter ASCII shape code, **top-left** corner.

  - `"A"` and `"edf"` — asymmetry index and effective degrees of
    freedom, stacked **bottom-left**.

  - `"shape"` — shape glyph (Unicode or ASCII per `glyph_style`),
    **bottom-right** corner.

  Default `c("edf", "A")`. `"code"` and `"shape"` occupy distinct
  corners so both can be requested together. See
  [`janusplot_shape_hierarchy()`](https://max578.github.io/janusplot/reference/janusplot_shape_hierarchy.md)
  for the full code list.

- shape_cutoffs:

  Named list of classification thresholds used to map the continuous
  shape indices into discrete `shape_category` labels; see
  [`janusplot_shape_cutoffs()`](https://max578.github.io/janusplot/reference/janusplot_shape_cutoffs.md).

- show_shape_legend:

  Logical. If `TRUE` (default), attach a standing shape-types legend
  plate below the matrix that illustrates every category in the taxonomy
  as a canonical thumbnail spline. Independent of `annotations`.

- glyph_style:

  One of `"ascii"` (default) or `"unicode"`. Controls how cell shape
  glyphs render when `"shape"` is included in `annotations`. Default is
  `"ascii"` for maximum portability across typesetting pipelines; switch
  to `"unicode"` only when the target font is known to cover the curve
  glyph set.

- labels:

  One of `"border"` (default), `"diagonal"`, or `"none"`. Controls where
  variable names are rendered:

  - `"border"` — names along the top (rotated per `label_srt`) and left
    margins of the matrix; diagonal cells are left blank. Mirrors
    `corrplot`'s `tl.pos = "lt"` convention.

  - `"diagonal"` — names centred on the diagonal cells (the pre-0.1
    layout).

  - `"none"` — labels suppressed entirely; diagonal cells blank.

- label_srt:

  Numeric. Rotation (degrees) of top labels when `labels = "border"`.
  Default `45`; set to `0` for horizontal or `90` for vertical. Ignored
  when `labels != "border"`.

- label_cex:

  Positive numeric multiplier on the border-label font size. Default
  `1`. Ignored when `labels = "none"`.

- signif_glyph:

  Logical. If `TRUE` (default), annotate cells with `·` / `*` / `**`
  reflecting the smooth's F-test p-value.

- show_asymmetry:

  Deprecated. Use `annotations` instead (`"A" %in% annotations`). When
  supplied, a soft deprecation warning fires and the argument is merged
  into `annotations`.

- na_action:

  One of `"pairwise"` (default; per-cell complete observations) or
  `"complete"` (listwise; all cells use the same rows).

- parallel:

  Logical. If `TRUE`, use
  [`future.apply::future_mapply()`](https://future.apply.futureverse.org/reference/future_mapply.html)
  to fit pairs in parallel. Requires the `future.apply` package and a
  user-configured
  [`future::plan()`](https://future.futureverse.org/reference/plan.html).
  Default `FALSE`.

- with_data:

  Logical. If `TRUE`, return a two-element list `list(plot, data)` where
  `data` is a flat per-cell summary (one row per off-diagonal cell) of
  everything the plot displays. If the `data.table` package is
  installed, `data` is returned as a `data.table`; otherwise as a
  `data.frame`. Default `FALSE` — in which case only the ggplot is
  returned.

- text_scale_diag:

  Positive numeric multiplier applied to the diagonal variable-name
  labels. Default `1`. Diagonal labels additionally auto-shrink for long
  variable names (`nchar(var) > 10`) so they fit the cell regardless of
  this value.

- text_scale_off_diag:

  Positive numeric multiplier applied to all off-diagonal annotations
  (`n` / `EDF` readouts, significance glyphs, asymmetry-index labels).
  Default `1`. Use `< 1` when cells are small and the annotations crowd
  the fit line; use `> 1` for presentation plots.

- show_glossary:

  Logical. If `TRUE` (default), attach a multi-line caption below the
  matrix describing the on-plot abbreviations (`n`, `EDF`, `A`, fill
  encoding, significance glyphs). Only keys actually displayed are
  listed.

- glossary_scale:

  Positive numeric multiplier on the glossary caption font size. Default
  `1`.

- ...:

  Additional arguments passed to
  [`mgcv::gam()`](https://rdrr.io/pkg/mgcv/man/gam.html).

## Value

If `with_data = FALSE` (default), a
[ggplot2::ggplot](https://ggplot2.tidyverse.org/reference/ggplot.html)
object (via
[`patchwork::wrap_plots()`](https://patchwork.data-imaginist.com/reference/wrap_plots.html)).
If `with_data = TRUE`, a list with two elements: `plot` (the ggplot) and
`data` (a tidy table with columns `var_x`, `var_y`, `position`,
`n_used`, `edf`, `pvalue`, `signif`, `dev_exp`, `asymmetry_index`,
`cor_pearson`, `cor_spearman`, `cor_kendall`, `tie_ratio`,
`monotonicity_index`, `convexity_index`, `n_turning_points`,
`n_inflections`, `flat_range_ratio`, `shape_category`, `colour_value`,
one row per off-diagonal cell).

## See also

[`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md)
for the raw per-cell fits + metrics.

Other smooth-associations:
[`janusplot_data()`](https://max578.github.io/janusplot/reference/janusplot_data.md)

## Examples

``` r
# Small numeric data frame — runs in under a second
janusplot(mtcars[, c("mpg", "hp", "wt", "qsec")])


# \donttest{
# Heteroscedastic DGP: Pearson r is ~ 0.9 but the inverse fit is
# clearly non-linear, yielding asymmetry index > 0.5.
set.seed(2026L)
n  <- 200L
x1 <- stats::runif(n, 0, 10)
x2 <- x1 + stats::rnorm(n, sd = 0.2 * x1)
janusplot(data.frame(x1 = x1, x2 = x2, x3 = stats::rnorm(n)),
          show_asymmetry = TRUE)
#> Warning: The `show_asymmetry` argument of `janusplot()` is deprecated as of janusplot
#> 0.0.0.9000.
#> ℹ Please use the `annotations` argument instead.

# }
```
