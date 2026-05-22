#!/usr/bin/env Rscript
## post-cran-acceptance.R
##
## Run after the CRAN acceptance email for janusplot arrives.
## Idempotent: each step checks for prior completion before acting.
## Loud-on-failure: every external command is checked and aborts the
## script on non-zero exit. No silent "OK" after a failed step.
##
## Preconditions:
##   * cwd is the janusplot package root.
##   * Git working tree is clean; HEAD is on `main` and pushed to origin.
##   * `gh` CLI is authenticated with write access to max578/janusplot.
##   * `CRAN-SUBMISSION` exists (devtools-authored marker).
##
## What it does, in order:
##   1. Reads the submission SHA from `CRAN-SUBMISSION`.
##   2. Verifies that SHA is an ancestor of HEAD.
##   3. Creates an annotated git tag `v<version>` on that SHA.
##   4. Pushes the tag to origin.
##   5. Creates a GitHub release at v<version>, notes pulled from the top
##      section of NEWS.md.
##   6. Bumps DESCRIPTION Version to <version>.9000.
##   7. Prepends a "# <package> (development version)" heading to NEWS.md.
##   8. Commits and pushes the dev-version bump.
##
## Does NOT:
##   * Delete the `CRAN-SUBMISSION` marker (retained as provenance).
##   * Announce the release on social or mailing lists.

suppressPackageStartupMessages({
  if (!requireNamespace("desc", quietly = TRUE)) {
    stop("desc package is required (install.packages('desc'))")
  }
})

abort_if <- function(cond, msg) if (isTRUE(cond)) stop(msg, call. = FALSE)
cli_step <- function(msg) cat("==> ", msg, "\n", sep = "")
cli_skip <- function(msg) cat("    (skip) ", msg, "\n", sep = "")
cli_ok   <- function(msg) cat("    OK    ", msg, "\n", sep = "")

## Run an external command with each argument passed as a single
## arg vector element. shQuote() each arg so multi-word strings
## (commit messages, release titles) survive the shell expansion that
## system2() does on Unix. Abort with a loud error on non-zero exit.
run_checked <- function(command, args, capture = TRUE) {
  quoted <- vapply(args, shQuote, character(1))
  if (capture) {
    out <- system2(command, quoted, stdout = TRUE, stderr = TRUE)
    status <- attr(out, "status")
    status <- if (is.null(status)) 0L else status
    if (status != 0L) {
      stop(sprintf("`%s %s` failed (exit %d):\n%s",
                   command,
                   paste(args, collapse = " "),
                   status,
                   paste(out, collapse = "\n")),
           call. = FALSE)
    }
    out
  } else {
    status <- system2(command, quoted)
    if (status != 0L) {
      stop(sprintf("`%s %s` failed (exit %d).",
                   command,
                   paste(args, collapse = " "),
                   status),
           call. = FALSE)
    }
    invisible(status)
  }
}

run_status <- function(command, args) {
  ## For probe-style calls where a non-zero exit is meaningful, not fatal.
  quoted <- vapply(args, shQuote, character(1))
  system2(command, quoted, stdout = FALSE, stderr = FALSE)
}

git <- function(...) run_checked("git", c(...), capture = TRUE)

# --- Read package version + tag/heading names -------------------------

pkg_version <- as.character(desc::desc_get_version())
pkg_name    <- desc::desc_get_field("Package")
tag         <- paste0("v", pkg_version)
dev_version <- paste0(pkg_version, ".9000")
release_title <- sprintf("%s %s - first CRAN release", pkg_name, pkg_version)
dev_heading <- sprintf("# %s (development version)", pkg_name)
commit_msg <- sprintf("chore: bump to dev version %s after CRAN acceptance",
                      dev_version)

# --- Step 1: read submission SHA ---------------------------------------

cli_step("Reading CRAN-SUBMISSION marker")
abort_if(!file.exists("CRAN-SUBMISSION"),
         "CRAN-SUBMISSION not found - run from the janusplot package root.")

sub_meta <- readLines("CRAN-SUBMISSION")
sub_sha  <- sub("^SHA: ", "", grep("^SHA: ", sub_meta, value = TRUE))
sub_ver  <- sub("^Version: ", "", grep("^Version: ", sub_meta, value = TRUE))
abort_if(!nzchar(sub_sha), "Could not parse SHA from CRAN-SUBMISSION.")
abort_if(sub_ver != pkg_version,
         sprintf("CRAN-SUBMISSION reports version '%s' but DESCRIPTION says '%s'.",
                 sub_ver, pkg_version))
cli_ok(sprintf("version %s, SHA %s", sub_ver, substr(sub_sha, 1, 10)))

# --- Step 2: ancestry check --------------------------------------------

cli_step("Verifying submission SHA is an ancestor of HEAD")
ancestry_rc <- run_status("git", c("merge-base", "--is-ancestor", sub_sha, "HEAD"))
abort_if(ancestry_rc != 0,
         sprintf("Submission SHA %s is not an ancestor of HEAD - resolve manually.",
                 sub_sha))
cli_ok("ancestry verified")

# --- Step 3: annotated tag on the submission SHA -----------------------

cli_step(sprintf("Creating annotated tag %s on submission SHA", tag))
existing_tag <- git("tag", "--list", tag)
if (length(existing_tag) == 0 || !any(nzchar(existing_tag))) {
  git("tag", "-a", tag,
      "-m", sprintf("%s %s - first CRAN release", pkg_name, pkg_version),
      sub_sha)
  cli_ok(sprintf("tag %s created", tag))
} else {
  cli_skip(sprintf("tag %s already exists", tag))
}

# --- Step 4: push tag --------------------------------------------------

cli_step("Pushing tag to origin")
existing_remote <- run_status("git",
                              c("ls-remote", "--exit-code", "--tags",
                                "origin", tag))
if (existing_remote != 0) {
  git("push", "origin", tag)
  cli_ok(sprintf("tag %s pushed", tag))
} else {
  cli_skip(sprintf("tag %s already exists on origin", tag))
}

# --- Step 5: GitHub release -------------------------------------------

cli_step("Creating GitHub release")
view_rc <- run_status("gh",
                      c("release", "view", tag, "--repo", "max578/janusplot"))
if (view_rc != 0) {
  news_lines <- readLines("NEWS.md")
  heads <- grep("^# ", news_lines)
  abort_if(length(heads) == 0, "NEWS.md has no top-level (# ) headings.")
  start <- heads[1] + 1
  end   <- if (length(heads) >= 2) heads[2] - 1 else length(news_lines)
  notes <- paste(news_lines[start:end], collapse = "\n")

  notes_path <- tempfile(fileext = ".md")
  writeLines(notes, notes_path)
  on.exit(unlink(notes_path), add = TRUE)

  run_checked("gh",
              c("release", "create", tag,
                "--repo", "max578/janusplot",
                "--title", release_title,
                "--notes-file", notes_path),
              capture = TRUE)
  cli_ok("release created")
} else {
  cli_skip(sprintf("GitHub release %s already exists", tag))
}

# --- Steps 6-8: dev version bump + commit + push ----------------------

cli_step(sprintf("Bumping to development version %s", dev_version))
cur_ver <- as.character(desc::desc_get_version())
if (cur_ver == pkg_version) {
  desc::desc_set_version(dev_version)

  news_lines <- readLines("NEWS.md")
  already_dev <- any(grepl("development version",
                           news_lines[seq_len(min(5, length(news_lines)))]))
  if (!already_dev) {
    news_new <- c(dev_heading, "", "", news_lines)
    writeLines(news_new, "NEWS.md")
  }

  git("add", "DESCRIPTION", "NEWS.md")
  run_checked("git", c("commit", "-m", commit_msg), capture = TRUE)
  run_checked("git", c("push", "origin", "main"), capture = TRUE)
  cli_ok("dev version committed and pushed")
} else if (cur_ver == dev_version ||
           utils::compareVersion(cur_ver, pkg_version) > 0) {
  cli_skip(sprintf("DESCRIPTION already at %s", cur_ver))
} else {
  stop(sprintf("Unexpected DESCRIPTION version: '%s'", cur_ver), call. = FALSE)
}

cat("\n")
cli_ok(sprintf("%s %s is released, tagged, and on GitHub.", pkg_name, pkg_version))
cli_ok(sprintf("Dev work continues on %s.", dev_version))
