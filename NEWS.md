# janusplot 1.0.0

janusplot 1.0.0 fits once and draws many times: `janusplot_fit()` fits every
ordered pair of variables once, and `plot()`, `summary()` and every view
below read that object without refitting. Three comparisons build on it:
the two directions of a pair side by side (`janusplot_pair()`), a marginal
fit against an adjusted one (`janusplot_compare()`), and the
residual-independence test of direction (`janusplot_direction()`).

## Breaking changes

* `janusplot()` no longer takes appearance arguments; they live in
  `janusplot_style()`, passed as `style`. The function has fourteen
  formals: `data`, `vars`, `adjust`, the view arguments `colour_by`,
  `background_by`, `annotations`, `order`, `display`, `group`, `focus_by`,
  `focus_threshold`, `axes`, `style`, and `...`, which goes to
  `janusplot_fit()` and then to mgcv. The 0.2.0 names (`show_data`,
  `show_ci`, `palette`, `show_shape_legend`, `glyph_style`, `labels`,
  `diagonal`, `label_srt`, `label_cex`, `text_scale_diag`,
  `text_scale_off_diag`, `show_glossary`, `glossary_scale`, `compact`,
  `compact_threshold`, `compact_levels`, `focus_dim_alpha`, `fill_by`,
  `show_asymmetry`, `signif_glyph`) are accepted through `...` for one
  release, each with a `lifecycle` deprecation warning, and are removed
  in 1.1.0. Arguments after `adjust` must be named.

  ```r
  # 0.2.0
  janusplot(d, show_data = FALSE, palette = "magma", label_srt = 90)

  # 1.0.0
  janusplot(d, style = janusplot_style(show_data = FALSE, palette = "magma",
                                       label_srt = 90))
  ```

* The default cell encodes non-linearity (EDF minus 1) on the panel
  border and tints the panel background by the pair's signed Pearson
  correlation, in place of Pearson r washed over the whole cell.
  `colour_by` defaults to `"nonlinearity"`; its channel is
  `janusplot_style(colour_channel = )`: `"border"` (the default), `"tile"`
  (a bottom-right corner tile) or `"fill"` (the whole cell at alpha 0.45).
  A background with the fill channel is an error naming both settings, so
  the 0.2.0 look needs `background_by = "none"`. `colour_by = "edf"` is
  mapped to `"nonlinearity"` with a deprecation message for one release.

  ```r
  # 0.2.0 (default look)
  janusplot(d)

  # 1.0.0: the same look
  janusplot(d, colour_by = "pearson", background_by = "none",
            style = janusplot_style(colour_channel = "fill"))
  ```

* `with_data = TRUE` is gone. `summary()` on a `janusplot_fit` object
  returns the per-cell table. Given to `janusplot()`, `with_data = TRUE`
  still returns `list(plot, data)` with a deprecation warning for one
  release.

  ```r
  # 0.2.0
  out <- janusplot(d, with_data = TRUE)
  out$plot
  out$data

  # 1.0.0
  fit <- janusplot_fit(d)
  plot(fit)
  summary(fit)
  ```

* `pvalue_yx` / `pvalue_xy` in `$pairs` and `pvalue` in the per-cell
  table are renamed `association_p_yx` / `association_p_xy` and
  `association_p`; the adjusted values sit beside them.

  ```r
  # 0.2.0
  out <- janusplot_data(d)
  out$pairs[[1]]$pvalue_yx
  janusplot(d, with_data = TRUE)$data$pvalue

  # 1.0.0
  fit <- janusplot_fit(d)
  fit$pairs[[1]]$association_p_yx
  summary(fit)$association_p
  summary(fit)$association_p_adj
  ```

* `save_as`, `save_width`, `save_height` and `save_dpi` are gone;
  `ggplot2::ggsave()` writes the returned plot. The shim calls it once
  with a deprecation warning for one release.

  ```r
  # 0.2.0
  janusplot(d, save_as = "matrix.png", save_dpi = 300)

  # 1.0.0
  p <- janusplot(d)
  ggplot2::ggsave("matrix.png", p, width = 6, height = 6, dpi = 300)
  ```

* `labels = "diagonal"` is gone; `janusplot_style(labels = )` takes
  `"border"` or `"none"`, and the shim draws `"diagonal"` as `"border"`
  with a message. `janusplot_style(diagonal = "name")` still writes the
  variable names on the diagonal.

  ```r
  # 0.2.0
  janusplot(d, labels = "diagonal")

  # 1.0.0
  janusplot(d, style = janusplot_style(labels = "none", diagonal = "name"))
  ```

* `janusplot_shape_sensitivity_shapes()`, `janusplot_shape_sensitivity_summary()`
  and `janusplot_shape_sensitivity_plot()` are removed, with no alias.
  `janusplot_shape_sensitivity()` runs the sweep over every ground-truth
  shape by default (the 14 names are the default of its `shapes` argument,
  and `shapes = NULL` means the same) and returns a data frame of class
  `janusplot_sensitivity`; `summary()` and `plot()` on that object do what
  the two helpers did, with the same `level` and `type` arguments.

  ```r
  # 0.2.0
  janusplot_shape_sensitivity_shapes()
  res <- janusplot_shape_sensitivity(shapes = janusplot_shape_sensitivity_shapes())
  janusplot_shape_sensitivity_summary(res, level = "archetype")
  janusplot_shape_sensitivity_plot(res, "recovery_curves")

  # 1.0.0
  eval(formals(janusplot_shape_sensitivity)$shapes)
  res <- janusplot_shape_sensitivity()
  summary(res, level = "archetype")
  plot(res, "recovery_curves")
  ```

* `janusplot_direction_test(data, x, y, k, bs, method, ...)` is replaced by
  `janusplot_direction(fit, x, y, ...)`, which reads the rows, the basis
  dimension, the basis type and the method from a `janusplot_fit` object.
  The old name runs the same engine on the complete cases of two columns
  of `data` for one release, with a `lifecycle` deprecation warning, and
  returns the same object.

  ```r
  # 0.2.0
  res <- janusplot_direction_test(d, "x", "y", k = 10L, seed = 1L)

  # 1.0.0
  fit <- janusplot_fit(d, k = 10L, engine = "gam")
  res <- janusplot_direction(fit, "x", "y", seed = 1L)
  ```

* `janusplot_fit()` computes first and second derivatives at fit time
  (`derivatives = 1:2`), so `n_grid = NULL` resolves to 200 evaluation
  points where `janusplot_data()` used 100 without derivatives. The shape
  indices and counts are computed on this grid, so labels near a cutoff
  can differ from 0.2.0. `derivatives = integer()` restores the 100-point
  grid.
* The cutoffs `mono_nonmono`, `mono_s` and `curv_strong` of
  `janusplot_shape_cutoffs()` are deprecated in 1.0.0. The classifier
  never read them, so passing them had no effect on any label. They raise
  a deprecation warning once per session, are dropped from the returned
  list before validation and no longer appear among the defaults or in
  the documentation. Classification is unchanged.

  ```r
  # 0.2.0: accepted and ignored
  janusplot_shape_cutoffs(curv_strong = 0.6)

  # 1.0.0: the same call warns once and returns the defaults
  janusplot_shape_cutoffs(curv_strong = 0.6)
  ```

* Every off-diagonal cell `[r, c]` of the matrix drawn by `plot()`,
  `janusplot()` and `plot()` on a `janusplot_compare` object now shows
  `vars[r] ~ s(vars[c])`: the row variable on the vertical axis against the
  column variable on the horizontal axis. In 0.x the column variable was the
  response in the upper triangle, so a 0.x figure and a 1.0.0 figure of the
  same data show each pair's two curves in swapped cells. The new layout
  matches `pairs()` and GGally, so the labels name each cell's axes.
  `summary(fit)$position` follows the drawing: `"upper"` is now the
  `_xy` cell.

  ```r
  # 0.2.0: cell [Ozone, Temp] showed Temp ~ s(Ozone)
  # 1.0.0: cell [Ozone, Temp] shows Ozone ~ s(Temp)
  janusplot(airquality[, c("Ozone", "Temp")])
  ```

* `janusplot_style()` replaces `label_cex`, `text_scale_diag`,
  `text_scale_off_diag` and `glossary_scale` with one `text_size` knob.
  Given to `janusplot()`, the old names map to the matching `text_size`
  element with a deprecation warning; the sizes are close to the 0.2.0
  ones, not identical.

  ```r
  # 0.2.0
  janusplot(d, label_cex = 1.2, glossary_scale = 0.8)

  # 1.0.0
  janusplot(d, style = janusplot_style(text_size = list(labels = 12,
                                                        glossary = 7)))
  ```

* `annotations` defaults to `NULL`, which writes `c("A", "signif")` in a
  strip above each cell below eight variables and the significance glyph
  alone from eight, where the strip text is at its 5-point floor. 0.2.0
  wrote `c("edf", "A")` in the bottom-left corner.
  `janusplot_style(annotation_position = "corners")` puts the annotations
  back inside the panel.
* The shape-categories legend is attached by default only when the cells
  carry the shape code: `janusplot_style(show_shape_legend = "auto")` draws
  it when `annotations` include `"code"`. Set `show_shape_legend = TRUE` to
  attach it always, as in 0.2.0.
* `janusplot_data()` is deprecated: it forwards every argument to
  `janusplot_fit()` with a soft deprecation message and is removed in
  1.1.0. Its fourth and later positional arguments follow
  `janusplot_fit()`'s order (`k`, `bs`, `engine`, `method`, ...), so
  arguments beyond `adjust` should be named.
* The per-cell table drops `display` and `colour_value`; both are
  view-level choices that belong to the plot, not to the data.
* `janusplot_direction()` fits each direction with the basis dimension
  that direction used in the fit (`k_used_yx` or `k_used_xy` of the pair)
  and the fit's `bs`, so the verdict rests on the smooths the matrix
  draws. Its rows are the pair's own rows in `fit$data`, so `n` equals the
  pair's `n_used`. A fit made with `engine = "bam"` carries a `bam()`
  method (`"fREML"` by default); the two direction fits then use `gam()`
  with its default `"REML"`, and the method used is returned as `method`.

## New features

* Under `adjust` with the identity link, every view draws each point as a
  partial residual: the observation with its own adjustment replaced by
  the average adjustment, so the points sit around the curve. The curve
  is the smooth averaged over the fixed adjustment covariates of the
  data, with random effects at zero. A Simpson's-paradox reversal then
  shows as a cloud that changes direction. `janusplot_style(adjusted_points
  = "raw")` draws the observed values. Each pair stores the residuals as
  `partial_yx` and `partial_xy`. With a non-identity link the points stay
  raw and covariates are held at typical values.
* `janusplot_reference()` (experimental) gives a bootstrap reference for
  the asymmetry index of chosen pairs. For each direction it simulates
  that direction's fitted smooth with resampled additive residuals,
  keeping the predictor and the adjustment, refits both directions and
  reports the median, the 95th percentile and the share of replicates at
  or above the observed index. `print()` adds a one-line reading per
  pair and `plot()` draws the reference distributions.
* `janusplot_curves()` (experimental) returns the fitted curves, or their
  derivatives, as one long data frame (`var_x`, `var_y`, `position`, `x`,
  `fit`, `se`, `lo`, `hi`) for drawing with any tool.
* `janusplot_style(identity_line = TRUE)` adds the line `y = x` to the
  z-score panels of `janusplot_pair(display = "both")`. There it is the
  standard-deviation line, and a curve flatter than it along its own
  predictor axis regresses towards the mean.
* The strip shows `A` as a dash when neither direction of the pair is
  significant at 0.05, and `print()` leaves such pairs out of its ranking
  and counts them on a line of their own: there the index compares two
  smooths of noise.
* `janusplot_fit()` warns, naming the cells, when a smooth keeps fewer
  than five residual degrees of freedom and so nearly passes through
  every point, as eleven rows with the default basis do.

* `janusplot_fit()` fits every ordered pair once and returns a
  `janusplot_fit` object: `$vars`, `$pairs` (one element per unordered
  pair, the fields `janusplot_data()` returned plus the ones below),
  `$table` (one row per directed cell), `$data` (the cleaned copy of the
  columns used, under the original names), `$adjust`, `$settings` (every
  fit setting as resolved), `$flags` (`failed`, `k_capped`, `k_flagged`,
  `sparse`), `$fits` (the mgcv objects when `keep_fits = TRUE`) and
  `$call`. `print()` lists the variables, the cell count, the engine and
  method, the flags and the five largest asymmetries; `summary()` returns
  `$table`.
* `plot()` on a `janusplot_fit` object draws the matrix from the stored
  fit without refitting: `colour_by` (`"nonlinearity"`, `"asymmetry"`,
  `"pearson"`, `"spearman"`, `"kendall"`, `"deviance_gap"`, `"none"`),
  `background_by`, `annotations`, `order`, `display`, `group`,
  `focus_by`, `focus_threshold`, `axes` and `style`. Unknown names in
  `...` are an error. The non-linearity colour scale runs from 0 to the
  observed maximum, with a floor of 1.
* `plot()` and `janusplot()` gain `background_by` (`"pearson"`,
  `"spearman"`, `"kendall"` or `"none"`): each cell's background is tinted
  by the pair's signed correlation, white at 0 and deeper blue or red
  towards -1 and 1, with a colour bar marked at 0.
  `janusplot_style(background_palette = , background_strength = )` set the
  palette and the depth at |r| = 1. Left unset, the background is Pearson
  for a marginal fit and absent for a fit with `adjust`, whose curves are
  adjusted while the correlation is marginal; `background_by` set
  explicitly still draws it, and the glossary labels it marginal.
* `annotations` accepts `"n"` (the rows used), `"r"` (the background
  correlation, `r -0.03`) and `"formula"` (`Temp ~ Ozone`) beside `"A"`,
  `"edf"`, `"signif"`, `"code"`, `"shape"` and `"k_warn"`. For a fit with
  `adjust` the strip prints `marginal r -0.03`: the curves are adjusted,
  the correlation is not.
* The top-left corner of the matrix carries a key: a two-by-two schematic
  of the first two variables headed "each cell: row ~ s(column)"
  (`janusplot_style(show_key = )`). When either name is longer than seven
  characters, the key reads `v1` and `v2`.
* `janusplot_style()` collects every appearance knob into one validated
  object with a `print()` method listing the values changed from their
  defaults.
* `janusplot_style(text_size = )` sets every text in points: `"auto"`
  scales with the variable count and keeps the strip at 5 points or more, a
  number sets a base size, and a named list sets `strip`, `labels`,
  `diagonal`, `legend`, `key`, `glossary`, `title` or `axis` one by one,
  where `NULL` removes that text. `border_width`, `curve_width` and
  `base_family` complete the publication settings; the default coloured
  border is twice as thick as before.
* `group =` colours the raw points of every cell by a factor, character
  or logical column of `fit$data` with `janusplot_style(group_palette = )`
  (`"Okabe-Ito"` by default, resolved through
  `grDevices::palette.colors()`), with one legend below the matrix. The
  column never enters the model; an error names a column that is absent
  or has more than `group_max_levels` levels.
* Cells with more than `janusplot_style(density_threshold = )` rows
  (2000 by default) draw the raw points as a light grey binned density
  (`ggplot2::geom_bin2d()`, 40 bins) instead of points.
* `p_adjust = c("none", "BH", "holm")` adjusts the smooth F-test p-values
  once across the `k(k - 1)` directed cells with `stats::p.adjust()`.
  `association_p_adj` columns (and `association_p_adj_yx` / `_xy` fields)
  hold the result, equal to the raw values under `"none"`; the `signif`
  glyph reads the adjusted value.
* `directional_complexity` is the signed version of the asymmetry index,
  `(EDF_yx - EDF_xy) / (EDF_yx + EDF_xy)`, positive when the fit of the
  later variable on the earlier one is the more complex direction; each
  table row carries it signed for that cell, and `asymmetry_index` is its
  magnitude.
* `shape_borderline` gives the smallest gap between a shape index and a
  classification cutoff whose crossing by that index alone would change
  the label (`M` and `C` against their cutoffs, the flat-range ratio
  against `flat`), on the index's own scale. A label decided by the
  turning-point and inflection counts (`u_shape` and the other
  single-extremum labels, the waves) reports its gap to the `flat`
  cutoff; the value is `NA` only for an `indeterminate` label or a
  missing flat-range ratio. Small values mark labels a slightly different
  smooth would have moved.
* `janusplot_pair(fit, x, y)` draws the two directions of a pair side by
  side: `y ~ s(x)` on the left and `x ~ s(y)` on the right, whichever order
  the fit stored the pair in. Each panel carries its raw points, band and
  curve, axis titles and tick labels, the model formula with the fit's
  `adjust` terms as its title, and a strip of the pair's statistics.
  `display = "d1"` and `"d2"` draw the derivative of each smooth, and
  `group` colours the points with a legend below the panels.
* `janusplot_pair()` draws any number of pairs: `x` and `y` as vectors, or
  a two-column data frame of pairs. Each pair is a block of two panels set
  close together, the blocks stack top to bottom (`nrow` blocks per stack)
  and the stacks sit side by side (`ncol` stacks), sharing text sizes and
  one legend. The panels take the signed correlation background
  (`janusplot_style(pair_background = )`) for a fit without `adjust`.

  ```r
  fit <- janusplot_fit(airquality[, c("Ozone", "Temp", "Wind")])
  janusplot_pair(fit, c("Temp", "Wind"), c("Ozone", "Ozone"))
  ```

* `janusplot_pair(display = "both")` overlays the two curves in one panel
  in the z-score plane of the pair's rows: `y ~ s(x)` in the curve colour
  and `x ~ s(y)` in orange with its axes swapped into the plane, under a
  strip giving `A` and both EDFs and glyphs by direction, and a key naming
  each colour by its formula.
* `janusplot_compare()` matches every directed cell of two `janusplot_fit`
  objects over the same variables by name and returns a
  `janusplot_compare` object whose `$table` gives, per cell, both `n_used`,
  both EDFs and their difference, both asymmetry indices and their
  difference, both shape labels and archetypes, and whether each changed
  (`NA` when either fit failed). Differences are the second fit minus the
  first; nothing is refitted. `print()` counts the directed cells and
  pairs whose shape label changed, lists those cells with shape, EDF and
  `A` before and after, and names any fit setting other than `adjust`
  (engine, method, `k`, `bs`, `n_grid`, shape cutoffs) that also differs.
  `plot()` draws the matrix with both curves in every cell: the first fit
  as a grey dashed curve, the second as the solid curve with its band over
  its raw points, optionally coloured by `group`. The strip reads
  `EDF a -> b` and a red border marks the cells whose shape label changed.
  The comparison reports how sensitive each fitted shape is to the
  adjustment.

  ```r
  vars  <- c("bill_length_mm", "bill_depth_mm", "flipper_length_mm",
             "body_mass_g")
  fit_a <- janusplot_fit(palmerpenguins::penguins, vars)
  fit_b <- janusplot_fit(palmerpenguins::penguins, vars, adjust = ~ species)
  cmp   <- janusplot_compare(fit_a, fit_b,
                             labels = c("marginal", "species-adjusted"))
  cmp
  plot(cmp, group = "species")
  ```

* `janusplot_direction()` returns a `janusplot_direction` object with a
  `print()` method giving the verdict and the direction it names, the
  reason, the two HSIC p-values labelled by direction and `n_used` of `n`.
  The test is bivariate: when the fit was made with an `adjust` formula
  the adjust terms do not enter the two direction fits, and a message
  says so; only the rows they select carry over.
* When the fit keeps its models (`keep_fits = TRUE`), was made with
  `engine = "gam"` and no `adjust` formula, and no subsample is drawn,
  `janusplot_direction()` reads the residuals, EDFs and fitted values of
  the kept models instead of refitting; the result is identical to the
  refit.
* `janusplot_shape_sensitivity()` returns a `janusplot_sensitivity` data
  frame. `summary(x, level = c("fine", "archetype"))` aggregates it to one
  mean-accuracy row per `(truth, n, sigma)` cell and
  `plot(x, type = c("confusion_fine", "confusion_archetype", "accuracy_grid",
  "recovery_curves"))` draws the four diagnostics. Both methods read only
  the result columns, so a plain data frame with those columns works when
  the method is called by name. The shipped `shape_sensitivity_demo` data
  carry the class: they are regenerated by `data-raw/shape_sensitivity_demo.R`
  through the new runner with the same seed (2026), and every row is
  unchanged.
* Three shape categories are added, `skewed_trough`, `broad_trough` and
  `rippled_trough`, bringing the taxonomy to 27 categories. The taxonomy
  is now closed under reflecting `y`: replacing `y` with `-y` maps every
  single-extremum category onto its mirror, and the peak family was the
  only one that lacked its reflection. The new categories belong to the
  `unimodal` archetype, carry the codes `st`, `bt` and `rt`, and appear in
  the shape legend as reflections of the peak thumbnails.
* `janusplot_shape_metrics()` gains an `extremum_type` component
  (`"minimum"`, `"maximum"` or `NA`).

## Bug fixes and robustness

* Model formulas longer than 32 characters wrap after `~` in the titles
  and strips of `janusplot_pair()`, so neighbouring panels no longer
  overlap. Points coloured by `group` are drawn at an opacity of at least
  0.5 so the colours stay distinguishable. The matrix title reads
  "Fitted curves" in place of "Direct fit".

* Column names that are not syntactic R names (`"grain yield (t/ha)"`,
  `"N-rate %"`, `"2019_yield"`) no longer fail every cell. `janusplot_fit()`
  and `janusplot()` fit them under internal aliases and report the original
  names in labels, returned tables and messages; `adjust` refers to them with
  backticks.
* Character and logical columns named in `adjust` are converted to factor
  before fitting, with a message naming them, so `adjust = ~ site_year` and
  `adjust = ~ s(site_year, bs = "re")` work on a character grouping column.
* Infinite values are treated as missing before pairwise or listwise deletion.
  A warning gives the number removed per column, and `n_used` counts only the
  rows that remain.
* A pair sharing fewer than 5 complete rows is still drawn as an "n < 5" cell
  while the rest of the matrix renders, and the per-matrix warning lists
  every such pair with its shared-row count. An error is raised only when no
  pair reaches 5 rows.
* Identical or exactly collinear column pairs are detected before fitting. Their
  cells fail with a message naming both columns and the cause, in place of an
  uninformative error from the model fit.
* Predictors with fewer than 10 distinct values are fitted at the default
  `k`. For each ordered pair the basis dimension is capped at the number of
  distinct predictor values in that pair's complete rows, so a fertiliser
  rate with five levels no longer fails, and a per-variable `k` no longer
  fails when pairwise deletion leaves a pair with fewer distinct values
  than the chosen `k`. Capped cells are named in one message per call, and
  the `auto_refit_k` refit stays within the cap.
* Each fit records `k_requested`, `k_used` and `k_capped`. They appear per
  direction in `fit$pairs` (`k_requested_yx`, `k_used_yx`, `k_capped_yx` and
  their `_xy` counterparts) and per cell in `summary(fit)`.
* Capping the basis dimension in one direction inflates the asymmetry
  index A. Every pair-level output carries `k_capped_yx` and
  `k_capped_xy` beside A, the `"k_warn"` annotation also marks capped
  cells, and the documentation states that A is unreliable when either
  direction is capped.
* With a random effect in `adjust` (`s(g, bs = "re")` or a factor smooth
  `bs = "fs"`), the fitted curve, its confidence band and the derivative
  curves are predicted at the population level. 0.2.0 predicted them at
  the most frequent group, with that group's random effect and band width.
* `fit$pairs` gains `prediction_reference_yx` and
  `prediction_reference_xy`, recording for each `adjust` variable the
  value or level held fixed on the prediction grid, or that it was
  excluded as a random effect. Each internal fit carries the same record.
* `colour_by = "deviance_gap"` encodes a gap: the deviance explained by
  the smooth minus the deviance explained by the straight-line fit of the
  same ordered pair, bounded in [0, 1]. 0.2.0 showed deviance explained.
  The legend reads "Dev. gap". Deviance explained remains in `dev_exp`;
  the gap is `deviance_gap` in `summary(fit)` and `deviance_gap_yx` /
  `deviance_gap_xy` in `fit$pairs`.
* `janusplot_direction()` takes `n_min` (default 30) and `n_max`
  (default 2000). Below `n_min` complete cases the verdict is
  `"undecided"` with reason `"n below n_min"`; above `n_max` rows are
  subsampled reproducibly, seeded by `seed` or by 2026 when `seed` is
  `NULL`, without changing the global random-number state. The rows used
  are returned as `n_used`.
* `janusplot_direction()` accepts column names with spaces or symbols and
  reports them as supplied.
* The `janusplot_fit()` documentation states the `_yx` / `_xy`
  convention: `_xy` is the fit `vars[i] ~ s(vars[j])` for `i < j` (upper
  triangle, row `i`, column `j`) and `_yx` is `vars[j] ~ s(vars[i])`
  (lower triangle).
* A curve with a single turning point is labelled by the type of that
  extremum, read from the sign of the first derivative on either side of
  it. A minimum gives `u_shape`, `skewed_trough`, `broad_trough` or
  `rippled_trough` for 0, 1, 2 or 3+ inflections; a maximum gives
  `inverted_u`, `skewed_peak`, `broad_peak` or `rippled_peak`. 0.2.0
  applied `skewed_peak`, `broad_peak` and `rippled_peak` to minima as well
  as maxima, and a density-weighted convexity index could flip `u_shape`
  and `inverted_u`.
* The `skewed_peak` and `rippled_peak` legend thumbnails are redrawn so
  that each one is classified as its own category.
* The `wave` and `bi_wave` ground-truth generators of
  `janusplot_shape_sensitivity()` are corrected. Both carried a
  quarter-period phase shift that placed a trough at each end of
  `[0, 1]`, so `wave` had a single interior maximum (a broad peak) and
  `bi_wave` had three interior extrema (a bimodal curve). They now use
  zero phase: `wave` has one maximum and one minimum, and `bi_wave` has
  four interior extrema.
* `shape_sensitivity_demo` is regenerated with the recorded seed (2026)
  under the corrected generator and the extremum-type classifier. `wave`
  recovery rose from 0% to 96.9% exact and 97.8% by archetype, which
  lifted the overall figures from 70.1% to 86.2% exact and from 76.9% to
  93.1% by archetype. The other five shapes are unchanged. The
  shape-recognition-sensitivity vignette is updated to match, including a
  corrected verdict for hypothesis H2.
* Derivative cells keep the dashed zero line inside the panel: the
  y-range is expanded to include 0 with `ggplot2::expand_limits()` when
  the curve and its band sit entirely on one side, so a monotone cell no
  longer loses the reference line off the panel edge.
* `print()` on a fit or a comparison of two variables reads "1 pair".
* The colour bars set their layout through the `theme` argument of
  `ggplot2::guide_colourbar()`, so drawing a matrix raises no ggplot2
  deprecation warning.
* `DESCRIPTION` drops the `Remotes:` field, which a CRAN submission cannot
  carry. `kernR (>= 0.8.0)` stays in `Suggests:` and resolves through
  `Additional_repositories: https://max578.r-universe.dev`.
* `DESCRIPTION` names the 27-category shape taxonomy.
* A `family` with a non-identity link, passed through `...`, now draws the
  curve and its band on the response scale, beside points on the same
  scale. The band is formed on the link and mapped through the inverse
  link. The derivatives, shape indices and shape label describe the
  linear predictor, and the prediction grid carries it as `fit_link`.
  The fit records `family`, `link`, `discrete` and `nthreads` in
  `settings`, and `janusplot_compare()` names a difference in any of them.
* A column that is constant on a pair's rows is named in that cell's
  error, in place of mgcv's "NA/NaN/Inf in foreign function call".
* `derivative_ci = "simultaneous"` leaves the caller's random-number state
  where it was.
* `k_capped` is also `TRUE` when an `auto_refit_k` refit stops at the
  distinct-value cap.
* `shape_borderline` is `NA` for a label decided by the turning-point and
  inflection counts. It used to report the distance to the `flat` cutoff,
  which says nothing about how near a count is to changing.
* `print()` shows each direction's EDF and p-value (adjusted when the fit
  adjusted) beside its shape label, and marks a label "n.s." when that
  p-value is 0.05 or more. The strip does the same for a shape code or
  glyph. Labels in `summary()` are unchanged.
* With `adjust`, `janusplot_direction()` reports how many rows it used
  and that rows missing an `adjust` variable are left out. When both
  residual tests are independent but the two variables are correlated,
  the reason says the association is present and its direction is not
  identified.

# janusplot 0.2.0

* janusplot is now released under the MIT licence. Versions up to 0.1.1
  were released under GPL (>= 3).

* README lists related packages.

* The test covering the `parallel = TRUE` diagnostic now installs a
  sequential `future` plan for its duration and restores the previous
  plan afterwards, instead of setting the `future.plan` option. `future`
  consults that option only while initialising its own plan, so on a
  machine whose R startup profile has already called
  `future::plan("multisession")` the option changed nothing: two workers
  stayed active, `janusplot()` rightly stayed quiet about falling back to
  sequential dispatch, and the test recorded a failure against correct
  behaviour. The same suite came back clean under `R CMD check`, where
  such startup profiles conventionally stand aside, and reported one
  failure in 504 when run from `Rscript` -- a difference in the machine,
  not in the package. The suite-wide setup file carried the identical
  inert option and now installs the sequential plan directly, so the
  intent to keep test runs single-worker is actually met.


* A per-cell GAM fit that errors (e.g. a constant predictor) now carries
  its error message into both public returns (`janusplot(with_data =
  TRUE)$data$error` and `janusplot_data()$pairs[[i]]$error_yx` /
  `error_xy`), reports `n_used = NA` rather than the row count offered to
  a fit that never completed, and raises one warning per matrix
  summarising the failed cells.
* New `janusplot_direction_test()`. The package could already show that
  a pair's two directions of fit differ, and that asymmetry is what
  invites a directional reading of the matrix; what it could not do was
  check the condition that licenses such a reading. Under the additive
  noise model a direction is supported only when the residuals of the
  fit in that direction are independent of the putative cause, and the
  residuals of the fit the other way round are not. The new function
  fits both directions, tests each residual set against its putative
  cause with the kernel (HSIC) permutation test in `kernR`, and returns
  a verdict of `forward`, `reverse` or `undecided` alongside both
  p-values and both test statistics. It abstains rather than ranking the
  two p-values: when both directions admit an additive noise model, when
  neither does, and in the linear-Gaussian case -- where a linear model
  with Gaussian noise reproduces the joint distribution equally well
  read either way, so no direction is identifiable at all -- the verdict
  is `undecided`, and the reason returned with it says which of those
  situations produced it. `kernR` is a suggested dependency; where it is
  absent the function says so instead of falling back to a weaker rule.

* `janusplot_shape_metrics()`'s insufficient-data decline (fewer than 3
  finite predictor values) now raises a classed condition
  (`janusplot_refusal`/`orchestra_refusal`) instead of a bare error, so
  orchestra callers can recognise the decline programmatically.
* Vignette documentation pass: every figure chunk in both vignettes now
  carries a `fig.cap` and `fig.alt`, plus at least one interpreting
  sentence after the figure. The `\eqn{}` Rd macro left inert inside
  `janusplot.Rmd` (dropping two derivative formulas from the rendered
  text) is replaced with LaTeX math; the self-contradictory statement of
  the thin-plate penalty's effect on \eqn{\hat f'} vs \eqn{\hat f''}
  is corrected; the scale-invariance claim for `monotonicity_index` /
  `convexity_index` is corrected to hold under positive affine rescaling
  only (both indices sign-flip under `a < 0`); the "200 equally-spaced
  points" default-grid statement is corrected to 100 (200 only under
  `display %in% c("d1", "d2")`), matching the Limitations section.
* Fixed three factual errors in the quick-start and palette sections of
  `janusplot.Rmd`: EDF/asymmetry render bottom-left (not bottom-right),
  *n* is never rendered as an annotation, and the default cell fill is
  keyed to Pearson correlation, not EDF. The "changing the palette"
  worked example now sets `colour_by = "edf"` so the three palettes it
  demonstrates actually differ under the default correlation encoding.
* `shape-recognition-sensitivity.Rmd` now adjudicates its four
  pre-registered hypotheses against the shipped demo data instead of
  stating an unadjudicated, and in one case refuted, headline claim; the
  `wave`/`bi_wave` ground-truth generator defect (tracked separately) is
  called out explicitly wherever it confounds a figure or a hypothesis,
  rather than left for the reader to notice. The "custom cutoffs" worked
  example now demonstrates on the monotone shape family, where
  `mono_strong`/`curv_low` are actually consulted by the classifier,
  instead of the wave/multimodal family where they are inert by
  construction. `simulation/PLAN.md` -- a path that does not exist in
  the installed package -- is no longer cited; the four hypotheses are
  inlined instead. The `shape_sensitivity_demo` documentation (roxygen
  and vignette) now states "6 shapes across 5 archetypes", correcting
  "one per non-degenerate archetype" (`u_shape` and `inverted_u` are
  both `unimodal`).
* README: added a one-line purpose statement ahead of the badges. The
  installation section now gives the CRAN install first.
* `kernR`, a suggested dependency, is installable from
  <https://max578.r-universe.dev> (`Additional_repositories`).
* The insufficient-data refusal of `janusplot_shape_metrics()` now names
  the predictor in its message; it previously printed the unexpanded
  template.

# janusplot 0.1.1

### v0.1.1 NUMERICAL-SHIFT NOTICE (engine default change)

**v0.1.1 changes the default GAM fitting backend from `mgcv::gam`
to `mgcv::bam`** (Feature 4 below). `bam` uses fREML estimation
instead of REML, which differs by ~1-3% in effective degrees of
freedom on identical data. **Existing v0.1.0 users will see
slightly different EDFs, asymmetry indices, and per-cell colour
fills when they upgrade.** This is the single non-byte-identical
change in v0.1.1 — every other v0.1.1 feature is strictly additive.

**Recovery.** Set `engine = "gam"` on `janusplot()` or
`janusplot_data()` to reproduce v0.1.0 numerical output verbatim.
The package's vdiffr visual-regression suite pins
`engine = "gam"` for exactly this purpose — every old snapshot
remains valid under the backward-compat escape.

### v0.1.1 Feature 4 — Default fitting engine = `bam` (with `gam` escape)

* **New `engine = c("bam", "gam")` argument**, default `"bam"`.
  At janusplot's scale (k = 15-25 vars, 600+ fits per call)
  `mgcv::bam`'s block-Lanczos solve + fREML estimation delivers
  ~3-10x wall-time speedup vs `mgcv::gam` without any new
  dependency (`mgcv` already exports both).
* **fREML vs REML.** `bam` defaults to fREML (fast REML); `gam`
  defaults to REML. The two methods optimise the same penalty
  target via different paths — EDFs differ by ~1-3% on identical
  data. v0.1.1 surfaces this as the one numerical break with
  v0.1.0, documented prominently above.
* **`method` argument default is now `NULL`**, resolved
  per-engine: `"fREML"` for bam, `"REML"` for gam. Users who
  passed `method` explicitly in v0.1.0 see no behaviour change.
* **`discrete = FALSE` (bam-only)** — opt-in to mgcv's
  covariate-discretisation optimisation. Further ~2-5x speedup
  at sub-pixel prediction shift cost.
* **`nthreads = 1L` (bam-only)** — intra-fit threading. Default
  1 to avoid oversubscription when combined with `parallel =
  TRUE` (which fans out across pair-fits already).
* **`engine` + `method` provenance** — both columns now appear
  in `janusplot(..., with_data = TRUE)$data` and on every
  `janusplot_data()$pairs[[i]]` entry. Useful for paper figures
  whose methodology section needs to document which backend
  produced the EDFs they report.
* **`bam` inherits from `gam`** — `class(bam_fit)` is
  `c("bam", "gam", "glm", "lm")`, so `mgcv::k.check()`,
  `predict.gam()`, derivative LP-matrix arithmetic, and every
  shape-metric extractor work without modification. Engine is
  plumbing, not redesign.
* **vdiffr suite pinned to `engine = "gam"`** so every legacy
  visual snapshot continues to validate under the v0.1.0
  backward-compat escape. Acts as a regression gate on the
  `engine = "gam"` recovery path.

### v0.1.1 Feature 3 — Axes rendering modes + figure-to-file output

* **`axes`** rendering knob with four modes:
  `"original"` (default), `"standardised"`, `"centred"`, `"rank"`.
  Applied per variable from raw data; same transform propagates
  consistently to (a) raw scatter, (b) spline prediction grid,
  (c) CI ribbon, and (d) the matrix-border variable label
  (`"mpg (z)"`, `"mpg (centred)"`, `"rank(mpg)"`).
* **Rendering-only invariant.** The underlying `mgcv` fits are
  byte-identical across modes — verified in
  `tests/testthat/test-axes.R` via direct column comparison of
  `with_data` output across all four modes on a non-linear DGP.
* **At-k coverage.** The new test suite renders every
  `(k, mode)` combination across `k ∈ {2, 5, 10, 15, 20, 26}`
  and `mode ∈ {original, standardised, centred, rank}` —
  24 panels — and asserts none emit warnings. Border-label
  suffixing is independently verified at `k ∈ {3, 12, 20}` by
  walking patchwork's plot list and matching against the
  expected suffix pattern.
* **Tier-3 no-op.** At compact tier 3 (`n_var >= 25`) the cells
  render only colour fill + shape-class glyph (no curve, no
  scatter), so `axes` is a documented no-op there. The border
  labels still pick up the mode suffix so the user can tell
  which transform they're looking at.
* **`save_as = NULL`** — new file-output knob. When set to a
  path with extension, writes the assembled matrix to disk via
  [ggplot2::ggsave()]; the device is inferred from the
  extension. Supported: `.png`, `.pdf`, `.svg`, `.jpg` /
  `.jpeg`, `.tif` / `.tiff`, `.eps`, `.ps`, `.bmp`. The
  function still returns the ggplot — the file is a side-effect.
* **`save_width` / `save_height` / `save_dpi`** — overrides
  for the auto-resolved square (`pmax(6, 0.65 * k_n)` inches,
  300 dpi for raster). Useful when targeting a fixed-size
  R Journal figure.

### v0.1.1 Feature 2 — Scale-aware compact rendering

* **Progressive content tiers.** New `compact` argument with values
  `"auto"` (default), `"always"`, and `"never"`. Under `"auto"`,
  each matrix renders at a tier resolved from the pixel-budget
  ladder:
  * Tier 0 (`n_var < 12`) — v0.1.0 behaviour: spline + CI + scatter
    + every annotation.
  * Tier 1 (`12 <= n_var < 18`) — drop raw scatter; keep spline,
    CI, colour fill, and at most one annotation (`k_warn` if it
    was requested).
  * Tier 2 (`18 <= n_var < 25`) — spline + colour fill only.
  * Tier 3 (`n_var >= 25`) — colour mini-tile + shape-class glyph
    at the cell centre; no spline.
* **Configurable ladder.** `compact_threshold = 12L` sets where
  Tier 1 begins; the full ladder shifts with it
  (`t2 = t1 + 6`, `t3 = t1 + 13`). Power users can override the
  ladder directly via `compact_levels = list(t1 = ..., t2 = ...,
  t3 = ...)`.
* **Backward-compat escape.** `compact = "never"` forces Tier 0 on
  any matrix, reproducing v0.1.0 output regardless of `n_var`.
  `compact = "always"` forces at least Tier 1 even at small
  `n_var` (useful for very dense fixed-size renders).
* **Focus filter (companion).** New `focus_by` argument accepts
  `NA` (default — no filter), `"asymmetry"`, `"edf"`,
  `"non_linearity"` (defined as `edf - 1`), or `"k_flag"`. Cells
  whose chosen metric falls below `focus_threshold` (default
  `"q90"`, a quantile string, or a numeric cutoff) are rendered in
  `grey85` at alpha `focus_dim_alpha` (default `0.25`). The matrix
  shape is preserved; attention drains visually to high-metric
  cells. This is a **visual filter, not a statistical one** — the
  underlying fits and the `with_data` table are unchanged.
* **Rendering-only knob.** Compact tier and focus mask are pure
  presentation layers. Fits, EDFs, asymmetry indices, shape
  classifications, k-check diagnostics, and the `with_data`
  summary table are byte-identical across `compact` settings — a
  regression-tested invariant.

### v0.1.1 Feature 1 — Per-cell k-checking (Strategy A always-on + Strategy B opt-in)

* **Diagnostic always on.** Every cell's fit now carries five new
  diagnostic fields derived from `mgcv::k.check()`: `k_prime`,
  `k_index`, `k_p`, `k_flag` (Wood's trifecta: `edf/k' > 0.9 &
  k-index < 1 & p < 0.05`), and `k_check_status` (`"ok"`,
  `"flagged"`, `"unreliable"`). Cells with `n_unique(x) < 10` are
  marked `"unreliable"` rather than flagged — `k.check()`'s
  simulation p-value is meaningless at very low unique-x.
* **Opt-in auto-refit.** New `auto_refit_k = FALSE` (default) and
  `k_max_iter = 2L` arguments on `janusplot()` and `janusplot_data()`.
  With `auto_refit_k = TRUE`, every flagged cell is refit with a
  doubling-k loop until either the flag clears, the per-cell
  unique-x cap is reached, or `k_max_iter` iterations have passed.
  Refit trajectory persisted on each cell: `k_initial`, `k_final`,
  `k_iterations`, `k_at_cap`.
* **Configurable thresholds.** New `k_check_thresholds =
  list(edf_ratio = 0.9, k_index = 1.0, p = 0.05)` argument.
  Defaults track `mgcv::gam.check()` and Wood (2017) §5.9.
* **Console summary.** A 3-line `cli::cli_inform()` summary fires at
  the end of `janusplot()` / `janusplot_data()` whenever at least
  one cell is flagged: total flagged, chance-expected count under
  α = 0.05, and a recovery hint pointing at either
  `auto_refit_k = TRUE` or `k_max_iter`. Quiet on clean datasets.
* **Cell annotation.** New `"k_warn"` entry in the `annotations`
  vocabulary on `janusplot()`. When included, flagged cells render
  a red `!` (ASCII) or `⚠` (Unicode) in the top-left corner.
  Off by default — opt in with `annotations = c("edf", "A", "k_warn")`.
* **Summary-table extension.** `janusplot(..., with_data = TRUE)$data`
  gains 9 new columns: `k_prime`, `k_index`, `k_p`, `k_flag`,
  `k_check_status`, `k_initial`, `k_final`, `k_iterations`,
  `k_at_cap`.
* **RNG isolation.** `mgcv::k.check()` runs its own simulation
  (default `n.rep = 400`) for the basis-deficiency p-value. The
  diagnostic's RNG draw is now isolated via an internal
  seed-preservation helper, so it does not shift downstream Monte
  Carlo consumers — `derivative_ci = "simultaneous"` bands and
  `future.seed = TRUE` reproducibility are unaffected.


# janusplot 0.1.0

## First CRAN release (2026-04-23)

Initial public release of `janusplot`. The package renders a pairwise,
asymmetric smoothed-association matrix of continuous variables, with each
cell showing the fitted spline from an `mgcv` generalised additive model.
Upper-triangle cells plot `gam(x_j ~ s(x_i))`; lower-triangle cells plot
`gam(x_i ~ s(x_j))`. The intentional asymmetry surfaces heteroscedasticity,
leverage, and directional non-linearity that a single scalar correlation
hides.

Public surface includes:

* `janusplot()` — the matrix-plot entry point, with per-cell fit / CI /
  raw-data controls, hclust-ordered variables, random-effects adjustment
  via `s(g, bs = "re")`, and opt-in parallel fits via `future.apply`.
* `janusplot_data()` — sibling returning the fitted-model metadata
  (EDF, F-test p, asymmetry index, shape classification) without
  rendering.
* `janusplot_shape_metrics()` + `janusplot_shape_cutoffs()` +
  `janusplot_shape_hierarchy()` — the 24-category shape taxonomy.
* `janusplot_shape_sensitivity()` + helpers — recovery-rate simulation
  over 12 ground-truth shapes × 7 sample sizes × 500 replicates, with
  the precomputed `shape_sensitivity_demo` dataset for quick inspection.

The remainder of this file documents pre-release development history,
retained for provenance.

---

# janusplot 0.0.0.9001 (development)

### AAGI-preset audit fixes (2026-04-22)

User-visible changes:

* **`data.table` dependency removed.** `janusplot(..., with_data = TRUE)$data`
  and any other tabular returns are now always a plain `data.frame` — no
  runtime or documented fallback to `data.table::as.data.table()`. The
  package charter bans `data.table` as a dependency (plotting function,
  overhead unearned). `data.table` is no longer listed in `Suggests:`.
* **Documentation example cleanup.** The `janusplot()` example no longer
  passes `show_asymmetry = TRUE` (which has been deprecated since
  `0.0.0.9000` and emitted a soft deprecation warning on every example
  render). The default `annotations = c("edf", "A")` already surfaces the
  asymmetry index, so the example is materially unchanged.

Internal / house-style fixes:

* **`match.arg()` → `rlang::arg_match()`** in the two remaining sites
  (`.shape_glyph()` in `R/shape-metrics.R` and `.display_title()` in
  `R/janusplot.R`). Brings every enumerated-argument gate to the same
  `rlang` discipline CONTRIBUTING already documents. Function signatures
  updated so the enum set lives on the formal default (as
  `rlang::arg_match()` requires).
* **`@family` tags added to 7 exports** — `janusplot_shape_cutoffs()`,
  `janusplot_shape_hierarchy()`, `janusplot_shape_metrics()`,
  `janusplot_shape_sensitivity()`, `janusplot_shape_sensitivity_shapes()`,
  `janusplot_shape_sensitivity_summary()`,
  `janusplot_shape_sensitivity_plot()`. The `_pkgdown.yml` reference
  index now organises these two families (`shape-metrics` and
  `shape-sensitivity`) alongside the existing `smooth-associations`
  family, replacing an alphabetical dump.
* **`inst/WORDLIST` extended** with the 24 Phase-F shape-category names
  (`linear_up`, `linear_down`, `convex_up`, `convex_down`, `concave_up`,
  `concave_down`, `s_shape`, `u_shape`, `inverted_u`, `skewed_peak`,
  `broad_peak`, `rippled_peak`, `rippled_monotone`, `rippled_wave`,
  `warped_wave`, `complex_wave`, `bimodal_ripple`, `bi_wave`,
  `bi_wave_ripple`, …). Keeps `devtools::spell_check()` clean.
* **`inst/CITATION` Article bibentry** now carries `email=` and
  `comment = c(ORCID = ...)` for consistency with the Manual bibentry,
  `CITATION.cff`, and `codemeta.json`.
* **Version pins harmonised** across `DESCRIPTION`, `CITATION.cff`, and
  `inst/CITATION` at `0.0.0.9001`.

Deferred to a later maintenance sweep (not blocking 0.0.0.9001):

* `renv.lock` snapshot.
* `covr::package_coverage() > 0.85` CI-side floor assertion.
* `adr/` relocation to `docs/adr/`.

### Legend height tracks matrix height (2026-04-22)

* **Colour-bar flex-fills vertical extent.** Removed the fixed
  `barheight = grid::unit(0.6, "npc")` override inside the
  `guide_colourbar()` for both diverging and sequential scales, and set
  `legend.key.height = grid::unit(1, "null")` in the legend plot's
  theme. The bar now tracks the matrix panel height robustly across
  figure sizes (corrplot-like behaviour), closing the visible
  proportional-scaling mismatch that appeared between narrow and wide
  renders. Added a thin `frame.colour = "grey50"` around the bar for
  visual weight.

### Lifecycle badge SVGs shipped (2026-04-22)

* **`man/figures/lifecycle-*.svg` added.** Running
  `usethis::use_lifecycle()` copied `lifecycle-experimental`,
  `lifecycle-stable`, `lifecycle-superseded`, and
  `lifecycle-deprecated` into `man/figures/`. The HTML help pages for
  every `lifecycle::badge()`-tagged function now render the badge
  instead of the broken-image placeholder (`?` in a box) that appeared
  when the SVG file was absent.

### Derivative views — single-display mode + Simpson 2018 MC CIs (2026-04-22)

* **New `display` parameter on `janusplot()`.** Scalar — one of
  `"fit"` (default, unchanged behaviour for legacy callers),
  `"d1"`, or `"d2"`. Controls which single quantity is rendered in
  every off-diagonal cell of the matrix. A matrix-level title
  (`"Direct fit"`, `"First derivative f'(x)"`, or
  `"Second derivative f''(x)"`) names the displayed quantity. To
  compare fit vs derivative, issue two or three `janusplot()` calls
  and place them side-by-side; each call keeps its own
  `with_data = TRUE` summary table, which now carries a `display`
  column tagging the rendered mode.
* **LP-matrix derivative estimation.** Derivatives computed
  analytically from `mgcv`'s linear-predictor matrix via
  `D %*% coef(fit)` with variance `D %*% Vp %*% t(D)`. The method
  of Wood (2017, §7.2.4), as popularised for GAMs by Simpson (2018,
  *Frontiers in Ecology and Evolution*). No new dependency
  (`gratia` is not required).
* **New `derivative_ci` parameter on `janusplot()` and
  `janusplot_data()`.** One of `"none"` (default), `"pointwise"`,
  or `"simultaneous"`. Default is `"none"` — no CI ribbon is drawn
  on derivative panels unless the caller opts in, because pointwise
  derivative ribbons over-read local features. `"pointwise"` draws
  `fit ± 1.96 * se` from the LP-matrix SE. `"simultaneous"` draws
  Monte Carlo critical-multiplier bands per Simpson (2018): draw
  $\tilde{\boldsymbol\beta}_b \sim N(\hat{\boldsymbol\beta}, V_p)$
  and use the $(1-\alpha)$ quantile of the normalised max-deviation
  statistic as the critical multiplier on the pointwise SE.
* **New `derivative_ci_nsim` parameter.** Integer number of Monte
  Carlo samples used when `derivative_ci = "simultaneous"`. Default
  `1000L` (Simpson 2018 uses 10000; 1000 is a throughput-quantile
  accuracy compromise affordable for medium matrices).
* **New `n_grid` parameter on `janusplot()` and `janusplot_data()`.**
  Prediction-grid resolution. `NULL` (default) resolves to 100 when
  `display = "fit"` and 200 otherwise. Callers may override. Larger
  grids shift the shape-metric values (`M`, `C`, turning /
  inflection counts) slightly because they are computed on this same
  grid — a deliberate side-effect, flagged in `?janusplot` and in
  the Limitations section of the vignette. Shapes and asymmetry are
  the primary matrix reading; M/C/counts are secondary diagnostics.
* **New `derivatives` parameter on `janusplot_data()`.** Integer
  vector of orders in `1:2` (multi-order is allowed — unlike
  `janusplot()`'s scalar `display`, the data companion returns
  arbitrary requested orders in a single call). Every per-pair list
  in the return carries `deriv_yx` and `deriv_xy` named lists keyed
  by order, each a data frame with columns
  `x`, `fit`, `se`, `lo`, `hi`, `ci_type`. When
  `derivative_ci = "simultaneous"` each derivative frame also
  carries a `"crit_multiplier"` attribute.
* **New vignette section "Derivative views: theoretical
  justification and applied use"** — three worked examples (fit /
  d1 / d2) plus a simultaneous-CI demo; covers the LP-matrix
  variance propagation, noise amplification and the rationale for
  the order-2 hard cap, and two applied framings (gain-scheduled
  control; derivative-of-dose-response as the causal estimand of
  Zhang & Chen 2025). BibTeX for the section lives in
  `references/janusplot-derivatives.bib` for re-use in the R
  Journal paper.
* **Validation.** `display` enforces the scalar choice via
  `rlang::arg_match()`; `n_grid < 10` is an error and `n_grid > 500`
  raises an informational note. Orders ≥ 3 are refused by design —
  higher-order derivatives of penalised regression splines amplify
  noise beyond usable signal at realistic sample sizes (Eilers,
  Marx & Durbán 2015).
* **Breaking change from the interim development release.** An
  earlier in-development pattern allowed `display` as a vector
  (`display = c("fit", "d1")`) that stacked panels inside every
  cell. That pattern is removed; the scalar API is the only one
  supported. Callers that reached the stacked-panel intermediate
  must switch to one `janusplot()` call per quantity.

### Label placement — border vs. diagonal (2026-04-22)

* **New `labels` parameter** with three modes: `"border"` (default —
  variable names along the top + left margins, mirroring `corrplot`'s
  `tl.pos = "lt"` convention), `"diagonal"` (previous in-matrix
  layout), and `"none"` (suppressed). Default flipped to `"border"`
  because border labels free the diagonal cells and scale better to
  `k > 4` variables.
* **New `label_srt`** — rotation of top labels when
  `labels = "border"`. Default `45°` matches the visual reference;
  `0` and `90` are accepted.
* **New `label_cex`** — positive multiplier on border-label font
  size. Default `1`.
* Diagonal cells are now rendered as blank bordered panels whenever
  `labels != "diagonal"`, giving the matrix a uniform grid reading.

### Breaking: shape-metric column names (2026-04-21)

* User-facing `M` and `C` columns renamed to `monotonicity_index`
  and `convexity_index` across every data surface: the flat data
  frame from `janusplot(..., with_data = TRUE)`, `janusplot_data()`
  per-pair lists (`monotonicity_index_yx` / `convexity_index_yx` /
  `_xy` variants), the return of `janusplot_shape_metrics()`, the
  raw output of `janusplot_shape_sensitivity()`, and the precomputed
  `shape_sensitivity_demo` dataset. Paper symbols `M` / `C` remain
  as mnemonics in the documentation. Internal classifier parameter
  names (`M`, `C`) are unchanged because they match the math
  convention.
* New "Shape metrics explained" section in the `janusplot`
  vignette.
* Callers referencing `result$M` / `result$C` must update to
  `result$monotonicity_index` / `result$convexity_index`.

### Phase G — sensitivity study as a package feature (2026-04-21)

* **`janusplot_shape_sensitivity()`** — new public function that runs a
  full-factorial shape-recognition sensitivity sweep (shapes ×
  sample sizes × noise levels × replicates) and returns a tidy raw
  data frame. Optional parallel dispatch via `future.apply`.
* **`janusplot_shape_sensitivity_shapes()`** — lists the 14 canonical
  ground-truth shapes available to the sweep.
* **`janusplot_shape_sensitivity_summary()`** — per-cell accuracy
  aggregation at the fine (24-category) or archetype (7-family)
  level.
* **`janusplot_shape_sensitivity_plot()`** — four built-in
  diagnostic plots: fine / archetype confusion matrices, per-shape
  accuracy grid, recovery curves.
* **`shape_sensitivity_demo`** dataset — precomputed 2160-fit sweep
  shipped with the package so the vignette and examples don't need
  to re-run the sweep. Regenerated deterministically via
  `data-raw/shape_sensitivity_demo.R`.
* **New vignette** `shape-recognition-sensitivity.Rmd` — presents the
  sweep design, the pre-registered hypotheses, and every diagnostic
  plot on the precomputed demo dataset.
* `LazyData: true` in DESCRIPTION so `shape_sensitivity_demo` is
  accessible without an explicit `data()` call under default
  user expectations.

### Phase F — post-first-render revisions (2026-04-21)

* **Default correlation = Pearson** (switched from Spearman on the back
  of first-render review). Spearman + Kendall remain as `colour_by`
  options.
* **Colour-bar title simplified to `corr`** for all three correlation
  encodings; actual method remains visible in `janusplot_data()`
  column names and the caption.
* **Taxonomy expanded to 24 categories** via `(T, I)` dispatch. New
  fine categories: `skewed_peak`, `broad_peak`, `rippled_peak`,
  `wave`, `warped_wave`, `rippled_wave`, `complex_wave`, `bimodal`,
  `bimodal_ripple`, `bi_wave`, `bi_wave_ripple`, `rippled_monotone`.
* **Shape-types legend redesigned** — now renders every category as a
  canonical 1-cm thumbnail spline in a 6-column grid below the matrix
  (font-independent, full-width). Each panel is labelled
  `label (code)`. The old right-margin Unicode-glyph list is retired.
* **Cell glyphs off by default.** `annotations` default is
  `c("edf", "A")`; opt into per-cell shape markers with
  `annotations = c(..., "shape")` (glyph) or `annotations = c(..., "code")`
  (2-letter ASCII — safer on any font / PDF pipeline). When both are
  passed, `"code"` wins.
* **Hierarchy columns added to every output.** `janusplot(..., with_data)$data`
  gains `shape_code`, `shape_archetype`, `shape_monotonic`,
  `shape_linear`. `janusplot_data()` pairs gain per-direction
  `shape_code_yx` / `shape_code_xy` and the matching
  `shape_archetype_*`, `shape_monotonic_*`, `shape_linear_*`.
* **New public function `janusplot_shape_hierarchy()`** — returns the
  24-row taxonomy with hierarchy columns (`category`, `code`,
  `archetype`, `monotonic`, `linear`, `label`, `gloss`). Intended for
  downstream group-bys and for cross-referencing the compact 2-letter
  codes when they appear in cells or the data table.
* **Classifier is noise-robust.** Sign-change detection now uses
  lobe-mass-weighted accounting, so tail-noise wiggles on a smoothed
  saturating curve no longer inflate the inflection count into
  `complex`.

**Academic framing.** The broader-tier vocabulary (linear /
non-linear, monotone / non-monotone, convex / concave) is standard
calculus; the archetype layer is anchored by Pya & Wood (2015)
*Stat & Comput* (shape-constrained additive models) and Calabrese
(2008) *Env Tox Chem* (dose-response taxonomy). The `(T, I)` dispatch
is a coarsened Morse-theoretic critical-point classification
(Milnor 1963).

### Breaking / behaviour changes (2026-04-21 cell encoding redesign)

* **Default cell colour now encodes Spearman rank correlation.** The
  per-cell fill previously encoded EDF (non-linearity). It now encodes
  classical monotonic correlation via the new `colour_by` argument
  with a diverging `RdBu` palette symmetric around zero. Choose
  `colour_by = "pearson"` / `"kendall"` for other correlation flavours
  or `colour_by = "edf"` to restore the legacy encoding.
* **`fill_by` is deprecated** — use `colour_by`. When supplied,
  `fill_by` fires a soft deprecation warning and forwards to
  `colour_by` for one minor version.
* **Corner annotations switched to `annotations`** — a character
  vector (subset of `c("edf", "A", "shape")`) now controls which
  corner labels render on each cell. `"A"` (asymmetry index) replaces
  the old `n = ...` annotation; `"edf"` keeps EDF visible as text;
  `"shape"` draws the new shape-category glyph bottom-right.
* **`show_asymmetry` is deprecated** — use `annotations`. When
  supplied, the legacy argument fires a soft deprecation warning and
  is merged into `annotations`.

### New features

* **Objective shape descriptor** — every cell now carries two
  continuous indices (monotonicity `M`, convexity `C`), two discrete
  counts (`n_turning_points`, `n_inflections`), and a discrete
  `shape_category` from a 12-category taxonomy (`linear_up`,
  `linear_down`, `convex_up`, `concave_up`, `convex_down`,
  `concave_down`, `u_shape`, `inverted_u`, `s_shape`, `complex`,
  `flat`, `indeterminate`). Cutoffs are tunable via
  `janusplot_shape_cutoffs()`.
* **`janusplot_shape_metrics()`** — public function to compute the
  shape descriptor for any fitted `mgcv::gam` with a single `s()`
  term.
* **`janusplot_shape_cutoffs()`** — public function returning the
  default threshold list; callers override individual thresholds via
  `...`.
* **Shape-types legend** — when `annotations` includes `"shape"`, a
  compact legend listing every category present in the matrix is
  attached alongside the colour bar. Toggle with `show_shape_legend`.
* **Unicode / ASCII glyph switch** — new `glyph_style` argument
  (`"unicode"` default, `"ascii"` fallback) for pipelines that lack
  Unicode curve glyphs.
* **Extended data table** — `janusplot(..., with_data = TRUE)$data`
  gains columns `cor_pearson`, `cor_spearman`, `cor_kendall`,
  `tie_ratio`, `M`, `C`, `n_turning_points`, `n_inflections`,
  `flat_range_ratio`, `shape_category`, `colour_value`. The legacy
  `fill_value` column is renamed `colour_value`.
* **Extended `janusplot_data()` pairs** — each per-pair element gains
  Pearson / Spearman / Kendall correlations, tie ratio, and
  per-direction shape descriptors (`M_yx`, `C_yx`, `M_xy`, `C_xy`,
  `n_turning_*`, `n_inflect_*`, `shape_yx`, `shape_xy`).

## janusplot 0.0.0.9000

### New features

* `janusplot()` — asymmetric smoothed-association matrix visualisation.
  For each pair of numeric variables `(X_i, X_j)` with `i != j`, the
  cell at matrix position `[i, j]` renders the fitted spline from
  `mgcv::gam(X_j ~ s(X_i) + <adjust>)`. Upper and lower triangles show
  the two directional fits. Diagonal cells carry variable labels.
* `janusplot_data()` — programmatic companion returning raw GAM fits
  and per-pair metrics (EDF, F-test p-value, deviance explained,
  asymmetry index) without constructing a ggplot. Set
  `keep_fits = TRUE` to retain the full `mgcv::gam` objects.
* **Asymmetry index** — the per-pair single-number summary
  `|EDF_yx − EDF_xy| / (EDF_yx + EDF_xy)`, bounded in `[0, 1]`,
  exposed both via `janusplot_data()$pairs[[i]]$asymmetry_index` and
  (optionally) as a cell corner annotation via `show_asymmetry = TRUE`.
* **Partial smooths via `adjust =`** — any one-sided formula RHS
  (e.g. `~ s(z) + s(g, bs = "re")`) propagates to every pairwise
  GAM, producing covariate-adjusted smooths and supporting random
  effects out of the box.
* **`order = "hclust"`** — reorder variables by hierarchical
  clustering of `1 - |cor|` (matching the `corrplot` convention) to
  group strongly correlated variables visually.
* **`na_action = "pairwise"`** (default) vs `"complete"` — per-pair
  complete observations with annotated `n_used` per cell, vs listwise
  deletion.
* **Parallelism via `future.apply`** — set `parallel = TRUE` to
  dispatch pair fits across a user-configured `future::plan()`.
* **Colour palette choice** — `palette =` accepts one of 16 options:
  - viridis family (colourblind-safe sequential): `viridis` (default),
    `magma`, `inferno`, `plasma`, `cividis`, `mako`, `rocket`;
  - viridis high-contrast: `turbo` (not colourblind-safe);
  - ColorBrewer diverging (colourblind-safe): `RdYlBu`, `RdBu`, `PuOr`;
  - ColorBrewer diverging (not colourblind-safe): `Spectral`;
  - ColorBrewer sequential (colourblind-safe): `YlOrRd`, `YlGnBu`,
    `Blues`, `Greens`.
* **Shared right-margin colourbar legend** when `fill_by != "none"`,
  placed in a dedicated fixed-width column (1.8 cm) so cells remain
  square.
* **Cell annotations scale with `k`** — `n` and `EDF` labels shrink
  sublinearly as the number of variables grows, keeping small-cell
  plots legible.
* **Glossary caption** — a dynamic caption below the matrix explains
  the on-plot abbreviations (`n`, `EDF`, `A`, fill encoding, and
  significance glyphs), showing only the keys actually displayed.
* **`with_data = TRUE`** — optional flat per-cell summary table
  returned alongside the ggplot, as a `data.table` when the package
  is installed or a `data.frame` otherwise.

### Testing and quality

* 70 unit + integration tests; 5 `vdiffr` visual-regression snapshots.
* Passes `R CMD check --as-cran` with 0 ERRORs, 0 WARNINGs; 2 NOTEs
  remain (both environmental: new-submission status; local HTML Tidy
  version).
* Three-scenario simulation study validating the approach — linear
  recovery, non-linear detection, and heteroscedastic asymmetry.
  Scenario 3 is the paper's headline result: under a DGP with
  Pearson `r = 0.93`, `janusplot` recovers an asymmetry index ≈ 0.56
  (IQR [0.52, 0.65]), exposing hidden directional structure a
  scalar correlation misses.

### Dependency diet

Imports kept minimal: `mgcv`, `ggplot2`,
`patchwork`, `grid`, `stats`, `cli`, `rlang`. Optional: `data.table`,
`future.apply`, `vdiffr`, `withr`, `palmerpenguins`, `MASS`,
`agridat`, `knitr`, `rmarkdown`.
