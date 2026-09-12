# tests/testthat/setup.R — env sanitisation + seed discipline.

# Deterministic RNG across tests. Seed pinned to 2026L to match paper
# replication bundle.
set.seed(2026L, kind = "default", normal.kind = "default",
         sample.kind = "default")

# Locale sanitisation — number formatting and string collation must be
# deterministic across machines to keep vdiffr + snapshot tests stable.
tryCatch({
  Sys.setlocale("LC_COLLATE", "C")
  Sys.setlocale("LC_NUMERIC", "C")
  Sys.setlocale("LC_TIME",    "C")
}, error = function(e) invisible(NULL))

# Env-var sanitisation — clear anything that could influence knitr,
# rmarkdown, future.apply, or tinytex during test runs.
Sys.unsetenv(c(
  "R_CHECK_LENGTH_1_LOGIC2",
  "R_CHECK_LENGTH_1_CONDITION",
  "KNITR_IN_PROGRESS",
  "RMARKDOWN_PREVIEW_DIR"
))

# Disable parallelism in tests unless a specific test opts in.
# The plan is installed directly rather than requested through
# options(future.plan = "sequential"): future reads that option only
# while initialising its own plan, so once a plan exists -- a startup
# profile calling future::plan("multisession") is enough -- the option
# is inert and the suite inherits whatever the session already had.
if (requireNamespace("future", quietly = TRUE)) {
  future::plan(future::sequential)
}

# vdiffr snapshot directory lives under tests/testthat/_snaps/ (default).
