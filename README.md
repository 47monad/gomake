# 47monad Makefile Repository
-- Version: 0.0.1

## Overview

This repository contains a **centralized Makefile** designed to standardize and simplify project automation across all 47monad microservices. The Makefile includes a comprehensive set of commands for tasks such as development, testing, building, linting, formatting, cleaning, and more.

By using this Makefile, teams can:
- Maintain consistency across projects.
- Reduce the overhead of setting up project-specific automation.
- Ensure that all services adhere to the company’s engineering standards.

---

## Features

NOTE: **(service)** should be substituted with the name of the service you are trying to run.
The Makefile supports the following categories of tasks:

### Help
- **`make`** or **`make help`**: See the list of commands and services.

### Development
- **`make run-(service)`**: Start the application in development mode.
- **`make dev`**: Start development tools, including hot reloading (if applicable).

### Build & Deploy
- **`make build-(service)`**: Build the service for production.

### Code Quality
- **`make lint`**: Run code linters to enforce style and quality.
- **`make format`**: Automatically format code to conform to standards.

### Testing
- **`make test`**: Run unit tests.
- **`make coverage`**: Generate test coverage reports.

### Maintenance
- **`make clean`**: Remove temporary files, build artifacts, and cached data.
- **`make deps`**: Download dependencies and tools.
- **`make deps-update`**: Update dependencies and tools.
- **`make deps-tidy`**: Tidy dependencies and tools.

### Tooling
- **`make tools`**: Install required tools and dependencies.

---

## Usage

### Integration into a Project
Copy the Makefile to the root of your repository any way you want and start using.

You can customize this Makefile or add your own targets like a normal Makefile. However for the sake of consistency this is **NOT RECOMMENDED**.

### Running Commands
Navigate to the root of your project and use `make` commands:
```bash
make <command>
```
For example:
```bash
make run-reader
make lint
```

---

## Contribution Guidelines

Since this repository is used across the company, contributions must adhere to the following rules:
- **Follow coding standards**: Ensure all scripts and tools conform to the company’s engineering standards.
- **Document new targets**: Update this README and add clear comments in the Makefile for any new targets.
- **Test changes**: Validate changes against multiple projects before merging.

---

## License

This repository is private and proprietary. Only authorized personnel are permitted to use or modify its contents.
