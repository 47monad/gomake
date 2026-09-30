#!/usr/bin/env bash
#
# Fixture-based regression harness for the Gomake Makefile template.
#
# Gomake is a template, so it must be exercised inside small consumer modules
# rather than by running consumer targets at this repository root (which has no
# go.mod). Every test runs in an isolated temporary directory and copies the
# repository Makefile in; no global Go cache is cleared and no real network
# fetch happens (a curl stub is used for the updater tests).
#
# Usage:
#   scripts/test-gomake.sh              # run every test
#   scripts/test-gomake.sh --list       # list test names
#   scripts/test-gomake.sh --only NAME  # run a single test
#
# Exit status is nonzero if any test fails.

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
MAKEFILE="$REPO_ROOT/Makefile"
REV=d0742c290dcbe13f51cb562c577509fc94265a97

ONLY=""
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --list) LIST=1; shift ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

WORK=""
PASS=0
FAIL=0
FAILED_NAMES=()

log() { printf '%s\n' "$*" >&2; }

cleanup() {
  [ -n "$WORK" ] && rm -rf "$WORK"
  WORK=""
}
trap cleanup EXIT

new_work() {
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/gomake-harness.XXXXXX")
  STUB_BIN="$WORK/stubs/bin"
  STUB_LOG="$WORK/stub.log"
  : > "$STUB_LOG"
  export STUB_LOG
  export STUB_MODULE="example.com/fixture"
  export STUB_PACKAGES="example.com/fixture/cmd/foo example.com/fixture/cmd/bar"
  export STUB_GOPATH="$WORK/gopath"
  export STUB_GOOS="linux"
  export STUB_GOARCH="amd64"
  unset STUB_CURL_SRC STUB_GO_INSTALL_FAIL STUB_GO_GENERATE_FAIL STUB_GO_BUILD_FAIL 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Fixtures and stubs
# ---------------------------------------------------------------------------

make_module() { # <dir> [module-path]
  local dir=$1 mod=${2:-example.com/fixture}
  mkdir -p "$dir"
  printf 'module %s\n\ngo 1.21\n' "$mod" > "$dir/go.mod"
  cp "$MAKEFILE" "$dir/Makefile"
}

write_main() { # <file>
  cat > "$1" <<'GO'
package main

func main() { println("hello") }
GO
}

write_stubs() {
  mkdir -p "$STUB_BIN"

  cat > "$STUB_BIN/go" <<'SH'
#!/usr/bin/env bash
printf 'go %s\n' "$*" >> "${STUB_LOG:-/dev/null}"
cmd=${1:-}; shift || true
case "$cmd" in
  env)
    case "${1:-}" in
      GOPATH) echo "${STUB_GOPATH:-/tmp/stub-gopath}" ;;
      GOOS)   echo "${STUB_GOOS:-linux}" ;;
      GOARCH) echo "${STUB_GOARCH:-amd64}" ;;
      *)      echo "" ;;
    esac ;;
  list)
    if [ "${1:-}" = "-m" ]; then echo "${STUB_MODULE:-example.com/fixture}"; else
      for p in ${STUB_PACKAGES:-example.com/fixture}; do echo "$p"; done
    fi ;;
  version) echo "go version go1.99-fake ${STUB_GOOS:-linux}/${STUB_GOARCH:-amd64}" ;;
  install)  [ "${STUB_GO_INSTALL_FAIL:-0}" = 1 ] && { echo "fake go: install failed" >&2; exit 1; } ;;
  generate) [ "${STUB_GO_GENERATE_FAIL:-0}" = 1 ] && { echo "fake go: generate failed" >&2; exit 1; } ;;
  build|test) [ "${STUB_GO_BUILD_FAIL:-0}" = 1 ] && { echo "fake go: build failed" >&2; exit 1; } ;;
esac
exit 0
SH

  # curl stub: never touches the network; copies STUB_CURL_SRC to the -o target.
  cat > "$STUB_BIN/curl" <<'SH'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "${STUB_LOG:-/dev/null}"
out=""
args=("$@")
for ((i=0;i<${#args[@]};i++)); do [ "${args[$i]}" = "-o" ] && out="${args[$((i+1))]}"; done
if [ -n "${STUB_CURL_SRC:-}" ] && [ -n "$out" ]; then cp "$STUB_CURL_SRC" "$out"; exit 0; fi
echo "fake curl: refusing network access" >&2
exit 1
SH

  local t
  for t in golangci-lint gofumpt govulncheck mockery; do
    local var="STUB_${t//-/_}_FAIL"
    cat > "$STUB_BIN/$t" <<SH
#!/usr/bin/env bash
printf '$t %s\n' "\$*" >> "\${STUB_LOG:-/dev/null}"
exit "\${$var:-0}"
SH
  done
  chmod +x "$STUB_BIN"/*
}

# ---------------------------------------------------------------------------
# Execution helpers
# ---------------------------------------------------------------------------

USE_STUBS=0
MAKE_RC=0

run_make() { # <dir> <outfile> [make args...]
  local dir=$1 out=$2; shift 2
  if [ "$USE_STUBS" = 1 ]; then
    ( cd "$dir" && PATH="$STUB_BIN:$PATH" make "$@" ) >"$out" 2>&1
  else
    ( cd "$dir" && make "$@" ) >"$out" 2>&1
  fi
  MAKE_RC=$?
}

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

filtered_digest() { # digest of a Makefile excluding its GOMAKE_SHA256 assignment
  sed '/^GOMAKE_SHA256[[:space:]]*[?]*=/d' "$1" | {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi
  } | awk '{print $1}'
}

has() { grep -qF -- "$2" "$1"; }

rewrite_pin() { # <file> <digest> : replace the GOMAKE_SHA256 assignment value
  sed -E "s/^GOMAKE_SHA256[[:space:]]*\\?=.*/GOMAKE_SHA256 ?= $2/" "$1" > "$1.new" && mv "$1.new" "$1"
}

make_selfconsistent() { # <file> : pin the file to its own filtered digest; print the digest
  local f=$1 dig
  dig=$(filtered_digest "$f")
  rewrite_pin "$f" "$dig"
  printf '%s' "$dig"
}

# ---------------------------------------------------------------------------
# Tests. Each prints a reason and returns 1 on failure.
# ---------------------------------------------------------------------------

TESTS=(
  help_capitalization
  help_disclaimer_percent
  help_and_service_listing
  deps_tidy_label
  clean_scope_static
  lint_report_flag_static
  bench_flags_static
  no_dead_build_flag_static
  coverage_error_helper_static
  build_flat_real
  build_multi_real
  build_multi_serial
  custom_service_makefile
  no_services_error
  unknown_service_run_fast
  unknown_service_build_fast
  generate_once_parallel
  bin_dir_override
  self_update_verify_ok
  self_update_mismatch
  updater_rejects_expression
  updater_rejects_duplicate
  updater_rejects_forged_pin
  updater_rejects_branch_ref
  updater_missing_hash_tool
  updater_download_failure
  updater_rejects_caller_pin
  report_requires_tools
)

if [ "$LIST" = 1 ]; then printf '%s\n' "${TESTS[@]}"; exit 0; fi

t_help_capitalization() { # regression #14
  local d="$WORK/my_project"
  make_module "$d"
  USE_STUBS=1
  run_make "$d" "$WORK/out" help
  [ "$MAKE_RC" = 0 ] || { log "  make help exited $MAKE_RC"; return 1; }
  has "$WORK/out" "My project" || { log "  expected 'My project' in help"; return 1; }
  return 0
}

t_help_disclaimer_percent() { # regression #19
  local d="$WORK/pct"
  make_module "$d"
  USE_STUBS=0
  run_make "$d" "$WORK/out" help DISCLAIMER='a %s b'
  has "$WORK/out" "a %s b" || { log "  DISCLAIMER with % and spaces was corrupted"; return 1; }
  return 0
}

t_help_and_service_listing() {
  local d="$WORK/multi"
  make_module "$d"
  mkdir -p "$d/cmd/foo" "$d/cmd/bar"
  write_main "$d/cmd/foo/main.go"; write_main "$d/cmd/bar/main.go"
  USE_STUBS=0
  run_make "$d" "$WORK/out" help
  has "$WORK/out" "Available targets:" || { log "  help missing target list"; return 1; }
  has "$WORK/out" "Service list:" || { log "  help missing service list"; return 1; }
  has "$WORK/out" "foo" && has "$WORK/out" "bar" || { log "  help did not list services"; return 1; }
  return 0
}

t_deps_tidy_label() { # regression #18
  local d="$WORK/labels"
  make_module "$d"
  USE_STUBS=0
  run_make "$d" "$WORK/out" help
  has "$WORK/out" "Tidy dependencies" || { log "  deps-tidy label not 'Tidy dependencies'"; return 1; }
  return 0
}

t_clean_scope_static() { # regression #10
  local d="$WORK/clean"
  make_module "$d"
  USE_STUBS=0
  run_make "$d" "$WORK/out" -n clean
  if has "$WORK/out" "go clean -cache"; then log "  clean still clears the global cache"; return 1; fi
  run_make "$d" "$WORK/out2" -n clean-all
  has "$WORK/out2" "go clean -cache -testcache" || { log "  clean-all missing global cache clear"; return 1; }
  return 0
}

t_lint_report_flag_static() { # regression #12
  local d="$WORK/lint"
  make_module "$d"
  USE_STUBS=0
  run_make "$d" "$WORK/out" -n lint-report
  has "$WORK/out" "--output.checkstyle.path" || { log "  lint-report missing v2 flag"; return 1; }
  if has "$WORK/out" "--out-format"; then log "  lint-report still uses removed flag"; return 1; fi
  return 0
}

t_bench_flags_static() { # regression #11
  local d="$WORK/bench"
  make_module "$d"
  USE_STUBS=0
  run_make "$d" "$WORK/out" -n benchmark-report
  has "$WORK/out" "-benchtime=" || { log "  benchmark-report missing -benchtime"; return 1; }
  return 0
}

t_no_dead_build_flag_static() { # regression #4
  local d="$WORK/flag"
  make_module "$d"
  USE_STUBS=0
  run_make "$d" "$WORK/out" -n build-foo
  if has "$WORK/out" "ENABLE_BUILD_CACHE"; then log "  dead ENABLE_BUILD_CACHE still referenced"; return 1; fi
  return 0
}

t_coverage_error_helper_static() { # regression #5
  local d="$WORK/cov"
  make_module "$d"
  USE_STUBS=0
  run_make "$d" "$WORK/out" -n coverage
  has "$WORK/out" "is below threshold" || { log "  coverage threshold message missing"; return 1; }
  if has "$WORK/out" "NERROR"; then log "  coverage still references the undefined NERROR"; return 1; fi
  return 0
}

t_build_flat_real() { # regression #6/#9
  local d="$WORK/flat"
  make_module "$d"
  mkdir -p "$d/cmd"; write_main "$d/cmd/main.go"
  USE_STUBS=0
  run_make "$d" "$WORK/out" build
  [ "$MAKE_RC" = 0 ] || { log "  make build exited $MAKE_RC"; return 1; }
  [ -x "$d/bin/main" ] || { log "  bin/main was not produced"; return 1; }
  return 0
}

t_build_multi_real() { # regression #9
  local d="$WORK/multi"
  make_module "$d"
  mkdir -p "$d/cmd/foo" "$d/cmd/bar"
  write_main "$d/cmd/foo/main.go"; write_main "$d/cmd/bar/main.go"
  USE_STUBS=0
  run_make "$d" "$WORK/out" build
  [ "$MAKE_RC" = 0 ] || { log "  make build exited $MAKE_RC"; return 1; }
  [ -x "$d/bin/foo" ] && [ -x "$d/bin/bar" ] || { log "  expected bin/foo and bin/bar"; return 1; }
  return 0
}

t_build_multi_serial() {
  local d="$WORK/serial"
  make_module "$d"
  mkdir -p "$d/cmd/foo" "$d/cmd/bar"
  write_main "$d/cmd/foo/main.go"; write_main "$d/cmd/bar/main.go"
  USE_STUBS=0
  run_make "$d" "$WORK/out" build BUILD_SYSTEM=ci
  [ "$MAKE_RC" = 0 ] || { log "  serial build exited $MAKE_RC"; return 1; }
  [ -x "$d/bin/foo" ] && [ -x "$d/bin/bar" ] || { log "  serial build missing artifacts"; return 1; }
  return 0
}

t_custom_service_makefile() {
  local d="$WORK/custom"
  make_module "$d"
  mkdir -p "$d/cmd/foo"
  write_main "$d/cmd/foo/main.go"
  cat > "$d/cmd/foo/Makefile" <<'MK'
build:
	@echo "delegated-build" > "$(CURDIR)/../../bin/delegated"
MK
  USE_STUBS=0
  run_make "$d" "$WORK/out" build-foo
  [ "$MAKE_RC" = 0 ] || { log "  build-foo exited $MAKE_RC"; return 1; }
  [ -f "$d/bin/delegated" ] || { log "  custom service Makefile was not delegated to"; return 1; }
  return 0
}

t_no_services_error() {
  local d="$WORK/empty"
  make_module "$d"
  USE_STUBS=0
  run_make "$d" "$WORK/out" build
  [ "$MAKE_RC" != 0 ] || { log "  build with no services should fail"; return 1; }
  has "$WORK/out" "No services found" || { log "  missing friendly no-services error"; return 1; }
  return 0
}

t_unknown_service_run_fast() { # regression #7
  local d="$WORK/unknown"
  make_module "$d"
  mkdir -p "$d/cmd/foo"; write_main "$d/cmd/foo/main.go"
  USE_STUBS=1
  run_make "$d" "$WORK/out" run-bar
  [ "$MAKE_RC" != 0 ] || { log "  run-bar should fail"; return 1; }
  has "$WORK/out" "'bar' is not a valid service" || { log "  missing friendly unknown-service error"; return 1; }
  if grep -q '^go build' "$STUB_LOG"; then log "  unknown service triggered a build"; return 1; fi
  return 0
}

t_unknown_service_build_fast() {
  local d="$WORK/unknown2"
  make_module "$d"
  mkdir -p "$d/cmd/foo"; write_main "$d/cmd/foo/main.go"
  USE_STUBS=1
  run_make "$d" "$WORK/out" build-bar
  [ "$MAKE_RC" != 0 ] || { log "  build-bar should fail"; return 1; }
  has "$WORK/out" "'bar' is not a valid service" || { log "  missing friendly error"; return 1; }
  return 0
}

t_generate_once_parallel() { # regression #13
  local d="$WORK/gen"
  make_module "$d"
  mkdir -p "$d/cmd/foo" "$d/cmd/bar"
  write_main "$d/cmd/foo/main.go"; write_main "$d/cmd/bar/main.go"
  USE_STUBS=1
  run_make "$d" "$WORK/out" build
  [ "$MAKE_RC" = 0 ] || { log "  fake build exited $MAKE_RC"; return 1; }
  local n
  n=$(grep -c '^go generate' "$STUB_LOG" || true)
  [ "$n" = 1 ] || { log "  expected exactly one 'go generate', saw $n"; return 1; }
  return 0
}

t_bin_dir_override() {
  local d="$WORK/override"
  make_module "$d"
  mkdir -p "$d/cmd/foo"; write_main "$d/cmd/foo/main.go"
  USE_STUBS=0
  run_make "$d" "$WORK/out" build-foo BIN_DIR="$WORK/custombin"
  [ "$MAKE_RC" = 0 ] || { log "  build-foo exited $MAKE_RC"; return 1; }
  [ -x "$WORK/custombin/foo" ] || { log "  BIN_DIR override not honored"; return 1; }
  return 0
}

t_self_update_verify_ok() { # regression #15 / P01
  local d="$WORK/upd"; make_module "$d"
  local dig; dig=$(make_selfconsistent "$d/Makefile")
  cp "$d/Makefile" "$WORK/staged"; export STUB_CURL_SRC="$WORK/staged"
  USE_STUBS=1
  run_make "$d" "$WORK/out" self-update GOMAKE_REF=v9.9.9 GOMAKE_SHA256="$dig"
  [ "$MAKE_RC" = 0 ] || { log "  exit $MAKE_RC"; return 1; }
  has "$WORK/out" "already up to date" || { log "  expected 'already up to date'"; return 1; }
  return 0
}

t_self_update_mismatch() { # regression #15 / P01
  local d="$WORK/updbad"; make_module "$d"
  make_selfconsistent "$d/Makefile" >/dev/null
  cp "$d/Makefile" "$WORK/staged2"; export STUB_CURL_SRC="$WORK/staged2"
  local before; before=$(hash_file "$d/Makefile")
  USE_STUBS=1
  run_make "$d" "$WORK/out" self-update GOMAKE_REF=v9.9.9 \
    GOMAKE_SHA256=0000000000000000000000000000000000000000000000000000000000000000
  [ "$MAKE_RC" != 0 ] || { log "  mismatched checksum should fail"; return 1; }
  has "$WORK/out" "checksum mismatch" || { log "  missing checksum mismatch message"; return 1; }
  [ "$(hash_file "$d/Makefile")" = "$before" ] || { log "  Makefile changed on failed update"; return 1; }
  return 0
}

t_updater_rejects_expression() { # P01
  local d="$WORK/updexpr"; make_module "$d"
  local dig; dig=$(filtered_digest "$d/Makefile")
  cp "$d/Makefile" "$WORK/staged"
  sed -E 's/^GOMAKE_SHA256.*/GOMAKE_SHA256 ?= $(shell echo pwned)/' "$WORK/staged" > "$WORK/staged.new"
  mv "$WORK/staged.new" "$WORK/staged"
  export STUB_CURL_SRC="$WORK/staged"
  USE_STUBS=1
  run_make "$d" "$WORK/out" self-update GOMAKE_REF=v9.9.9 GOMAKE_SHA256="$dig"
  [ "$MAKE_RC" != 0 ] || { log "  Make-expression pin should be rejected"; return 1; }
  has "$WORK/out" "must be exactly one literal" || { log "  missing structural rejection"; return 1; }
  return 0
}

t_updater_rejects_duplicate() { # P01
  local d="$WORK/upddup"; make_module "$d"
  local dig; dig=$(filtered_digest "$d/Makefile")
  cp "$d/Makefile" "$WORK/staged"
  printf 'GOMAKE_SHA256 ?= %s\n' "$dig" >> "$WORK/staged"
  export STUB_CURL_SRC="$WORK/staged"
  USE_STUBS=1
  run_make "$d" "$WORK/out" self-update GOMAKE_REF=v9.9.9 GOMAKE_SHA256="$dig"
  [ "$MAKE_RC" != 0 ] || { log "  duplicate pin should be rejected"; return 1; }
  has "$WORK/out" "must be exactly one literal" || { log "  missing duplicate rejection"; return 1; }
  return 0
}

t_updater_rejects_forged_pin() { # P01
  local d="$WORK/updforge"; make_module "$d"
  cp "$d/Makefile" "$WORK/staged"   # embedded pin is the repo's, not the staged file's own digest
  local dig; dig=$(filtered_digest "$WORK/staged")
  export STUB_CURL_SRC="$WORK/staged"
  USE_STUBS=1
  run_make "$d" "$WORK/out" self-update GOMAKE_REF=v9.9.9 GOMAKE_SHA256="$dig"
  [ "$MAKE_RC" != 0 ] || { log "  forged embedded pin should be rejected"; return 1; }
  has "$WORK/out" "does not match its own filtered digest" || { log "  missing self-consistency error"; return 1; }
  return 0
}

t_updater_rejects_branch_ref() { # P01
  local d="$WORK/updbranch"; make_module "$d"
  local dig; dig=$(make_selfconsistent "$d/Makefile")
  cp "$d/Makefile" "$WORK/staged"; export STUB_CURL_SRC="$WORK/staged"
  USE_STUBS=1
  run_make "$d" "$WORK/out" self-update GOMAKE_REF=main GOMAKE_SHA256="$dig"
  [ "$MAKE_RC" != 0 ] || { log "  branch ref should be rejected"; return 1; }
  has "$WORK/out" "moving branch" || { log "  missing branch-ref message"; return 1; }
  return 0
}

t_updater_missing_hash_tool() { # P01
  local d="$WORK/updhash"; make_module "$d"
  local dig; dig=$(make_selfconsistent "$d/Makefile")
  cp "$d/Makefile" "$WORK/staged"; export STUB_CURL_SRC="$WORK/staged"
  USE_STUBS=1
  run_make "$d" "$WORK/out" self-update GOMAKE_REF=v9.9.9 GOMAKE_SHA256="$dig" SHA256="$WORK/no-such-hash"
  [ "$MAKE_RC" != 0 ] || { log "  missing hash tool should fail"; return 1; }
  has "$WORK/out" "no SHA-256 tool" || { log "  missing hash-tool message"; return 1; }
  return 0
}

t_updater_download_failure() { # P01
  local d="$WORK/updfail"; make_module "$d"
  USE_STUBS=1
  run_make "$d" "$WORK/out" self-update GOMAKE_REF=v9.9.9
  [ "$MAKE_RC" != 0 ] || { log "  download failure should fail"; return 1; }
  has "$WORK/out" "download failed" || { log "  missing download-failure message"; return 1; }
  return 0
}

t_updater_rejects_caller_pin() { # P01
  local d="$WORK/updpin"; make_module "$d"
  make_selfconsistent "$d/Makefile" >/dev/null
  cp "$d/Makefile" "$WORK/staged"; export STUB_CURL_SRC="$WORK/staged"
  USE_STUBS=1
  run_make "$d" "$WORK/out" self-update GOMAKE_REF=v9.9.9 GOMAKE_SHA256=not-a-digest
  [ "$MAKE_RC" != 0 ] || { log "  invalid caller pin should fail"; return 1; }
  has "$WORK/out" "not a literal SHA-256" || { log "  missing invalid-pin message"; return 1; }
  return 0
}

t_report_requires_tools() { # regression #16
  local d="$WORK/report"
  make_module "$d"
  mkdir -p "$d/pkg"; printf 'package pkg\n\nfunc F() {}\n' > "$d/pkg/pkg.go"
  USE_STUBS=0
  run_make "$d" "$WORK/out" report \
    GOLANGCI_LINT="$WORK/nope-golangci-lint" GOVULNCHECK="$WORK/nope-govulncheck"
  [ "$MAKE_RC" != 0 ] || { log "  report should fail when tools are missing"; return 1; }
  has "$WORK/out" "is not installed; run 'make tools'" || { log "  missing actionable tool error"; return 1; }
  return 0
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

ALL_TESTS="${TESTS[*]}"

run_test() {
  local name=$1
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && return 0
  new_work
  write_stubs
  if "t_$name"; then
    PASS=$((PASS+1)); log "ok   - $name"
  else
    FAIL=$((FAIL+1)); FAILED_NAMES+=("$name"); log "FAIL - $name"
  fi
  cleanup
}

main() {
  if [ ! -f "$MAKEFILE" ]; then echo "Makefile not found at $MAKEFILE" >&2; exit 2; fi
  local name
  for name in $ALL_TESTS; do run_test "$name"; done
  log ""
  log "passed: $PASS  failed: $FAIL  (reviewed revision $REV)"
  if [ "$FAIL" != 0 ]; then
    log "failed tests: ${FAILED_NAMES[*]}"
    exit 1
  fi
  exit 0
}

main
