#!/usr/bin/env Rscript
## post-cran-acceptance.R
##
## Run after the CRAN acceptance email for janusplot 0.1.0 arrives.
## Idempotent: each step checks for prior completion before acting.
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
##   3. Creates an annotated git tag `v0.1.0` on that SHA.
##   4. Pushes the tag to origin.
##   5. Creates a GitHub release at v0.1.0, notes pulled from the top
##      section of NEWS.md.
##   6. Bumps DESCRIPTION Version to 0.1.0.9000.
##   7. Prepends a "# janusplot (development version)" heading to
##      NEWS.md.
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

git <- function(...) {
  args <- c(...)
  system2("git", args, stdout = TRUE, stderr = TRUE)
}

# --- Step 1: read submission SHA ---------------------------------------

cli_step("Reading CRAN-SUBMISSION marker")
abort_if(!file.exists("CRAN-SUBMISSION"),
         "CRAN-SUBMISSION not found - run from the janusplot package root.")

sub_meta <- readLines("CRAN-SUBMISSION")
sub_sha  <- sub("^SHA: ", "", grep("^SHA: ", sub_meta, value = TRUE))
sub_ver  <- sub("^Version: ", "", grep("^Version: ", sub_meta, value = TRUE))
abort_if(!nzchar(sub_sha), "Could not parse SHA from CRAN-SUBMISSION.")
abort_if(sub_ver != "0.1.0",
         sprintf("CRAN-SUBMISSION reports version '%s', expected '0.1.0'.", sub_ver))
cli_ok(sprintf("version %s, SHA %s", sub_ver, substr(sub_sha, 1, 10)))

# --- Step 2: ancestry check --------------------------------------------

cli_step("Verifying submission SHA is an ancestor of HEAD")
rc <- system2("git", c("merge-base", "--is-ancestor", sub_sha, "HEAD"))
abort_if(rc != 0,
         sprintf("Submission SHA %s is not an ancestor of HEAD - resolve manually.", sub_sha))
cli_ok("ancestry verified")

# --- Step 3: annotated tag on the submission SHA -----------------------

tag <- "v0.1.0"
cli_step(sprintf("Creating annotated tag %s on submission SHA", tag))
existing_tag <- git("tag", "--list", tag)
if (length(existing_tag) == 0 || !any(nzchar(existing_tag))) {
  git("tag", "-a", tag,
      "-m", "janusplot 0.1.0 - first CRAN release",
      sub_sha)
  cli_ok(sprintf("tag %s created", tag))
} else {
  cli_skip(sprintf("tag %s already exists", tag))
}

# --- Step 4: push tag --------------------------------------------------

cli_step("Pushing tag to origin")
push_out <- git("push", "origin", tag)
cli_ok(paste(push_out, collapse = " | "))

# --- Step 5: GitHub release -------------------------------------------

cli_step("Creating GitHub release")
view_rc <- system2("gh",
                   c("release", "view", tag, "--repo", "max578/janusplot"),
                   stdout = FALSE, stderr = FALSE)
if (view_rc != 0) {
  news_lines <- readLines("NEWS.md")
  heads <- grep("^# ", news_lines)
  abort_if(length(heads) == 0, "NEWS.md has no top-level (# ) headings.")
  start <- heads[1] + 1
  end   <- if (length(heads) >= 2) heads[2] - 1 else length(news_lines)
  notes <- paste(news_lines[start:end], collapse = "\n")

  notes_path <- tempfile(fileext = ".md")
  writeLines(notes, notes_path)

  system2("gh",
          c("release", "create", tag,
            "--repo", "max578/janusplot",
            "--title", "janusplot 0.1.0 - first CRAN release",
            "--notes-file", notes_path))
  cli_ok("release created")
} else {
  cli_skip(sprintf("GitHub release %s already exists", tag))
}

# --- Steps 6-8: dev version bump + commit + push ----------------------

cli_step("Bumping to development version 0.1.0.9000")
cur_ver <- as.character(desc::desc_get_version())
if (cur_ver == "0.1.0") {
  desc::desc_set_version("0.1.0.9000")

  news_lines <- readLines("NEWS.md")
  already_dev <- any(grepl("development version", news_lines[seq_len(min(5, length(news_lines)))]))
  if (!already_dev) {
    news_new <- c("# janusplot (development version)", "", "", news_lines)
    writeLines(news_new, "NEWS.md")
  }

  git("add", "DESCRIPTION", "NEWS.md")
  commit_msg <- "chore: bump to dev version 0.1.0.9000 after CRAN acceptance"
  system2("git", c("commit", "-m", commit_msg))
  system2("git", c("push", "origin", "main"))
  cli_ok("dev version committed and pushed")
} else if (cur_ver == "0.1.0.9000" || utils::compareVersion(cur_ver, "0.1.0") > 0) {
  cli_skip(sprintf("DESCRIPTION already at %s", cur_ver))
} else {
  stop(sprintf("Unexpected DESCRIPTION version: '%s'", cur_ver), call. = FALSE)
}

cat("\n")
cli_ok("janusplot 0.1.0 is released, tagged, and in GitHub.")
cli_ok("Dev work continues on 0.1.0.9000.")
