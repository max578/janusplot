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
