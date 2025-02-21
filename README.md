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
- 🔁 **Self-Update**: Fetches the latest Makefile from the repository.

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

### Updating Makefile

```sh
make self-update # Fetch the latest Makefile from the repository
```

## Configuration

Modify environment variables in the Makefile to customize build settings,
services, and testing parameters.

## License

47monad | All rights reserved

## Maintainer

Maintained by 47monad.
