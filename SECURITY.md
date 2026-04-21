# Security Policy

## Supported versions

janusplot is a development-stage package. Only the latest `main` branch
receives fixes. Once a CRAN release ships, the most recent CRAN version and
`main` will both be supported.

## Reporting a vulnerability

Please do not open public issues for security-sensitive reports. Instead,
email the maintainer:

**Max Moldovan** — [max.moldovan@adelaide.edu.au](mailto:max.moldovan@adelaide.edu.au)

You should receive an acknowledgement within 3 working days. Please include:

- A description of the issue.
- A minimal reprex (`reprex::reprex()`) demonstrating the vulnerability.
- Your `sessionInfo()`.
- Suggested remediation if you have one.

Vulnerabilities will be disclosed via a `NEWS.md` entry and (for CRAN
releases) a patched tarball submitted to CRAN. Public disclosure timelines
are coordinated with the reporter.
