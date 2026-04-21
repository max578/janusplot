# Contributing to janusplot

Thanks for your interest. The short version: open an issue first, keep PRs small,
run the checks before you push.

## Filing an issue

- **Bug report** — use the bug-report issue form. Include a minimal reprex
  (`reprex::reprex()`), your `sessionInfo()`, and the exact error message or
  unexpected output.
- **Feature request** — use the feature-request issue form. Explain the
  intended use case before the proposed API.

## Submitting a pull request

1. Fork + branch from `main`. Branch names: `feat/<slug>`, `fix/<slug>`,
   `docs/<slug>`.
2. One logical change per PR.
3. Run the full `/rpkg check` quality gate locally:

   ```r
   devtools::document()
   devtools::test()
   devtools::check(args = "--as-cran")
   lintr::lint_package()
   covr::package_coverage()   # must stay >= 85%
   ```

4. Update `NEWS.md` under `# janusplot (development version)` with a bullet
   describing the user-visible change, and link the PR/issue number.
5. If you add or modify a public function, make sure the roxygen block has
   `@param`, `@returns`, an executable `@examples`, and a `@family`/`@seealso`
   tag.
6. Open the PR with the template pre-filled.

## House style

- snake_case throughout (package, functions, arguments, files).
- `cli::cli_abort()` / `cli_warn()` / `cli_inform()` with bare-symbol keys
  (`i = ...`), never `"i" = ...`.
- `rlang::arg_match()` for enumerated arguments (never `rlang::match_arg` —
  that function does not exist).
- `withr::local_*` when tests mutate global state.
- Integer literals `1L` when semantically integer.
- Australian English (`optimise`, `colour`, `behaviour`).

## Code of Conduct

Please note that the janusplot project is released with a [Contributor Code
of Conduct](CODE_OF_CONDUCT.md). By contributing to this project, you agree
to abide by its terms.
