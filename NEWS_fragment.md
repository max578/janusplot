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
