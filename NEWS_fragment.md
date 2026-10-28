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
