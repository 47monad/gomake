# 47monad Gomake

## Version

Current version: **0.0.3**

## Overview

Gomake is a powerful Makefile-based build system for Go projects, providing a
streamlined workflow for building, testing, linting, and deploying Go services.
It supports multi-service repositories, parallel builds, and extensive
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
make build       # Build all services
make build-<svc> # Build a specific service (replace <svc> with service name)
```

### Testing & Coverage

```sh
make test        # Run tests
make coverage    # Run tests with coverage report
```

### Linting & Formatting

```sh
make lint        # Run linters
make fmt         # Format code
```

### Dependency Management

```sh
make deps        # Install dependencies
make deps-tidy   # Tidy dependencies
make deps-update # Update dependencies
make deps-verify # Verify dependencies
```

### Running Services

```sh
make run-<svc>   # Run a specific service
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
make self-update                                          # verify against the pinned GOMAKE_SHA256
make self-update GOMAKE_REF=<rev> GOMAKE_SHA256=<sha256>  # move the pin to a new revision
make self-update GOMAKE_ALLOW_UNVERIFIED=1                # skip verification (not recommended)
```

`GOMAKE_REF` must be an immutable revision (a full commit SHA or a tag), never a
moving branch, and `GOMAKE_SHA256` is the expected digest of `Makefile` at that
revision. When releasing a new GoMake version, bump both together. The download
is written to a temporary file, validated, and only then renamed over the
current Makefile, so a failed check never leaves a corrupted file behind.

## Configuration

Modify environment variables in the Makefile to customize build settings,
services, and testing parameters.

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

## License

47monad | All rights reserved

## Maintainer

Maintained by 47monad.
