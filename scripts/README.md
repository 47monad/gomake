# scripts/

Maintainer tooling for the Gomake template. Nothing here is a consumer target.

## `test-gomake.sh`

Fixture-based regression harness. Gomake is a **Makefile template**, so it is
exercised inside small throwaway consumer modules rather than by running consumer
targets at this repository root (which has no `go.mod`).

Every test runs in an isolated temporary directory, copies the repository
`Makefile` in, and asserts exit status, invoked arguments/order, and artifact
state. No global Go cache is cleared, and the updater tests use a `curl` stub so
nothing is fetched from the network.

```sh
scripts/test-gomake.sh              # run every test
scripts/test-gomake.sh --list       # list test names
scripts/test-gomake.sh --only NAME  # run one test, e.g. --only build_multi_real
```

Requires GNU make and Go (for the real-build fixtures). Fake `go`, `curl`,
`golangci-lint`, `gofumpt`, `govulncheck`, and `mockery` executables are
generated inside each temp directory for the command/failure assertions.

### What it covers

- **Layouts:** flat (`cmd/main.go`), multi-service (`cmd/<svc>/main.go`), custom
  service Makefiles, no services, unknown services.
- **Service validation:** exact-literal membership (a prefix or regex punctuation
  is rejected) and no Go/dependency/generation/bake work for unknown
  `build-*/dev-*/run-*`.
- **Behaviour:** parallel and serial builds, shared `go generate` (runs once),
  `BIN_DIR` override, updater verification and mismatch, report tool checks.
- **Tools:** an install failure stops `make tools` immediately, installs land in
  `GOBIN` (default and override), a second run is a no-op, and an existing custom
  tool path is not overwritten.
- **Updater hardening:** tampered pins (expression/duplicate/forged), moving-branch
  refs, missing hash tool, download failure, invalid caller pin, self-file binding
  across `include`s, permission preservation, staging failure, and symlinks.
- **Regressions from closed issues:** #4, #5, #6, #7, #9, #10, #11, #12, #13,
  #14, #15, #16, #18, #19.

The harness is itself checked by mutating the Makefile (for example reverting the
lint-report flag) and confirming the relevant test fails.
