# Support

## Getting help

- **Bug reports + feature requests** — open an issue on GitHub using the
  templates under `.github/ISSUE_TEMPLATE/`.
- **Usage questions** — consult the package vignettes first
  ([`vignette("janusplot")`](https://max578.github.io/janusplot/articles/janusplot.md)
  and
  [`vignette("shape-recognition-sensitivity")`](https://max578.github.io/janusplot/articles/shape-recognition-sensitivity.md))
  and the pkgdown reference at <https://max578.github.io/janusplot/>
  (available after first release).
- **Security disclosures** — see `SECURITY.md` for the private channel.
  Please do not open public issues for security-sensitive reports.

## Maintenance capacity

**Primary maintainer.** Max Moldovan
([@max578](https://github.com/max578), ORCID 0000-0001-9680-8474),
Adelaide University.

**Time budget.** Approximately 2 hours per week on open-source
maintenance, best-effort. Response target: 14 days during normal
academic term, up to 30 days during teaching peaks or leave.

**Commitment horizon.** Active maintenance is committed through at least
2026-12-31, covering (a) the R Journal paper review cycle, (b) the first
CRAN release, and (c) one minor follow-up release. Post-2026, the
commitment is renewed annually if the package remains in active use.

**Bus factor.** 1. The package has a single primary maintainer. The
codebase is pure R with no compiled components; any R-literate
maintainer familiar with `mgcv` could take it over.

**Language-competence matrix.** R only — no C / C++ / Rust / Python. See
the “Maintainer competence matrix” section in `CONTRIBUTING.md`.

**Abandonment protocol.** If active maintenance becomes infeasible for
two consecutive release cycles, the maintainer will (1) mark the package
lifecycle as `superseded` or `deprecated`, (2) submit an
orphan-maintainer request to CRAN, (3) archive the GitHub repository,
and (4) announce the change in `NEWS.md`. The preferred handoff route is
via rOpenSci’s successor-maintainer programme.

## Contribution expectations

Please read `CONTRIBUTING.md` before opening a non-trivial pull request.
Issues are triaged before PRs; open an issue first to discuss proposed
changes of any substantive size.
