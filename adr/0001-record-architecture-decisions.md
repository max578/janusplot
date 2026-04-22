# 0001. Record architecture decisions

**Status.** Accepted · 2026-04-22.

## Context

janusplot is released as an R package with a small number of
architecturally load-bearing decisions (class system, dependency
surface, layout engine, asymmetry-index formulation). Tracking these
decisions in prose inside `PROJECT_LOG.md` has low discoverability
for anyone outside the active session and is chronological rather
than decision-indexed.

## Decision

Adopt lightweight ADRs under `docs/adr/` following the Nygard format
(Title · Status · Context · Decision · Consequences). One file per
decision, monotonically numbered. Edits are additive — a revision
records a new ADR that supersedes the old one; the old ADR is kept
verbatim for traceability.

## Consequences

- Load-bearing architecture decisions become searchable and stable
  under the package source tree.
- `PROJECT_LOG.md` remains a chronological project diary; ADRs
  capture the decisions that outlive the session notes.
- Cost: a few minutes per decision, mostly at design time.
- `docs/adr/` is already excluded from the built tarball via
  `^docs$` in `.Rbuildignore`.
