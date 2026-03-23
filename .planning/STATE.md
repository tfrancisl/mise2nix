---
gsd_state_version: 1.0
milestone: v0.1.0
milestone_name: milestone
status: Ready to plan
stopped_at: Completed 03-utility-tool-resolution-overrides-api/03-03-PLAN.md
last_updated: "2026-03-23T02:51:04.872Z"
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 7
  completed_plans: 7
---

# Project State: mise2nix

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-22)

**Core value:** `mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; }` produces a working devShell — zero manual Nix required for common toolsets.
**Current focus:** Phase 1 complete — both plans done; Phase 2 (runtime tool resolution) is next

## Current Phase

**Phase 3: Utility Tool Resolution + Overrides API** — IN PROGRESS (1/3 plans done).

**Next action:** Continue Phase 3 (Plan 02: integrate utilities tier into fromMiseToml + overrides API)

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 1 | Flake Scaffold + Parser | Complete (2/2 plans done) |
| 2 | Runtime Tool Resolution | Complete (1/1 plans done) |
| 3 | Utility Tool Resolution + Overrides API | In Progress (1/3 plans done) |
| 4 | Env Vars + Full devShell Assembly | Pending |
| 5 | Tests, Documentation, and Publish | Pending |

## Decisions

- lib output is NOT wrapped in forAllSystems — fromMiseToml takes pkgs as argument for system-specificity (matches uv2nix pattern)
- forAllSystems uses explicit 4-system list via nixpkgs.lib.genAttrs — no flake-utils dependency
- Phase 1 fromMiseToml returns pkgs.mkShell { packages = []; } — tool resolution deferred to Phase 2
- builtins.toString applied in lib/default.nix at call site (consistent for future Phase 3 utility tier)
- Single-version runtimes (rust, deno, bun, terraform, kubectl) silently map all version strings
- Resolver aliases (nodejs, golang) use shared let-bound functions to avoid rec attrset self-reference
- [Phase 02-runtime-tool-resolution]: builtins.toFile used for inline latest TOML fixture to avoid adding mise-latest.toml to repo
- [Phase 03-01]: All utility resolvers take _version (ignored) — nixpkgs pin provides a single version per tool
- [Phase 03-01]: make maps to pkgs.gnumake (pkgs.make does not exist in nixpkgs)
- [Phase 03-01]: rg provided as alias for ripgrep so both mise tool names work
- [Phase 03]: overrides values are derivations directly (not functions) — simpler API matching CORE-04 requirement
- [Phase 03]: Resolution cascade order: overrides -> runtimes -> utilities -> throw (user overrides always win)
- [Phase 03]: Error message names the specific tool and explains both escape hatches (DX-01 compliance)
- [Phase 03-utility-tool-resolution-overrides-api]: unknown-tool-error check uses builtins.deepSeq devShell.nativeBuildInputs to force lazy package evaluation before tryEval
- [Phase 03-utility-tool-resolution-overrides-api]: builtins.toFile used for inline TOML fixtures in check derivations to avoid adding test files to repo

## Performance Metrics

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 01-flake-scaffold-parser | 01 | 2min | 2 | 4 |
| 01-flake-scaffold-parser | 02 | 5min | 2 | 1 |
| 02-runtime-tool-resolution | 01 | 2min | 2 | 2 |
| Phase 02-runtime-tool-resolution P02 | 3min | 2 tasks | 1 files |
| 03-utility-tool-resolution-overrides-api | 01 | 1min | 1 | 1 |
| Phase 03-utility-tool-resolution-overrides-api P02 | 1min | 2 tasks | 2 files |
| Phase 03-utility-tool-resolution-overrides-api P03 | 3min | 1 tasks | 1 files |

## Notes

- No flake-utils — expose simple `forAllSystems` directly
- Pure Nix only (builtins.fromTOML for parsing)
- Two-tier resolution: runtimes get version-matched attrs, utilities get pkgs.X
- flake.nix, lib/default.nix, mise.toml, flake.lock all committed and git-tracked
- nix flake show: devShells for 4 systems, checks for 4 systems, lib: unknown (expected)
- nix flake check: exits 0 (parse-toml and devshell-builds checks green)
- nix develop --command bash -c "echo mise2nix-shell-works" prints expected output

## Last Session

**Stopped at:** Completed 03-utility-tool-resolution-overrides-api/03-03-PLAN.md
**Timestamp:** 2026-03-23T02:40:00Z

---
*Initialized: 2026-03-22*
*Last updated: 2026-03-23*
