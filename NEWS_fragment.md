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
