# Gomake release plan and Luna handoff

Prepared: 2026-09-30. Reviewed revision: `d0742c290dcbe13f51cb562c577509fc94265a97`.

## 1. Scope and review evidence

Gomake is a **Makefile template for Go projects**, not currently a Go library or
CLI. The tracked repository contains only `Makefile` and `README.md`. There is
no `go.mod`, Go source, test suite, CI workflow, license file, changelog, or
contributor guide. Do not add a root Go module merely to satisfy a checklist;
use small isolated Go fixture modules to exercise the template.

This is a whole-repository assessment against the advertised workflows, not a
PR diff review. Findings below come from static inspection, release history,
read-only GitHub queries, and official documentation. No builds, tool installs,
runtime reproductions, or target tests were run. Acceptance tests below are work
for the implementing agent. Treat hypotheses explicitly marked for reproduction
as hypotheses, not demonstrated failures.

GitHub snapshot:

- Repository: `47monad/gomake`, default branch `main`.
- Latest local tag: `v0.1.0`; local HEAD is the release preparation merge.
- No open issues, no milestones, and no published GitHub releases were returned.
- Issues #1–#19 are closed; fixes were merged through PR #37.
- GitHub reports no detected license. README ends with “All rights reserved.”
- The three pinned tool tags exist upstream. Their existence does not establish
  that installation succeeds on every Go version or that existing binaries match.
- The filtered local Makefile checksum matches its pin:
  `3ba8c859ba266c07e6ec01aea289276fce2cf08bbd7b3d88f12771d27f7faa25`.
  The ordinary SHA-256 of the tagged file is a different digest. Preserve that
  distinction in release assets and documentation.

### Remaining findings

Line references refer to the reviewed revision and will drift during execution.

| Finding | Evidence | Consequence | Planned work |
|---|---|---|---|
| Tool installation can report success after failure | `Makefile:357–371`: install is followed by success printing in the same shell block | A failed install can produce a successful target exit | P03 |
| Pinned tool versions are not checked against installed binaries | `Makefile:357–371`: only file existence is tested | An old or unrelated binary silently satisfies a new pin | N03; default isolation in M06 |
| Service validation uses regex/word matching rather than exact list membership | `Makefile:60`: `grep -wq "$*"` | `api` can match a list containing `api-worker`; punctuation has regex meaning | P04 |
| Validation happens after prerequisites for build/dev | `Makefile:210–211,332–333` | A typo can execute generation, dependency download, or bake hooks first, contrary to README's dev claim | P04 |
| Bake and build have no ordering edge | `Makefile:332,341` | With parallel make, generation/build may race with config preparation | P05 |
| Old binary is removed before a replacement build succeeds | `Makefile:213–225` | A failed build destroys the last usable artifact | P06 |
| Builds and dev runs name only `main.go` | `Makefile:225,336` | Sibling files in a normal Go main package are omitted | M02; documented in P11 |
| Every directory under `cmd/` becomes a service | `Makefile:50–52` | Support directories can be treated as executables; valid mains need not be named `main.go` | M02 |
| Package discovery hides failures and uses a broad substring exclusion | `Makefile:164`: `go list ./... \| grep -v "mocks"` inside `$(shell ...)` | Errors can yield a partial/empty list; a real package with “mocks” in its path is excluded | P07 preserves selection; M04 changes selection policy |
| Coverage gate truncates numbers and can fail open on missing/invalid output | `Makefile:260–264` | Decimal thresholds are unsupported; shell comparison errors can fall through to success | P08 |
| Some commands bypass the configured Go executable | `Makefile:260,387` | Coverage analysis and version output can use a different Go toolchain | P08 |
| Output paths are inconsistently quoted | `Makefile:217,224,254–259,336,343,401,428–429` | Shell token splitting; make prerequisite lists introduce additional whitespace limitations | P09 for recipe paths; M10 for the full path contract |
| `.PHONY: build-%` and similar declarations name literal targets | `Makefile:209,232,331,338` | They do not make all matching targets phony; bake is especially vulnerable to a same-name file suppressing it | P10; verify the actual collision cases |
| Updater identity is late-bound | `Makefile:31`: `SELF_FILE=$(lastword $(MAKEFILE_LIST))` | An included file loaded later can become the update destination or checksum input | P02 |
| Updater temporary file may be on another filesystem; replacement errors can be masked | `Makefile:437,460–461` | `mv` is not guaranteed to be atomic, can change permissions, and is followed by unconditional success | P02 |
| Updater's checksum excludes an executable Make assignment | `Makefile:30,442` | Altering only the excluded assignment does not change the digest; unsafe Make expressions there could survive validation | P01 |
| “Immutable ref” is a comment, not enforced | `Makefile:8,20,439` | Moving refs can be supplied despite the documented contract | P01 |
| Unverified flag documentation disagrees with implementation | `README.md` Updating Makefile section; `Makefile:443–454` | `GOMAKE_ALLOW_UNVERIFIED=1` does not bypass a nonempty mismatched checksum | P11; preserve refusal |
| Cleanup trusts arbitrary configured directories | `Makefile:292–294` | A mistaken root/output override can delete unintended data | P12 minimal guard; ownership model in M10 |
| Metadata quoting only strips apostrophes | `Makefile:143–154` | Spaces can break linker argument parsing or lose fidelity; complete contract is absent | N05 opt-in controls; M07 serialization/default changes |
| No repository regression protection | Tracked-file inventory | Earlier fixes can regress across GNU make versions/platforms | P00, P13, N01 |

Do not recreate closed issues wholesale. The remaining validation defect relates
to #7 but differs from the merged run fix. Updater work extends #15 rather than
reintroducing unpinned downloads. Path and target work extends #19; its help
format-string fix and self-update `.PHONY` declaration are already present.
Parallel builds and once-per-aggregate-build generation were addressed in #9
and #13; add regression coverage rather than claiming they are still unfixed.

## 2. Version and compatibility policy

Create exactly these three milestones:

| Milestone title | Description to use | Completion gate |
|---|---|---|
| `v0.1.1 — Correctness and release foundations` | Repair existing targets, strengthen update validation and failure handling, establish regression CI, and document the current contract. Preserve valid existing invocations, defaults, names, service layouts, and installation model. | All P issues complete; patch compatibility checklist passes |
| `v0.2.0 — Complete Go workflows` | Add opt-in, composable Go quality, testing, diagnostics, tooling, reporting, and distribution workflows, with documented examples and CI. Existing v0.1 behavior remains compatible. | All N issues complete; old-consumer compatibility suite passes |
| `v1.0.0 — Stable contract and migration` | Establish a stable public Makefile API, package-based builds, explicit lifecycle and workspace behavior, isolated tools, safe configuration/update ownership, and migration from v0.x. All changes to existing defaults or contracts belong here. | All M issues complete; release candidate and migration gates pass |

Leave due dates and assignees unset; no delivery dates or staffing were provided.
Use `v1.0.0`, not `v0.3.0`, for the next major milestone. Although SemVer permits
API instability at v0.x, this plan deliberately follows the user's stronger rule:
**any potentially incompatible change belongs in the major milestone**.
See [SemVer](https://semver.org/) for version definitions.

Treat target names, variables, variable precedence, default flags, output paths,
service discovery, extension hooks, prerequisites/side effects, supported make
and Go versions, and updater behavior as the public API. Existing valid usage
includes command-line/environment overrides and service-local Makefiles.

Patch fixes may reject unsafe updates, invalid service names, malformed coverage
results, and catastrophic cleanup paths. These are documented safety corrections,
not a license to redesign valid configurations. If a proposed fix also rejects a
previously valid configuration, put that portion in M01/M10 and retain a compatible
patch approach. Mark uncertainty `compatibility-review`; do not merge it into a
patch or minor release just because the version is below 1.0.

## 3. Issue conventions

Each issue below includes its title, priority, size, dependencies, evidence,
scope, and acceptance criteria. Create **one issue per ID** and preserve the ID
in both title and body. IDs are planning keys, not GitHub issue numbers.

Priorities: P0 = integrity/safety blocker; P1 = correctness/release blocker;
P2 = planned workflow or maintenance. All listed issues are required for their
milestone; priority determines ordering, not whether to silently omit them.

Sizes: S = focused change, M = several related changes/fixtures, L = substantial
design and implementation. Sizes are relative, not time commitments.

Reuse `bug`, `enhancement`, `documentation`, and `security`. Add if missing:

| Label | Color | Description |
|---|---|---|
| `priority:p0` | `B60205` | Integrity or safety blocker |
| `priority:p1` | `D93F0B` | Correctness or release blocker |
| `priority:p2` | `FBCA04` | Planned workflow or maintenance |
| `area:build` | `1D76DB` | Service discovery, build, and run |
| `area:test` | `5319E7` | Tests, coverage, race, and benchmarks |
| `area:tools` | `0052CC` | Tool installation and diagnostics |
| `area:update` | `B60205` | Template integrity and self-update |
| `area:ci` | `0E8A16` | Repository and consumer CI |
| `area:docs` | `0075CA` | User and contributor documentation |
| `area:release` | `006B75` | Versioning and distribution |
| `area:config` | `C5DEF5` | Variables, paths, and extension contract |
| `breaking-change` | `B60205` | Changes an existing public contract; v1 only |
| `compatibility-review` | `D4C5F9` | Compatibility impact must be resolved before implementation |
| `maintainer-decision` | `F9D0C4` | Requires a maintainer's policy decision |
| `size:s` | `EDEDED` | Focused scope |
| `size:m` | `D4C5F9` | Moderate scope |
| `size:l` | `BFD4F2` | Substantial scope |

For each issue apply one type label, one priority label, one size label, and the
areas listed. Add `security` alongside `bug` for P01/P02/P12 as appropriate.
Apply `breaking-change` to M issues that change behavior; M11/M12 are documentation
and release gates and need not themselves be labeled breaking.

## 4. Patch milestone: v0.1.1

### P00 — Add a fixture-based Makefile regression harness

Metadata: enhancement; P1; M; areas test/ci; dependencies none.

Evidence: no tracked tests or fixtures. The template must be tested inside
consumer projects, not by running `make test` at this module-less root.

Scope: introduce an explicit maintainer entry point such as
`scripts/test-gomake.sh` and tiny fixture modules. Keep it outside consumer target
names. Use fake Go/tool/curl executables for command and failure assertions;
use real Go for the core consumer smoke fixture.

Acceptance:

- Every fixture runs in an isolated temporary directory; no global caches are
  cleared and no real updater replaces the repository Makefile.
- Cover flat and multi-service layouts, custom service Makefiles, no services,
  unknown services, shared generation, serial/parallel builds, flags/overrides,
  and previous closed-issue regressions.
- Assertions check exit status, invoked arguments/order, and artifact state;
  golden colored console output is not the main assertion mechanism.
- Updater/tool tests use controlled local stubs and do not execute downloaded
  untrusted content. Failure fixtures cannot fetch network tools accidentally.
- Document how to run the harness. No root module solely for orchestration.

### P01 — Close checksum exclusion gaps and enforce updater validation

Metadata: bug + security; P0; M; area update; dependency P00.

Evidence: `Makefile:8–30,437–455`; the digest omits any matching checksum
assignment, including Make expressions, duplicate assignments, or an empty pin.

Scope: preserve the current filtered digest format for valid v0.1 files. Parse
and validate the excluded assignment as data before replacement. Require exactly
one supported assignment containing a literal valid SHA-256 digest; reject Make
expressions, extra syntax, duplicate entries, and unsupported variants. Establish
that the downloaded embedded pin equals its computed filtered digest. Validate
the caller's expected pin and documented ref form. Tags can be moved upstream;
the independent caller checksum remains essential even for tags.

Acceptance:

- Correct v0.1.0/patched files validate with the existing digest algorithm.
- Modifying only the excluded line to contain an expression, an empty value,
  duplicates, or a forged future pin is rejected before any replacement or Make
  evaluation of downloaded content.
- Branch refs, malformed refs/digests, empty downloads, download failures,
  mismatches, and missing required hashing commands fail explicitly.
- Preserve refusal on nonempty checksum mismatch even with the unverified flag.
  The explicit empty-pin escape hatch remains clearly documented and bounded.
- Test shell/hash failures; no pipeline failure can be converted into successful
  verification. Updater messages explain filtered versus full-file digests.

### P02 — Bind the updater to its own file and replace it safely

Metadata: bug + security; P0; M; areas update/config; dependencies P00, P01.

Evidence: recursive `SELF_FILE` at line 31, cross-directory `mktemp` at 437,
and unconditional success after `mv` at 460–461.

Scope: capture the template path when the template is read, not after all includes
are loaded. Stage in the destination directory for same-filesystem rename; clean
up on failures/signals and preserve the destination's appropriate permissions.

Acceptance:

- Standalone use, `make -f`, and wrapper includes before/after another file update
  or hash only Gomake; unrelated Makefiles remain byte-for-byte unchanged.
- Failed downloads, malformed contents, invalid hashes, and interrupted staging
  leave the old destination intact and remove temporary files.
- Failed rename/replacement returns nonzero and never prints update success.
  Destination permission errors are visible. Successful replacement does not
  unexpectedly turn a shared readable Makefile into mode 0600.
- Document and test symlink behavior; do not silently expand into a new destructive
  policy. Unsupported filename cases are reported and tracked under M10.

### P03 — Propagate tool installation failures and respect install destinations

Metadata: bug; P1; S; area tools; dependency P00.

Evidence: `Makefile:357–371`: unconditional success commands mask failed installs;
the inferred GOBIN path and Go's actual installation destination can disagree.

Scope: make each failed install fail the target immediately. Align the installation
destination with the supported GOBIN configuration; honor an environment-provided
Go GOBIN and the first GOPATH element when deriving a default. Do not silently
overwrite a user-selected custom tool executable.

Acceptance:

- Failed installation of each tool returns nonzero; later tools and success
  messages do not run.
- Default, explicit GOBIN, inherited Go GOBIN, and a GOPATH list use the intended
  destination. Installed binaries are executable and resolve as documented.
- Preserve current tool pins and public tool-path overrides; version drift and
  opt-in synchronization are addressed in N03, default isolation in M06.

### P04 — Validate exact service membership before side effects

Metadata: bug; P1; M; area build; dependency P00.

Evidence: regex membership at line 60; build/dev prerequisites run before recipe
validation. README currently promises early validation for dev/run.

Scope: compare complete configured service names as literals. Ensure build/dev/
run validate before dependencies, generation, hooks, or output mutation. Preserve
valid configured service names and existing flat/custom service behavior.

Acceptance:

- `api` is rejected when only `api-worker` exists; regex punctuation does not
  make a different service valid.
- Unknown `build-*`, `dev-*`, and `run-*` return a useful nonzero error without
  invoking Go, downloads, generation, bake hooks, or binary removal.
- Aggregate build still generates once for ordinary services, respects the
  jobserver, and propagates nested failures.
- Any new service-name restriction affecting legitimate existing usage is moved
  to M02 rather than slipped into this patch.

### P05 — Enforce existing bake/generate/build ordering under parallel make

Metadata: bug; P1; M; area build; dependencies P00, P04.

Evidence: sibling prerequisites at line 332 and recursive goals at line 341.

Scope: express the intended ordering as dependency edges or explicit sequential
steps: validate, then dependency preparation where currently used, then bake,
then generation/build, then run. Preserve current implicit generation behavior.

Acceptance:

- A bake fixture creates input required by a generator; `dev-*` and `run-*`
  succeed with `-j` and record the expected order.
- Bake/generation/build failure prevents the subsequent stage and run.
- Independent aggregate service builds remain parallel; no blanket
  `.NOTPARALLEL` workaround and no unnecessary loss of jobserver sharing.
- Document ordinary versus custom service Makefile lifecycle boundaries.

### P06 — Preserve the last good binary on build failure

Metadata: bug; P1; S; area build; dependency P00.

Evidence: existing artifact is removed at lines 213–215 before compilation.

Scope: remove unnecessary pre-deletion or stage replacement without changing
the successful output name. Document responsibility for delegated custom builds.

Acceptance:

- A failed standard build leaves an existing executable unchanged.
- A successful build replaces it; first builds still create the output directory.
- Compile failure yields nonzero and never prints service success or runs the
  old binary automatically. No new package/file selection policy in this issue.

### P07 — Fail visibly when test package discovery fails

Metadata: bug; P1; M; area test; dependency P00.

Evidence: `Makefile:164`; make's `$(shell ...)` output does not propagate the
`go list` failure, and the pipeline obscures it further.

Scope: resolve packages for relevant targets with explicit error handling. Preserve
the existing default mock exclusion for now and honor explicit TEST_PACKAGES.
Do not turn a failed/empty selection into an implicit current-directory test.

Acceptance:

- Discovery failures fail test/coverage/benchmark-report, including partial stdout
  plus nonzero status. Go's useful stderr is retained.
- Empty filtered selection reports that no packages were selected.
- Explicit nonempty package selection and package patterns work without redundant
  default discovery. Help and updater operations need not discover test packages.
- Changing the substring exclusion and default package policy belongs to M04.

### P08 — Make coverage checks precise and fail closed

Metadata: bug; P1; M; area test; dependencies P00, P07.

Evidence: `Makefile:254–264,387`; integer truncation, unchecked pipelines, hardcoded
`go`, and only the default HTML directory is created.

Scope: compare validated numeric total coverage against a validated 0–100
threshold without truncation. Honor GO for every Go command, including version.
Create parent directories of explicitly selected profile and HTML output files.

Acceptance:

- Threshold boundaries include 0, 50, 50.5, and 100; for example 50.4 fails 50.5
  and 50.5 passes. Nonnumeric/out-of-range values fail clearly.
- Missing/malformed profiles, missing total, and `go tool cover` failures fail
  the target; do not print success after parser or comparison errors.
- GO wrapper is used consistently; custom profile/HTML directories are created.
- Keep existing test selection defaults. New coverage selection controls are N06;
  default coverage/test policy changes are M04.

### P09 — Quote recipe paths and preserve target failure statuses

Metadata: bug; P1; M; areas config/build; dependency P00.

Evidence: inconsistent quoting in build, run, coverage, report, and directory
recipes. Existing #19 fixed help, not all command paths.

Scope: audit recipe path arguments, mkdir/redirection use, and shell blocks for
failure masking. Quote data arguments and use deliberate end-of-options handling
where supported. Keep flags that are intentionally lists separate from paths.

Acceptance:

- Custom report paths with whitespace work where they are recipe arguments.
- Failing delegated builds, mkdir, formatters, linters, and report commands remain
  nonzero; no output creation error becomes a success message.
- Test supported metacharacter cases using inert sentinels. Do not claim that
  double quotes neutralize arbitrary shell substitutions or Make expressions.
- Explicitly document make-graph path limitations; complete root/BIN_DIR paths
  with spaces and a uniform quoting/configuration contract are M10, not a patch
  promise that recipe quoting alone cannot deliver.

### P10 — Make service action targets execute despite file collisions

Metadata: bug; P2; S; area build; dependencies P00, P04.

Evidence: `%` is literal in `.PHONY` prerequisites, not a phony pattern. See the
[GNU make manual](https://www.gnu.org/software/make/manual/make.html#Phony-Targets).

Scope: make concrete known service actions reliably phony or use an appropriate
force rule without disabling their implementation rules. Verify each affected
target's actual behavior before claiming it is suppressed.

Acceptance:

- Files named `bake-api`, `build-api`, `dev-api`, and `run-api` cannot suppress
  required service actions. Build/dev may already rerun through generate; keep
  that working and test it.
- Unknown service actions still fail early; concrete phony targets do not
  accidentally suppress implicit rule search and create successful no-op builds.

### P11 — Document the actual v0.1 contract and maintainer policies

Metadata: documentation; P1; M; areas docs/release; dependencies P01–P10.

Scope: fix unverified-update instructions to require an explicitly empty checksum
for the escape hatch. Explain how to copy the template into a consuming module;
cloning this repo alone does not make build/test meaningful. Document main.go-only
behavior, bake's placeholder, required tools, GNU make and shell prerequisites,
CGO/race prerequisites, supported platform evidence, and configuration limitations.

Acceptance:

- Include a minimal consuming main program, optional version package, and exact
  build/test commands. Separate consumer commands from repository harness commands.
- Add CONTRIBUTING, SECURITY reporting guidance, changelog, release checklist,
  and ignore rules for generated artifacts without hiding tracked fixture source.
- Capture the v0.1 public target/variable/default list for later compatibility tests.
- License issue: record a `maintainer-decision` task here. Ask the owner whether
  to retain the current rights statement or choose a license and have the owner
  approve its exact text. Do not invent authorization to relicense. Record the
  resolution even if it is to retain current terms; do not call the repo open
  source without a license granting those rights.
- Publish only a tested support matrix; new minimum-version restrictions go to M09.

### P12 — Refuse catastrophic cleanup destinations

Metadata: bug + security; P0; M; area config; dependency P00.

Evidence: `Makefile:292–294` deletes caller-selected directories recursively.

Scope: validate all destinations before any deletion and reject empty or
filesystem-root/project-root/home-equivalent destructive destinations. Keep
documented valid custom output locations usable in v0.x. Full ownership and
external-output policy belongs to M10.

Acceptance:

- Use disposable sandbox directories and inert deletion stubs to cover malformed
  overrides, trailing separators, `.`/`..`, and dangerous equivalent paths.
- An invalid destination prevents the entire cleanup before the first deletion.
- `clean` still only removes its documented artifacts; `clean-all` alone clears
  Go's global build/test caches. Tests never actually clear host caches.
- Symlink/canonicalization limitations are documented and escalated to M10 if
  resolving them would change valid existing configurations.

### P13 — Add patch regression CI and prepare v0.1.1

Metadata: enhancement; P1; M; areas ci/release; dependencies P00–P12.

Scope: repository CI runs the harness on Linux and macOS using the minimum
currently claimed GNU make plus modern GNU make. Start with the runner Go version
and record tool compatibility; N01 expands the matrix. Pin external actions to
full commit SHAs; use minimal permissions and avoid untrusted PR execution with
write tokens. Follow [GitHub's secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use).

Acceptance:

- CI tests real flat/multiple/custom service consumer fixtures plus stub failure
  tests; it never runs root consumer targets expecting a nonexistent Go module.
- Tests are mandatory for patch merge; contributor instructions match CI.
- Bump header/GOMAKE_VERSION/README, recompute the filtered pin after all changes,
  verify it from the exact candidate artifact, and tag the reviewed commit.
- Release notes explain corrections and limitations. Prepare a GitHub release
  with Makefile and separately named full-file and filtered digest data.
- Release publication and repository protection changes remain explicit owner
  actions unless separately authorized; issue creation is not publication consent.

## 5. Minor milestone: v0.2.0

All additions below are opt-in or new targets. Do not silently change existing
test flags, build side effects, tool locations, output names, or discovery rules.

### N01 — Expand the consumer compatibility matrix

Metadata: enhancement; P1; M; areas ci/test; dependency P13.

Scope: exercise supported Go versions and GNU make versions, Linux/macOS, flat/
multi-service/custom hooks, cgo and non-cgo, build tags, cross-compilation,
offline stubs, read-only sources, failed tools, and overrides. Add source fixtures
for a library-only module and a workspace; initially test supported quality flows
and clearly asserted unsupported build flows.

Acceptance: CI distinguishes host tests from cross-builds; race runs only on
documented supported hosts with a C compiler. Pin the matrix deliberately rather
than assuming every historical Go release is supported. Preserve the v0.1
compatibility fixture suite across the minor. Do not drop a previously documented
platform/minimum version here; policy changes belong to M09.

### N02 — Add read-only doctor diagnostics

Metadata: enhancement; P1; M; areas tools/config; dependency P13.

Scope: new `doctor` target checks target-specific prerequisites, module/workspace
state, selected Go version, tools, pin drift, output permissions, C compiler/race
requirements, and unsupported configurations. No installations or source mutation.

Acceptance: missing optional tools do not block unrelated targets; required-tool
checks give actionable fixes. Diagnostics honor GO/tool overrides, work outside
a module for basic template inspection, and avoid printing secrets from the full
environment. Support a nonzero status for explicitly requested failing checks.

### N03 — Add explicit tool version verification and synchronization

Metadata: enhancement; P1; M; area tools; dependencies P03, N02.

Scope: new `tools-check` and `tools-sync` (or equivalent documented names).
Check declared versus installed versions; synchronization deliberately upgrades
pins in the existing installation model. Add optional pinned mockery installation
and diagnostics instead of leaving it as an unexplained external prerequisite.

Acceptance: stale and nonexecutable binaries are identified; failed synchronization
preserves usable old binaries when possible and returns nonzero. Respect custom
executables without overwriting them silently. Record each tool's install method,
Go requirements, and update procedure using upstream guidance, including
[golangci-lint installation](https://golangci-lint.run/docs/welcome/install/).
Default local isolation is M06. Do not fetch `@latest` during normal execution.

### N04 — Add nonmutating quality targets and an aggregate check

Metadata: enhancement; P1; M; areas test/tools; dependencies N02, N03.

Scope: add `fmt-check`, `vet`, `tidy-check`, `generate-check`, and `check`.
Keep fmt/deps-tidy/generate as the explicit mutating commands. Provide an example
golangci-lint v2 configuration and avoid duplicating equivalent static analyzers.

Acceptance: check reports failure on required drift/findings and succeeds with
a clean consumer fixture. Checking tidy/generation uses an isolated copy or
guarantees restoration of preexisting uncommitted files; it must not destroy user
work. `check` has a documented dependency graph, no downloads or updates, and
honors package/tool configuration. Consumer quality checks and template shell/
Make linting are separate; include shellcheck where applicable to added scripts.

### N05 — Add optional build controls without changing existing defaults

Metadata: enhancement; P2; M; areas build/config; dependencies P13, N01.

Scope: explicit build metadata enable/disable switch, optional `-trimpath`,
read-only module mode, deterministic timestamp/user inputs, host/target diagnostics,
and documented GOOS/GOARCH/CGO propagation. Make full tag/flag handling explicit.

Acceptance: current defaults and output names remain intact; switching metadata
off supports a project without a version package. Caller-provided fixed metadata
is reproducible in the tested fixture. Verify CLI, environment, and included-file
overrides rather than assuming Make variables are always exported to Go. Separate
host test context from cross-build context. Default changes and complete metadata
serialization belong to M03/M07; package-based selection belongs to M02.

### N06 — Add explicit coverage scope and machine-readable test results

Metadata: enhancement; P1; M; area test; dependencies P08, N04.

Scope: new coverage selection/skip/coverpkg/covermode controls and test JSON report
target; integration coverage support can be a separate named target in this issue.
Preserve default coverage/test behavior. Add JUnit only as an optional pinned
converter, not a mandatory tool for `test`.

Acceptance: fixture shows cross-package coverage and race-compatible coverage
mode; numeric threshold behavior remains correct. JSON is parseable and preserves
test failure status without a `tee` pipeline masking errors. Document package
selection and exclusions, generated code treatment, empty suites, report location,
and separate unit/integration evidence. Use Go's
[integration coverage support](https://go.dev/doc/build-cover) when implementing it.

### N07 — Add dedicated race, integration, and fuzz workflows

Metadata: enhancement; P2; M; area test; dependencies N01, N02.

Scope: new `test-race`, `test-integration`, and a fuzz target requiring a selected
package/fuzz function and bounded duration. Expose documented environment, tags,
timeout/count, and seed/corpus controls. Existing `test` remains unchanged.

Acceptance: lightweight fixtures demonstrate each mode and expected failure;
integration dependencies are opt-in and never assumed to be live services.
Fuzz requires an unambiguous single package/function selection and does not run
indefinitely in normal CI. Race diagnostics identify C compiler/platform needs.
Use [Go's fuzz tutorial](https://go.dev/doc/tutorial/fuzz) and
[Go security practices](https://go.dev/doc/security/best-practices) for the workflow.

### N08 — Add reproducible benchmark and profiling targets

Metadata: enhancement; P2; M; area test; dependency N01.

Scope: add explicit benchmark selection/count/timeout controls and an opt-in
benchmark-only target; retain benchmark-report's current test-inclusive semantics.
Add CPU/memory profiles and optional benchstat comparison with a pinned tool.

Acceptance: controls appear in executed arguments; outputs identify Go version,
platform, revision, and relevant flags. Profiling requires an appropriate package
selection and does not assume a multi-package profile can be written to one file.
Comparison uses repeated samples and does not claim performance gains from one
run. Raw samples remain available; default benchmark policy changes are M04.

### N09 — Add dependency health and narrowly scoped update commands

Metadata: enhancement; P2; M; area tools; dependency N04.

Scope: read-only outdated-dependency listing, module verification, and an explicit
patch-only update target alongside the existing broad deps-update. Document
go.sum versus tidy drift, private modules, GOPRIVATE/GONOSUMDB/GOPROXY, and toolchain
auto-download implications without exposing credentials.

Acceptance: diagnostics do not mutate go.mod/go.sum; patch-update scope is tested
and fails on errors. Private/offline limitations are clear. Keep broad deps-update
semantics until M05. Explain that mod verify and govulncheck answer different
questions; neither proves that dependencies are free of every defect.

### N10 — Add tag-aware, configurable security scans

Metadata: enhancement; P1; M; areas tools/test; dependencies N02, N03.

Scope: opt-in package/tag/config controls for vulnerability scans; machine-readable
output and optional binary scanning. Document how to analyze production build
contexts and triage findings; do not create a pretend scan of the module-less root.

Acceptance: failure statuses and parseable reports are retained; source/binary
examples use supported govulncheck options verified against the pinned version.
No unconditional suppression or unaudited allowlist. Schedule scans for the
consumer examples where meaningful; tool supply-chain updates are N15.
Reference [Go security guidance](https://go.dev/doc/security/best-practices).

### N11 — Add report manifests and durable diagnostics

Metadata: enhancement; P2; M; areas test/config; dependencies N06, N08, N10.

Scope: new report mode emits a manifest containing tool/Go versions, selections,
revision, artifact paths, and per-stage status. Preserve existing filenames and
the old report target's stop-on-first-failure behavior; add an explicit
collect-all mode for diagnosing multiple failures.

Acceptance: manifest/output directories are configurable; stale outputs cannot
be mistaken for this run's successful reports. Separate stdout/stderr where needed
for machine-readable formats. Collect-all still exits nonzero on required failed
stages and never calls a failed report successful. Reports avoid leaking secrets.

### N12 — Add opt-in cross-platform distribution artifacts

Metadata: enhancement; P2; L; areas build/release; dependencies N01, N05.

Scope: new dist targets accept a declared GOOS/GOARCH matrix, build into platform
subdirectories, archive binaries, and emit full-file checksums. Windows output
names for these new targets include `.exe`. Preserve existing build output names.

Acceptance: validate supported target pairs; cross-build without executing foreign
binaries. Packaging includes approved license/readme data and records revision.
Archives have documented deterministic metadata when requested. CGO cross-builds
require explicit cross-compilers; no promise of arbitrary CGO portability.
Never publish/upload artifacts as a side effect of ordinary build/dist.

### N13 — Add examples and consumer CI templates

Metadata: documentation; P1; M; areas docs/ci; dependencies N04, N06, N07, N10, N12.

Scope: tested examples for flat command, multiple commands, library-only quality
flows, custom version package, generated code/mockery, tagged/cgo code, and
workspace limitations. Provide consumer CI for format/tidy/vet/test/coverage/
security and report upload on failure.

Acceptance: examples use local fixtures or pinned template revisions; no copied
Makefile drift. Explain single-main.go limitations until M02 rather than showing
unsupported multi-file commands as working. CI uses full action SHAs, read-only PR
permissions, explicit tools bootstrap, sensible cache keys, and no global cache
clearing. No production deployment credentials or repository settings required.

### N14 — Improve discoverability and argument handling through additive controls

Metadata: enhancement; P2; M; areas docs/config; dependencies N02, N04.

Scope: new target listing/config summary, optional plain/no-color output honoring
NO_COLOR, and explicit runtime-argument controls for dev/run. Document make flag
syntax and argument boundaries. Add help comments for report subtargets.

Acceptance: existing default appearance is retained; plain output is CI-readable.
Runtime args are forwarded with a defined quoting model tested for spaces and
literal metacharacters; no eval-based dispatcher. Help lists every intended public
target and distinguishes optional tools and mutating commands. Do not promise
arbitrary shell snippets as safe data input; stricter defaults belong to M10.

### N15 — Automate reviewed tool/action updates and release preparation

Metadata: enhancement; P1; M; areas ci/release; dependencies N01, N03.

Scope: automate update proposals for workflow actions and declared tool pins,
including versions stored in Makefile. Add a release preparation/verification
script and dry-run workflow. A bot proposal must trigger fixtures; no automatic
merge or release publication.

Acceptance: updater recognizes existing pins and records upstream references;
does not replace pins with latest. Validate minimum Go requirements, linter config
compatibility, and install paths for upgrades. Preparation updates version fields
and filtered checksum consistently, produces exact artifact/full-file digests,
and refuses dirty/inconsistent candidates without altering user work. Re-running
checks is idempotent. Bot credentials and repository protection remain owner setup.

### N16 — Prepare and validate the v0.2.0 release

Metadata: enhancement; P1; M; areas release/docs; dependencies N01–N15.

Scope: run the compatibility suite and publishable documentation, record all new
targets/variables, identify prospective v1 changes, and prepare release artifacts.

Acceptance: every old valid fixture still passes without adopting new options;
new features have tests/docs. Maintain a compatibility/deprecation table, with
no actual removal or changed default in this release. Verify self-update from a
v0.1 consumer to a v0.2 candidate through controlled downloads, including checksum
failure cases. Prepare immutable tag/release notes and filtered/full-file digest
data. Licensing policy is resolved and accurately stated. Publication requires
separate release authorization.

## 6. Major milestone: v1.0.0

These issues intentionally allow changes to existing behavior. Design notes and
migration instructions are part of the deliverable, not reasons to create vague
research issues instead of implementable work.

### M01 — Define and implement the stable public configuration contract

Metadata: enhancement; P1; L; area config; dependency N16; breaking-change.

Scope: document target names, configuration sources, precedence, private versus
public variables, flags, exit statuses, output paths, and extension points.
Recommended model: project wrapper includes a vendored Gomake core, project
configuration is separate, and internal variables are namespaced. Keep a legacy
adapter only where it gives an explicit, tested migration path.

Acceptance: contract examples cover CLI > project configuration > default
precedence and the intentional environment policy. Do not blanket-enable `make -e`.
Detect invalid enums/numbers and conflicting settings. Create a migration table
for each renamed/removed variable/target. Architecture stays proportionate: the
default deliverable remains usable offline through Make; a Go CLI is not required.

### M02 — Build and run Go packages with explicit service discovery

Metadata: enhancement; P1; L; area build; dependency M01; breaking-change.

Scope: make package-directory builds/runs the standard so sibling files, build
constraints, and non-main.go filenames work. Define automatic command discovery
and explicit mappings, flat layouts, library-only projects, and delegated service
Makefiles. Do not treat every cmd directory as a runnable main package.

Acceptance: multi-file/tagged/generated main fixture builds and runs; support
directories do not become services; library-only validation succeeds without a
fake command. A defined legacy file-build override handles intentionally selected
main.go use. Document custom build output/lifecycle contracts. Exact names remain
literal; any new name grammar gets a migration path. Windows standard-build output
suffix policy is explicit and documented. See
[Go build package/file semantics](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies).

### M03 — Make generation and preparation explicit lifecycle steps

Metadata: enhancement; P1; L; area build; dependencies M01, M02; breaking-change.

Scope: stop executing `go generate` implicitly for every ordinary build. Define
separate build/dev/run/release lifecycle graphs, deliberate opt-in generation,
bake/prepare extension hooks, and exactly-once scope across recursive invocations.
Choose whether no-op bake remains or becomes a documented prepare hook.

Acceptance: default build works on read-only checked-in generated code and cannot
unexpectedly execute generators; opt-in generation runs before compilation once
at its documented scope. Parallel service hooks obey ordering; failures stop the
graph. Document old build/dev side effects and exact migration commands. Do not
silently remove existing hooks without an adapter or migration example.

### M04 — Redesign test, race, coverage, and benchmark defaults

Metadata: enhancement; P1; L; area test; dependencies M01, N06–N08; breaking-change.

Scope: default `test` is ordinary unit testing; race/coverage become explicit
targets or check-profile choices. Default selection includes normal Go packages
without a hardcoded “mocks” substring filter. Define exclusions, tag/test/coverage
selection, benchmark-only behavior, thresholds, and aggregation consistently.

Acceptance: ordinary tests work on supported hosts without requiring a C compiler;
race stays a required supported-host CI profile. A legitimate package containing
“mocks” in its path is included unless explicitly excluded. Coverage policy is
project-configured and no stale/empty output passes. Benchmark-only does not run
normal tests. Document the change from `-v -race -cover`, default 50% threshold,
and test-inclusive benchmark reports; retain explicit ways to request old behavior.

### M05 — Define Go workspace, module, and dependency boundaries

Metadata: enhancement; P1; L; areas config/tools; dependencies M01, M02; breaking-change.

Scope: define execution roots and per-module operations in go.work repositories,
module selection, version package mapping, read-only build/check dependency policy,
and deliberate update/tidy actions. Make broad dependency upgrades opt-in by
name/profile rather than surprising default maintenance behavior.

Acceptance: two-module workspace and nested-module fixtures build/test/verify at
the intended scopes without assuming root go.mod or `go list -m` yields one line.
Each module keeps its own metadata and reports. Missing module/workspace errors
are actionable; simple single-module consumers remain straightforward. Document
private/offline behavior and go.work ownership. Migration explains altered deps
targets and no automatic source/dependency edits during normal build/check.

### M06 — Install tools in an isolated, versioned local toolchain

Metadata: enhancement; P1; L; area tools; dependencies M01, N03; breaking-change.

Scope: default tool binaries live in a project/cache location keyed by tool/version/
host platform, not shared GOPATH/bin. Installation is explicit; normal quality
targets diagnose missing tools without downloading. Decide between an isolated
tools module and verified binary releases per upstream installation guidance.

Acceptance: two projects with different pins do not overwrite one another;
version checks detect stale binaries and concurrent installations cannot expose
partial executables. Consumer go.mod/go.sum stays unchanged by tool bootstrap.
Tool path overrides, offline/cache use, and cleanup scope are documented. If using
Go's tool directives, acknowledge the Go 1.24 introduction and enforce any raised
minimum only with M09, per [Go 1.24 notes](https://go.dev/doc/go1.24#tools).

### M07 — Stabilize reproducible builds and metadata serialization

Metadata: enhancement; P1; L; areas build/release; dependencies M01, M02, N05; breaking-change.

Scope: select documented release/debug defaults for trimpath, symbols, CGO,
version metadata, dirty-tree treatment, timestamps, and build user identity.
Use a complete linker quoting/data transport design rather than silently deleting
apostrophes from input. Prefer optional metadata injection for projects without
a matching package; reject malformed explicit metadata with a clear error.

Acceptance: metadata containing spaces/apostrophes is either faithfully supported
or rejected before a shell/linker ambiguity, with no arbitrary evaluation. Fixed
inputs reproduce artifact hashes within the supported build context. Debug builds
can retain symbols. Ordinary outputs do not leak builder identity without an
explicit choice. Compatibility notes cover stripping, CGO, and metadata defaults;
do not promise deterministic binaries across different Go toolchains.

### M08 — Separate project customization from template updates

Metadata: enhancement; P0; L; areas update/config; dependencies M01, P01, P02; breaking-change.

Scope: updater replaces only the owned vendored core; project config/wrapper files
survive. Add explicit source/revision/digest state, dry-run/diff/backup behavior,
cross-major update checks, and recovery guidance. Replace the checksum-line exclusion
scheme with a full-file digest stored independently for v1 distribution.

Acceptance: customized project settings and hooks survive updates; invalid digests,
moved tags, unsupported refs, and partial downloads leave every owned file intact.
Version/checksum state updates transactionally with the downloaded core, with no
unverified automatic adoption of server-provided trust data. Migrate v0.x users
through an explicit bootstrap procedure; the old updater cannot simply trust an
incompatible full-digest scheme. Document digest source authenticity and offline
manual updates. Any removal of unverified escape behavior is explicit in migration.

### M09 — Publish and enforce the stable support policy

Metadata: enhancement; P1; M; areas ci/docs; dependencies M01, M06; breaking-change.

Scope: decide minimum GNU make, Go, shell/utilities, and host OS requirements based
on exercised fixtures/tool requirements. Recommend Linux/macOS plus documented
Windows-through-WSL use initially; do not promise native Windows shell support
without implementation and CI. Distinguish build target platforms from host support.

Acceptance: exact supported versions/ranges and retirement policy are documented;
doctor and CI enforce them. CI covers the oldest supported Go/make and current
supported Go releases with deliberate pins; race is a host-specific job. Explain
toolchain auto-selection/GOTOOLCHAIN and network requirements. Every dropped
configuration receives a migration note; no claim of support based solely on Go's
ability to cross-compile. Consult [Go toolchains](https://go.dev/doc/toolchain).

### M10 — Define safe path, input, artifact, and cleanup ownership

Metadata: enhancement; P0; L; area config; dependencies M01, M02, P09, P12; breaking-change.

Scope: settle which root/output filenames are supported, how whitespace and
special characters cross make's dependency graph and shell boundaries, what values
are data versus intentional flag lists, and which directories Gomake owns.
Default cleanup removes owned artifacts only; external outputs require explicit
registration/consent in configuration.

Acceptance: test root/output paths with spaces where claimed; reject unsupported
inputs before side effects. Account for symlinks and normalized paths, and validate
all cleanup destinations before deleting anything. Cleanup never follows an
unintended link outside owned scope or uses a corrupted variable as a broad rm
target. Raw shell hooks are explicitly trusted project code, not user data.
Document changes to external directory overrides and artifact naming/ownership.

### M11 — Ship the v0.x-to-v1 migration kit and stable documentation

Metadata: documentation; P1; L; areas docs/config; dependencies M01–M10.

Scope: complete changelog, target/configuration reference, support matrix,
compatibility adapters, before/after examples, and migration checklist.

Acceptance: enumerate every changed default/name/path/side effect across M01–M10.
Exercise migration of a copied customized Makefile, included wrapper, flat command,
multi-service/custom build, and workspace. Explain package builds, generation,
race/coverage, tools, dependencies, metadata, cleanup, and update trust changes.
A migration assistant may inspect and propose edits; it cannot overwrite unknown
customizations automatically. Link exact supported legacy configurations and
state the owner-decided v0.x maintenance/backport policy without inventing dates.

### M12 — Validate release candidates and prepare v1.0.0

Metadata: enhancement; P1; L; areas ci/release; dependency M11.

Scope: cut candidate artifacts such as `v1.0.0-rc.1`, exercise fresh install and
migration, complete release checks, then prepare the stable release.

Acceptance: supported host/make/Go matrix, standard and custom consumer fixtures,
security/quality workflows, distribution, and updater recovery all pass. Each
breaking change has an issue and migration note. External full-file digest manifest
matches released assets; stable public API is documented and versioned. Candidate
feedback has no unresolved P0/P1 defect. Prepare immutable stable tag/release notes;
only publish with release authorization. Never rewrite an existing release tag.

## 7. Dependency order and release gates

Release sequence is P13 → N16 → M12. Fix a serious integrity/correctness defect
on the earliest affected supported line; do not defer it to v1 merely because a
cleaner redesign is planned there. Keep incompatible portions in the M issues.

Suggested execution order:

1. Patch: P00; P01/P02/P12; P03/P04; P05/P06/P07/P08/P09/P10;
   P11; P13. P11 licensing decision can begin immediately.
2. Minor: N01/N02; N03/N05; N04/N07/N08/N09/N10/N14/N15;
   N06/N12; N11/N13; N16. Follow each issue's explicit dependencies.
3. Major: M01; M02/M04/M06/M08/M09/M10 as their dependencies permit;
   M03/M05/M07; M11; M12. M09 follows M06; M10 follows M02.

This order permits independent work, but a single executing agent can follow it
serially. Concurrent edits to the monolithic Makefile require coordination; do
not equate independent issue dependencies with conflict-free file edits.

Every implementation PR must state the issue ID, resulting behavior, compatibility
impact, fixtures exercised, and documentation changes. A target invoking Go needs
a consuming fixture, not only a snapshot of the recipe text. Updating tool pins
requires testing the actual pinned tool or recording a precise blocked check.

Before any release:

- All milestone issues are complete, or the owner explicitly changes scope and
  moves unfinished issues. Do not close issues because the release date arrived.
- Repository CI and documented consumer fixtures pass for the claimed matrix.
- Valid previous-release consumer invocations still work for patch/minor.
- Negative tests cover failure propagation, updater validation, cleanup scope,
  missing tools, and malformed outputs. No host cache deletion in fixtures.
- README/reference/changelog agree with the candidate artifact and version.
- Licensing terms and maintainer reporting/release responsibilities are recorded.
- Artifact digests are computed from final bytes; the filtered v0.x self pin and
  full-file digest are labeled separately. No changes after checksum computation
  without recomputation and verification.
- Tag/release publication and repository settings are distinct owner-authorized
  operations; ordinary quality/build workflows have no write tokens by default.

## 8. Coverage of Go project requirements

| Requirement | Planned coverage |
|---|---|
| Command/library layouts and package builds | P11, N13, M02 |
| Modules, workspaces, private/offline dependencies | P07, N09, M05 |
| Version/toolchain/platform policy | N01/N02, M09 |
| Build flags, tags, cgo, cross-compilation | N05/N12, M02/M07 |
| Unit/race/integration/fuzz tests | P00/P13, N06/N07, M04 |
| Coverage precision, scope, CI artifacts | P08, N06/N11 |
| Benchmarks and profiles | N08, M04 |
| Formatting, vet, static analysis, tidy/generated drift | N04 |
| Vulnerability scans and update review | P01/P02, N10/N15 |
| Mock and code generation tooling/lifecycle | N03/N04/N13, M03 |
| Reproducible tool versions and isolated installs | P03, N03/N15, M06 |
| Metadata and reproducible release artifacts | N05/N12/N15, M07/M12 |
| CLI help, config inspection, actionable errors | P04/P07, N02/N14, M01 |
| Artifact cleanup and update ownership | P02/P12, M08/M10 |
| Documentation, license, contributions, security policy | P11, N13, M11 |
| CI, release history, checksums, migration/support | P13, N01/N15/N16, M09/M11/M12 |

Do not impose irrelevant application architecture. Databases, HTTP frameworks,
Docker/Kubernetes, deployment credentials, hot reload, tracing, pprof web servers,
API schemas, and code generation frameworks depend on the consuming application.
Gomake should expose documented hooks/examples when requested, not require every
Go project to adopt them. A LICENSE decision is necessary; choosing its terms is
the owner's responsibility. SBOMs/signatures/provenance can be added to an actual
binary distribution when its delivery/trust requirements justify them; they are
not substitutes for tests or checksums and are not mandatory template dependencies.

## 9. Luna execution prompt: create the tracker, not implementation

Copy this prompt into Luna with this file available:

> Read `docs/release-plan.md` in `47monad/gomake`. Your task is to create/reconcile
> the GitHub planning artifacts only. Do not implement code, publish releases,
> edit repository protection, or send notifications/messages outside the created
> issues. Create exactly the three milestones specified in section 2 and the
> **42 issues** P00–P13, N01–N16, and M01–M12 from sections 4–6. Use the full
> issue scope and acceptance criteria, not one-line summaries. Preserve each ID
> in its title, e.g. `[P03] Propagate tool installation failures and respect install destinations`.
> Include priority, relative size, areas, compatibility classification, source
> evidence, and dependencies in each issue body. All potentially breaking changes
> stay in v1.0.0. Add/reuse section 3 labels, leave dates/assignees unset, and do
> not change existing label definitions or close unrelated issues.
>
> First read current remote branch/tags/releases, open and closed issues,
> milestones, and labels with pagination. The reviewed snapshot may be stale.
> Compare changes since the recorded revision before treating any finding as
> unresolved. Match existing issues by planning ID or actual scope, not just title.
> Reuse an equivalent open issue and append missing acceptance criteria; link a
> completed closed issue as history rather than reopening or duplicating it.
> If a planned issue is already completely implemented, record that evidence in
> the final mapping and do not create a new work item for completed work. If it is
> partly completed, create/reuse the remaining scope and name what remains.
>
> Use two passes: first create/reconcile milestones, labels, and issue bodies
> with ID dependencies; then resolve IDs to GitHub issue links and update bodies.
> Use structured API arguments or body files so multiline text, backticks, dollar
> signs, and examples remain literal. For gh CLI, write body text to temporary
> files and use `--body-file`; never interpolate issue bodies into shell code.
> If an API create call times out, search for the new item before retrying.
> Preserve all existing issue text when extending a reused item.
>
> Treat owner decisions in P11 as explicit subtasks. Creating their issue does
> not authorize selecting a license or changing legal terms. If permissions block
> writes, provide the exact blocked operation and retain prepared bodies for a
> retry; do not claim successful creation. Authentication must use the existing
> authorized account, with no credentials in output. Normal tool approval for
> network/write access may still be required.
>
> After creation, read all items back. Verify the three milestones, expected
> issue-ID mapping (42 at the reviewed baseline), no duplicate IDs, correct labels,
> complete acceptance criteria, and resolved dependency links. Every issue must
> have exactly one intended milestone. Ensure the dependency graph has no cycle,
> patch/minor issues have no major dependency, and every actual breaking issue is
> in v1.0.0. Treat snapshot changes as explained exceptions, not silent omissions.
> Produce `docs/tracker-map.md` with milestone URLs and a table of plan ID, issue
> number/URL or completed-work evidence, milestone, and status. Summarize created,
> reused, already-completed, and blocked items. Do not move on to implementation
> without a separate user request.

### Issue body template

```markdown
<!-- gomake-plan-id: P03 -->
## Objective
<Concrete final behavior and why it matters>

## Evidence
Reviewed revision: d0742c290dcbe13f51cb562c577509fc94265a97
<Permalink to relevant Makefile/README lines or inventory absence>
<Related closed issue, if applicable; explain remaining scope>

## Scope
<Full issue scope from the plan>

## Compatibility
<Patch repair / additive opt-in / breaking with required migration>

## Acceptance criteria
- [ ] <Each criterion from the plan>

## Dependencies
Blocked by: <Resolved issue links, or None>

## Delivery notes
Priority: P1
Size: S (relative estimate)
Areas: tools
Milestone: v0.1.1 — Correctness and release foundations
```

Evidence permalinks should use the reviewed commit, for example
`https://github.com/47monad/gomake/blob/d0742c290dcbe13f51cb562c577509fc94265a97/Makefile#L357-L371`.
Do not use drifting main-branch line links as the sole evidence.

## 10. Primary sources consulted

These references establish tool behavior, not a claim that all proposed features
are universal requirements. Verify exact flags against the selected pinned tool
versions during implementation.

- [Repository and current code](https://github.com/47monad/gomake/tree/d0742c290dcbe13f51cb562c577509fc94265a97),
  [closed issues](https://github.com/47monad/gomake/issues?q=is%3Aissue+is%3Aclosed),
  [milestones](https://github.com/47monad/gomake/milestones),
  [releases](https://github.com/47monad/gomake/releases).
- [GNU make manual](https://www.gnu.org/software/make/manual/make.html): prerequisite
  graphs, recursive make, variable export, and literal `.PHONY` target names.
- [Go command reference](https://pkg.go.dev/cmd/go): package/file build semantics,
  build/test flags, host/target settings, and module commands.
- [Go toolchains](https://go.dev/doc/toolchain),
  [Go modules reference](https://go.dev/ref/mod), and
  [Go 1.24 tools](https://go.dev/doc/go1.24#tools).
- [Go security best practices](https://go.dev/doc/security/best-practices),
  [Go fuzz tutorial](https://go.dev/doc/tutorial/fuzz), and
  [integration coverage](https://go.dev/doc/build-cover).
- [golangci-lint installation](https://golangci-lint.run/docs/welcome/install/).
  Verified tag refs:
  [golangci-lint v2.14.0](https://github.com/golangci/golangci-lint/tree/v2.14.0),
  [gofumpt v0.12.0](https://github.com/mvdan/gofumpt/tree/v0.12.0),
  [govulncheck v1.8.0](https://github.com/golang/vuln/tree/v1.8.0).
- [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use).
- [Semantic Versioning 2.0.0](https://semver.org/). Go module `/v2` path suffix
  rules do not apply to this v1 Makefile-only release; introducing an importable
  Go module would require its own module API/version design.
