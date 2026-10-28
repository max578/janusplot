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
