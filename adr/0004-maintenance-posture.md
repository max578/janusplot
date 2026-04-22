# 0004. Maintenance posture — single maintainer, experimental lifecycle

**Status.** Accepted · 2026-04-22.

## Context

`/rpkg` v0.4 mandates honest disclosure of maintenance capacity
(see `SUPPORT.md` and the LLM-independence rubric). janusplot is
Adelaide-authored by a single maintainer with an academic time
budget and no funded open-source FTE. Transparent posture lets
users plan adoption.

## Decision

- Lifecycle stage for the whole package and every exported symbol:
  **experimental** until v1.0.0.
- Single primary maintainer (Max Moldovan). Bus factor: 1.
- Time budget ≈ 2 hours / week; response target 14 days in term,
  30 days in teaching peaks (see `SUPPORT.md`).
- Commitment horizon: through 2026-12-31 minimum; renewed annually.
- No paid-support channel.
- v1.0.0 promotion is conditional on:
  (a) R Journal paper acceptance,
  (b) first CRAN release with at least one minor-version follow-up,
  (c) no breaking change in the preceding two minor versions.

## Consequences

- Users can plan around the explicit bus-factor-1 posture — mirror
  the package, pin the version, run the replication bundle
  offline, etc.
- Contributions are welcome but not relied on for release cadence.
- Abandonment protocol is codified in `SUPPORT.md`.
- A rOpenSci or AAGI-AUS transition at a later date is explicitly on
  the table; see `CLAUDE.md` §3 for the project's distribution
  history.
