---
phase: 01-flake-scaffold-parser
plan: 02
subsystem: infra
tags: [nix, flake, checks, builtins.fromTOML, runCommand, devshell]

# Dependency graph
requires:
  - 01-01 (flake.nix with devShells + lib/default.nix with fromMiseToml)
provides:
  - flake.nix checks output with parse-toml and devshell-builds derivations
  - nix flake check passing as regression gate for future phases
affects: [02-runtime-tool-resolution, 03-utility-tool-resolution, 04-env-vars, 05-tests-docs-publish]

# Tech tracking
tech-stack:
  added: [pkgs.runCommand, builtins.fromTOML eval-time TOML parsing, checks output pattern]
  patterns: [checks-as-regression-gate, toml-parse-verification-at-eval-time, forAllSystems-checks]

key-files:
  created: []
  modified:
    - flake.nix

key-decisions:
  - "parse-toml check uses builtins.fromTOML at eval time and interpolates the parsed value into the build script — no runtime TOML parser needed"
  - "devshell-builds check forces fromMiseToml evaluation by interpolating the derivation path — eval failure = check failure"
  - "pkgs.runCommand used (not runCommandNoCC which is deprecated)"

requirements-completed: [CORE-01, SHELL-01, SHELL-03]

# Metrics
duration: 5min
completed: 2026-03-23
---

# Phase 1 Plan 02: Checks Output + Phase 1 Integration Summary

**Nix checks output added to flake.nix with parse-toml (verifies builtins.fromTOML tools.node=22) and devshell-builds (forces fromMiseToml evaluation); nix flake check exits 0 — Phase 1 complete**

## Performance

- **Duration:** ~5 min
- **Completed:** 2026-03-23
- **Tasks:** 2 (1 with file changes, 1 verification-only)
- **Files modified:** 1 (flake.nix)

## Accomplishments

- Added `checks = forAllSystems (...)` to flake.nix with two check derivations
- `parse-toml` check: verifies `builtins.fromTOML (builtins.readFile ./mise.toml)` returns tools.node = "22" at build time
- `devshell-builds` check: forces `self.lib.fromMiseToml ./mise.toml { inherit pkgs; }` to evaluate — any eval error fails this check
- `nix build .#checks.x86_64-linux.parse-toml --no-link` exits 0
- `nix build .#checks.x86_64-linux.devshell-builds --no-link` exits 0
- `nix flake check` exits 0 (both checks green for x86_64-linux)
- `nix flake show` shows devShells (4 systems), checks (4 systems), lib: unknown
- `nix develop --command bash -c "echo mise2nix-shell-works"` prints expected output
- All 4 files git-tracked: flake.nix, lib/default.nix, mise.toml, flake.lock

## Task Commits

1. **Task 1: Add checks output with parse-toml and devshell-builds** - `75a49ed` (feat)
2. **Task 2: Verify full Phase 1 integration** - No commit (verification-only, no file changes)

## Files Created/Modified

- `flake.nix` - Added checks = forAllSystems block with parse-toml and devshell-builds check derivations

## Decisions Made

- `builtins.fromTOML` is called at eval time in the parse-toml check; the result (tools.node = "22") is interpolated as a Nix string into the bash build script — this pattern proves TOML parsing at eval time without needing a runtime TOML parser
- `devshell-builds` check references the devShell derivation via `${devShell}` string interpolation — Nix evaluates this at build time, so any fromMiseToml failure surfaces immediately
- `pkgs.runCommand` chosen over `pkgs.runCommandNoCC` (deprecated) per acceptance criteria

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None - both check derivations write actual PASS output to $out and validate real behavior.

## Phase 1 Contract: SATISFIED

| Requirement | Check | Status |
|-------------|-------|--------|
| CORE-01: builtins.fromTOML parses mise.toml | parse-toml check | PASS |
| SHELL-01: devShells.${system}.default exists for all 4 systems | nix flake show | PASS |
| SHELL-03: pkgs.mkShell used exclusively | lib/default.nix + nix develop | PASS |

## Self-Check: PASSED

- flake.nix exists and contains `checks = forAllSystems`, `parse-toml`, `devshell-builds`, `pkgs.runCommand`, `builtins.fromTOML (builtins.readFile ./mise.toml)` — verified
- Commit 75a49ed exists — verified
- Does NOT contain `runCommandNoCC` — verified
- nix flake check exits 0 — verified
- nix develop works — verified

## Next Phase Readiness

- Phase 2 (runtime tool resolution) can proceed immediately
- `nix flake check` is now a regression gate — Phase 2 must keep both checks green
- fromMiseToml already extracts `tools` attrset — Phase 2 maps tool names to version-specific nixpkgs attrs

---
*Phase: 01-flake-scaffold-parser*
*Completed: 2026-03-23*
