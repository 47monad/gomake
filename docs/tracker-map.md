# Gomake planning tracker map

Executed: 2026-09-30. Reviewed revision: `d0742c290dcbe13f51cb562c577509fc94265a97`.

This file maps the plan IDs in [`docs/release-plan.md`](release-plan.md) to the
GitHub tracking artifacts created for them. It records the planning tracker only;
no implementation work is included.

## Milestones

| # | Title | URL |
|---|---|---|
| 1 | v0.1.1 — Correctness and release foundations | https://github.com/47monad/gomake/milestone/1 |
| 2 | v0.2.0 — Complete Go workflows | https://github.com/47monad/gomake/milestone/2 |
| 3 | v1.0.0 — Stable contract and migration | https://github.com/47monad/gomake/milestone/3 |

## Labels

Added: `priority:p0`/`p1`/`p2`, `area:build`, `area:test`, `area:tools`,
`area:update`, `area:ci`, `area:docs`, `area:release`, `area:config`,
`breaking-change`, `compatibility-review`, `maintainer-decision`, `size:s`/`m`/`l`.
Reused: `bug`, `enhancement`, `documentation`, `security`.

## Issue map

| Plan ID | Issue | Milestone | Status |
|---|---|---|---|
| P00 | [#38](https://github.com/47monad/gomake/issues/38) | v0.1.1 | created |
| P01 | [#39](https://github.com/47monad/gomake/issues/39) | v0.1.1 | created |
| P02 | [#40](https://github.com/47monad/gomake/issues/40) | v0.1.1 | created |
| P03 | [#41](https://github.com/47monad/gomake/issues/41) | v0.1.1 | created |
| P04 | [#42](https://github.com/47monad/gomake/issues/42) | v0.1.1 | created |
| P05 | [#43](https://github.com/47monad/gomake/issues/43) | v0.1.1 | created |
| P06 | [#44](https://github.com/47monad/gomake/issues/44) | v0.1.1 | created |
| P07 | [#45](https://github.com/47monad/gomake/issues/45) | v0.1.1 | created |
| P08 | [#46](https://github.com/47monad/gomake/issues/46) | v0.1.1 | created |
| P09 | [#47](https://github.com/47monad/gomake/issues/47) | v0.1.1 | created |
| P10 | [#48](https://github.com/47monad/gomake/issues/48) | v0.1.1 | created |
| P11 | [#49](https://github.com/47monad/gomake/issues/49) | v0.1.1 | created |
| P12 | [#50](https://github.com/47monad/gomake/issues/50) | v0.1.1 | created |
| P13 | [#51](https://github.com/47monad/gomake/issues/51) | v0.1.1 | created |
| N01 | [#52](https://github.com/47monad/gomake/issues/52) | v0.2.0 | created |
| N02 | [#53](https://github.com/47monad/gomake/issues/53) | v0.2.0 | created |
| N03 | [#54](https://github.com/47monad/gomake/issues/54) | v0.2.0 | created |
| N04 | [#55](https://github.com/47monad/gomake/issues/55) | v0.2.0 | created |
| N05 | [#56](https://github.com/47monad/gomake/issues/56) | v0.2.0 | created |
| N06 | [#57](https://github.com/47monad/gomake/issues/57) | v0.2.0 | created |
| N07 | [#58](https://github.com/47monad/gomake/issues/58) | v0.2.0 | created |
| N08 | [#59](https://github.com/47monad/gomake/issues/59) | v0.2.0 | created |
| N09 | [#60](https://github.com/47monad/gomake/issues/60) | v0.2.0 | created |
| N10 | [#61](https://github.com/47monad/gomake/issues/61) | v0.2.0 | created |
| N11 | [#62](https://github.com/47monad/gomake/issues/62) | v0.2.0 | created |
| N12 | [#63](https://github.com/47monad/gomake/issues/63) | v0.2.0 | created |
| N13 | [#64](https://github.com/47monad/gomake/issues/64) | v0.2.0 | created |
| N14 | [#65](https://github.com/47monad/gomake/issues/65) | v0.2.0 | created |
| N15 | [#66](https://github.com/47monad/gomake/issues/66) | v0.2.0 | created |
| N16 | [#67](https://github.com/47monad/gomake/issues/67) | v0.2.0 | created |
| M01 | [#68](https://github.com/47monad/gomake/issues/68) | v1.0.0 | created |
| M02 | [#69](https://github.com/47monad/gomake/issues/69) | v1.0.0 | created |
| M03 | [#70](https://github.com/47monad/gomake/issues/70) | v1.0.0 | created |
| M04 | [#71](https://github.com/47monad/gomake/issues/71) | v1.0.0 | created |
| M05 | [#72](https://github.com/47monad/gomake/issues/72) | v1.0.0 | created |
| M06 | [#73](https://github.com/47monad/gomake/issues/73) | v1.0.0 | created |
| M07 | [#74](https://github.com/47monad/gomake/issues/74) | v1.0.0 | created |
| M08 | [#75](https://github.com/47monad/gomake/issues/75) | v1.0.0 | created |
| M09 | [#76](https://github.com/47monad/gomake/issues/76) | v1.0.0 | created |
| M10 | [#77](https://github.com/47monad/gomake/issues/77) | v1.0.0 | created |
| M11 | [#78](https://github.com/47monad/gomake/issues/78) | v1.0.0 | created |
| M12 | [#79](https://github.com/47monad/gomake/issues/79) | v1.0.0 | created |

## Summary

- **Created:** 42 issues (P00–P13 = #38–#51, N01–N16 = #52–#67, M01–M12 = #68–#79).
- **Reused:** none. There were no open issues and no equivalent existing items.
- **Already completed:** none. Earlier fixes (#7, #15, #19, #9/#13) are referenced as
  history in the relevant issues, which cover the remaining scope rather than
  recreating closed work.
- **Blocked:** none. All creates, labels, and milestones succeeded; no operations
  were refused for permissions. Dependency IDs were resolved to issue links in a
  second pass.
- **Owner decisions left as subtasks:** P11 records the licensing decision; issue
  creation does not authorize selecting a license or publishing a release.

## Notes

- Every issue carries exactly one milestone (14 patch, 16 minor, 12 major).
- Every issue carries one type, one priority, and one size label; areas list the
  affected subsystems.
- `breaking-change` is applied only to v1.0.0 issues (M01–M10); M11/M12 are
  documentation and release gates.
- No patch/minor issue depends on a major issue. The dependency graph has no cycle.
- Publishing releases or changing repository protection remains a separate,
  owner-authorized action.
