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
