# 47monad Gomake

## Version

Current version: **0.1.0**

## Overview

Gomake is a powerful Makefile-based build system for Go projects, providing a
streamlined workflow for building, testing, linting, and reporting on Go
services. It supports multi-service repositories, parallel builds, and extensive
automation features.

## Features

- 🚀 **Automated Build System**: Supports building all or specific services.
- 🧪 **Testing & Coverage**: Runs unit tests, generates coverage reports, and
checks for race conditions.
- 🎨 **Code Quality**: Lints code, formats files, and runs security checks.
- 🔄 **Dependency Management**: Installs, updates, and verifies dependencies.
- 📊 **Reporting & Analytics**: Generates benchmark, lint, and security reports.
- 🔁 **Self-Update**: Fetches the Makefile from a pinned upstream revision and verifies its checksum before replacing the local file.

## Installation

Clone the repository and ensure you have `make` installed:

```sh
git clone https://github.com/47monad/gomake.git
cd gomake
```

## Usage

Run the following `make` commands to execute different tasks:

### Build

```sh
make build       # Build all services (parallel on the local machine)
make build-<svc> # Build a specific service (replace <svc> with service name)
```

`make build` builds every service in one parallel `make` invocation, so shared
prerequisites such as `go generate` run once. Parallelism is on when
`BUILD_SYSTEM=local` (the default). Set `BUILD_SYSTEM=ci` to build serially,
tune the number of jobs with `PARALLEL_JOBS`, or pass `make -jN` to choose your
own job count (it is honored as-is).

### Testing & Coverage

```sh
make test        # Run tests
make coverage    # Run tests with coverage report
```

### Linting, Formatting & Security

```sh
make lint        # Run linters (golangci-lint)
make fmt         # Format code (gofmt + gofumpt)
make security    # Run security checks (govulncheck)
```

### Dependency Management

```sh
make deps        # Install dependencies
make deps-tidy   # Tidy dependencies
make deps-update # Update dependencies
make deps-verify # Verify dependencies
```

### Development & Running

```sh
make dev-<svc>   # Run a service with go run (installs deps, bakes config, generates)
make run-<svc>   # Build and run a service
make bake-<svc>  # Prepare a service's config
make generate    # Run go generate ./...
```

`run-<svc>` and `dev-<svc>` reject an unknown service name before doing any
build or generation work, so a typo fails fast with a clear message.

### Tools & Utilities

```sh
make tools       # Install the pinned linter, formatter and security tools
make mock        # Generate mocks with mockery
make version     # Show version, commit, branch and build metadata
```

### Reports

```sh
make report      # Generate all reports (coverage, benchmark, lint, security)
```

### Cleanup

```sh
make clean       # Remove build artifacts and generated reports
make clean-all   # Also clear the global Go build/test caches
```

`clean` removes `bin/`, `dist/`, `coverage.out` and `docs/reports/`. `clean-all`
additionally runs `go clean -cache -testcache`, which clears the machine-wide Go
caches shared by every project on the host, so it is opt-in.

### Updating Makefile

`self-update` downloads the Makefile from a pinned upstream revision and
verifies its SHA-256 before replacing the local file:

```sh
make self-update                                           # verify against the pinned GOMAKE_SHA256
make self-update GOMAKE_REF=v0.2.0 GOMAKE_SHA256=<sha256>  # move the pin to a new revision
make self-checksum                                         # print the checksum of the current file
make self-update GOMAKE_ALLOW_UNVERIFIED=1                 # skip verification (not recommended)
```

`GOMAKE_REF` must be an immutable revision (a tag or a full commit SHA), never a
moving branch; by default it tracks `GOMAKE_VERSION`. `GOMAKE_SHA256` is the
expected digest of `Makefile` at that revision.

The digest covers the file **excluding the `GOMAKE_SHA256` line itself**, so a
release can pin its own checksum (a file cannot contain the hash of itself).
`make self-checksum` prints that value for the local file. Because that line is
excluded from the hash, the updater also validates it as literal data: the
download must contain exactly one `GOMAKE_SHA256 ?= <64-hex>` assignment whose
value equals its own filtered digest, so a Make expression, a duplicate, an empty
value, or a forged pin is rejected before anything is replaced.
`GOMAKE_ALLOW_UNVERIFIED=1` only waives the caller-side pin; it never skips that
structural check.

The updater targets the file that contains this Makefile, captured when it is
read, so a wrapper that includes Gomake and then includes other files cannot
redirect the update. The download is staged next to the destination (same
filesystem) and renamed over it, so the replacement is atomic and a failed check
leaves the existing file untouched. The destination's permissions are preserved,
and a failed download, validation, or rename fails the target without printing
success.

If the target path is a symlink, the link is replaced by the downloaded file and
its target is left untouched; update the real file directly if you need
otherwise.

To cut a release: bump `GOMAKE_VERSION`, run `make self-checksum`, set
`GOMAKE_SHA256` to its output, commit, and tag that commit (e.g. `v0.1.0`).

## Configuration

Every variable below can be overridden on the command line or in the
environment, e.g. `make build BUILD_SYSTEM=ci` or `make test TEST_PATTERN=TestFoo`.

| Variable | Default | Purpose |
|---|---|---|
| `PROJECT_NAME` | directory name | Display name; `-`/`_` become spaces and the first letter is capitalized |
| `DESCRIPTION` | `<PROJECT_NAME> Project` | Shown in `make help` |
| `SERVICE_DIRS` / `SERVICES` / `FLAT_SERVICE` | directories under `cmd/` | Services built and run by the `<svc>` targets |
| `BUILD_SYSTEM` | `local` | `local` builds in parallel, `ci` builds serially |
| `PARALLEL_JOBS` | detected CPU count | Job count used by `make build` (a `make -jN` on the command line wins) |
| `VERSION_STRATEGY` | `git` | `git` (`git describe`), `semver` (reads `VERSION`) or `date` |
| `VERSION_PKG` | `<module>/pkg/version` | Package receiving the injected version metadata |
| `GO`, `GOOS`, `GOARCH` | Go defaults | Toolchain and target platform |
| `GOBIN` | `go env GOBIN` or first `GOPATH`/bin | Where `make tools` installs tools |
| `CGO_ENABLED` | `0` | Cgo setting for builds |
| `BUILD_TAGS`, `EXTRA_TAGS` | empty | Build tags applied to `go build` |
| `GCFLAGS`, `ASMFLAGS` | empty | Extra compiler flags |
| `TEST_FLAGS`, `TEST_TIMEOUT`, `TEST_PACKAGES`, `TEST_PATTERN`, `SKIP_PATTERN` | see Makefile | Test selection and flags |
| `COVERAGE_OUT`, `COVERAGE_THRESHOLD` | `coverage.out`, `50` | Coverage profile and minimum percent |
| `BENCH_FLAGS`, `BENCH_TIME` | `-benchmem`, `2s` | Used by `make benchmark-report` |
| `BIN_DIR`, `DIST_DIR`, `DOCS_DIR` | `bin`, `dist`, `docs` | Output directories |
| `GOLANGCI_LINT_VERSION`, `GOFUMPT_VERSION`, `GOVULNCHECK_VERSION` | pinned | Tool versions installed by `make tools` |
| `GOMAKE_VERSION`, `GOMAKE_REPO`, `GOMAKE_REF`, `GOMAKE_SHA256` | pinned | Source and checksum used by `make self-update` |

Run `make help` for the full target list and the detected service names.

### Version metadata

Build metadata (`Version`, `Commit`, `Branch`, `BuildTime`, `BuildBy`) is
injected at link time into the package named by `VERSION_PKG`, which defaults
to `<module>/pkg/version`. Override `VERSION_PKG` if the project keeps those
variables in a different package.

The module path is read once from `go.mod` via `MODULE_PATH`. When no module is
present (for example a standalone `go run`), the metadata flags are skipped
rather than emitting an invalid import path.

### Pinned tool versions

`make tools` installs the exact versions declared by `GOLANGCI_LINT_VERSION`,
`GOFUMPT_VERSION` and `GOVULNCHECK_VERSION` instead of `@latest`, so installs
are reproducible and resilient to upstream breaking changes. Override the
variables to upgrade deliberately; Go's module checksum database authenticates
each downloaded module.

Installs go to `GOBIN` (a configured/environment `GOBIN`, otherwise the first
`GOPATH` element's `bin`), and each install must succeed and produce an
executable — a failure stops the target immediately instead of reporting
success. An existing tool at a custom `GOLANGCI_LINT`/`GOFUMPT`/`GOVULNCHECK`
path is left untouched.

## License

47monad | All rights reserved

## Maintainer

Maintained by 47monad.
