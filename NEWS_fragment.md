* Column names that are not syntactic R names, such as `"grain yield (t/ha)"`,
  `"N-rate %"` or `"2019_yield"`, no longer fail every cell. `janusplot()` and
  `janusplot_data()` fit them under internal aliases and report the original
  names in labels, returned tables and messages; `adjust` refers to them with
  backticks.
* Character and logical columns named in `adjust` are converted to factor
  before fitting, with a message naming them, so `adjust = ~ site_year` and
  `adjust = ~ s(site_year, bs = "re")` work on a character grouping column.
* Infinite values are treated as missing before pairwise or listwise deletion.
  A warning gives the number removed per column, and `n_used` counts only the
  rows that remain.
* A pair sharing fewer than 5 complete rows is still drawn as an "n < 5" cell
  while the rest of the matrix renders, and the per-matrix warning now lists
  every such pair with its shared-row count. An error is raised only when no
  pair reaches 5 rows.
* Identical or exactly collinear column pairs are detected before fitting. Their
  cells fail with a message naming both columns and the cause, in place of an
  uninformative error from the model fit.

* `janusplot()` and `janusplot_data()` now fit predictors with fewer than
  10 distinct values at the default `k`. For each ordered pair the basis
  dimension is capped at the number of distinct predictor values in that
  pair's complete rows, so low-cardinality axes such as fertiliser rates
  no longer fail, and a per-variable `k` no longer fails when pairwise
  deletion leaves a pair with fewer distinct values than the chosen `k`.
  Capped cells are named in one message per call, and the `auto_refit_k`
  refit stays within the cap.

* Each fit now records `k_requested`, `k_used` and `k_capped`. They appear
  per direction in `janusplot_data()$pairs` (`k_requested_yx`,
  `k_used_yx`, `k_capped_yx` and their `_xy` counterparts) and per cell
  in the `with_data = TRUE` table.

* Capping the basis dimension in one direction inflates the asymmetry
  index A. Every pair-level output now carries `k_capped_yx` and
  `k_capped_xy` beside A, the `"k_warn"` annotation also marks capped
  cells, and the documentation states that A is unreliable when either
  direction is capped.

* With a random effect in `adjust` (`s(g, bs = "re")` or a factor smooth
  `bs = "fs"`), the fitted curve, its confidence band and the derivative
  curves are now predicted at the population level. Previously they were
  predicted at the most frequent group and carried that group's random
  effect and band width.

* `janusplot_data()` gained `prediction_reference_yx` and
  `prediction_reference_xy`, recording for each `adjust` variable the
  value or level held fixed on the prediction grid, or that it was
  excluded as a random effect. Each internal fit carries the same record.

* `colour_by = "deviance_gap"` now encodes a gap: the deviance explained by
  the smooth minus the deviance explained by the straight-line fit of the
  same ordered pair, bounded in [0, 1]. Previously it showed deviance
  explained. The legend reads "Dev. gap". Deviance explained remains in
  `dev_exp`; the gap was added as `deviance_gap` in the
  `janusplot(with_data = TRUE)` table and as `deviance_gap_yx` /
  `deviance_gap_xy` in `janusplot_data()`.

* `janusplot_direction_test()` gained `n_min` (default 30) and `n_max`
  (default 2000). Below `n_min` complete cases the verdict is
  `"undecided"` with reason `"n below n_min"`; above `n_max` rows are
  subsampled reproducibly, seeded by `seed` or by 2026 when `seed` is
  `NULL`, without changing the global random-number state. The rows used
  are returned as `n_used`.

* `janusplot_direction_test()` now accepts column names with spaces or
  symbols and reports them as supplied.

* The `janusplot_data()` documentation now states the `_yx` / `_xy`
  convention: `_yx` is the fit `vars[j] ~ s(vars[i])` (upper triangle,
  row `i`, column `j`) and `_xy` is `vars[i] ~ s(vars[j])` (lower
  triangle).

## Shape classification

* A curve with a single turning point is now labelled by the type of
  that extremum, read from the sign of the first derivative on either
  side of it, rather than by the sign of the convexity index or not at
  all. A minimum gives `u_shape`, `skewed_trough`, `broad_trough` or
  `rippled_trough` for 0, 1, 2 or 3+ inflections; a maximum gives
  `inverted_u`, `skewed_peak`, `broad_peak` or `rippled_peak`.
  Previously `skewed_peak`, `broad_peak` and `rippled_peak` were applied
  to minima as well as maxima, and a density-weighted convexity index
  could flip `u_shape` and `inverted_u`.
* Three categories were added, `skewed_trough`, `broad_trough` and
  `rippled_trough`, bringing the taxonomy to 27 categories. The
  taxonomy is now closed under reflecting `y`: replacing `y` with `-y`
  maps every single-extremum category onto its mirror, and the peak
  family was the only one that lacked its reflection. The new
  categories belong to the `unimodal` archetype, carry the codes `st`,
  `bt` and `rt`, and appear in the shape legend as reflections of the
  peak thumbnails.
* `janusplot_shape_metrics()` gained an `extremum_type` component
  (`"minimum"`, `"maximum"` or `NA`).
* The `skewed_peak` and `rippled_peak` legend thumbnails were redrawn
  so that each one is classified as its own category.

## Deprecated

* The `mono_nonmono`, `mono_s` and `curv_strong` cutoffs of
  `janusplot_shape_cutoffs()` were deprecated. The classifier never
  read them, so passing them had no effect on any label. They now
  raise a deprecation warning, are dropped from the returned list and
  no longer appear among the defaults or in the documentation.
  Classification is unchanged.

## Shape-sensitivity study

* The `wave` and `bi_wave` ground-truth generators of
  `janusplot_shape_sensitivity()` were corrected. Both carried a
  quarter-period phase shift that placed a trough at each end of
  `[0, 1]`, so `wave` had a single interior maximum (a broad peak) and
  `bi_wave` had three interior extrema (a bimodal curve). They now use
  zero phase: `wave` has one maximum and one minimum, and `bi_wave` has
  four interior extrema.
* `shape_sensitivity_demo` was regenerated with the recorded seed
  (2026) under the corrected generator and the extremum-type
  classifier. `wave` recovery rose from 0% to 96.9% exact and 97.8% by
  archetype, which lifted the overall figures from 70.1% to 86.2% exact
  and from 76.9% to 93.1% by archetype. The other five shapes are
  unchanged. The shape-recognition-sensitivity vignette was updated to
  match, including a corrected verdict for hypothesis H2.

