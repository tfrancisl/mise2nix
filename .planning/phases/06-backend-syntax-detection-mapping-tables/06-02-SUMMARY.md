---
phase: 06-backend-syntax-detection-mapping-tables
plan: "02"
subsystem: testing
tags: [nix, nixpkgs, flake-checks, backend-resolution, pipx, npm, cargo, tryEval]

# Dependency graph
requires:
  - phase: 06-backend-syntax-detection-mapping-tables
    plan: "01"
    provides: resolveBackend function in lib/default.nix, pipx/npm/cargo mapping tables
provides:
  - Six backend resolution check derivations in flake.nix (resolve-pipx-black, resolve-npm-prettier, resolve-cargo-ripgrep, unknown-backend-error, unmapped-tool-error, backend-overrides-win)
  - Regression tests proving BACKEND-01 through BACKEND-05 requirements
  - Fixed force pattern for error-checking checks (seq devShell.drvPath instead of deepSeq nativeBuildInputs)
affects:
  - phase 7 (mise wrapper) — CI baseline established with 18 passing checks
  - phase 8 (interactive override patching)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "builtins.seq devShell.drvPath null to force mkShell evaluation for error checks (avoids stack overflow from deepSeq nativeBuildInputs)"
    - "builtins.tryEval (builtins.seq devShell.drvPath null) pattern for testing that fromMiseToml throws"
    - "builtins.toFile inline TOML fixtures with quoted attrset keys for backend:tool syntax"

key-files:
  created: []
  modified:
    - flake.nix

key-decisions:
  - "Use builtins.seq devShell.drvPath null instead of builtins.deepSeq devShell.nativeBuildInputs devShell to force mkShell evaluation — deepSeq on nativeBuildInputs causes stack overflow; drvPath forces the derivation hash computation which triggers resolve and catches throws"
  - "Fixed pre-existing stack overflow in unsupported-version-error and unknown-tool-error checks as part of this plan (Rule 1 auto-fix) — same root cause as new error checks"

patterns-established:
  - "Pattern: error-testing checks use builtins.tryEval (builtins.seq devShell.drvPath null) to force evaluation and catch throws"
  - "Pattern: success checks use pkgs.runCommand with ${devShell} interpolation to force evaluation"

requirements-completed: [BACKEND-01, BACKEND-02, BACKEND-03, BACKEND-04, BACKEND-05]

# Metrics
duration: 15min
completed: "2026-03-23"
---

# Phase 6 Plan 02: Backend Resolution Check Derivations Summary

**Six nix flake check derivations proving pipx/npm/cargo resolution, unknown backend errors, unmapped tool errors, and override priority — all 18 checks pass with corrected drvPath force pattern**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-23T22:17:16Z
- **Completed:** 2026-03-23T22:32:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added `resolve-pipx-black` check: verifies `"pipx:black" = "latest"` resolves to a valid devShell via python3Packages table (BACKEND-01 + BACKEND-02)
- Added `resolve-npm-prettier` check: verifies `"npm:prettier" = "latest"` resolves via nodePackages table (BACKEND-01 + BACKEND-03)
- Added `resolve-cargo-ripgrep` check: verifies `"cargo:ripgrep" = "latest"` resolves via top-level pkgs (BACKEND-01 + BACKEND-04)
- Added `unknown-backend-error` check: verifies `"ubi:some-tool" = "latest"` throws for unrecognized backend (BACKEND-05)
- Added `unmapped-tool-error` check: verifies `"pipx:nonexistent_tool_xyz" = "latest"` throws for tool not in table (BACKEND-05)
- Added `backend-overrides-win` check: verifies `overrides = {"pipx:black" = pkgs.hello;}` takes priority over backend table (BACKEND-01 + BACKEND-05)
- Fixed pre-existing stack overflow in `unsupported-version-error` and `unknown-tool-error` checks by replacing `deepSeq nativeBuildInputs` with `seq drvPath`
- All 18 `nix flake check` derivations now pass on x86_64-linux

## Task Commits

Each task was committed atomically:

1. **Task 1: Add backend resolution check derivations to flake.nix** - `ad460d3` (feat)

**Plan metadata:** (final docs commit — see below)

## Files Created/Modified

- `flake.nix` - Added 6 backend resolution check derivations after `full-integration`; fixed force pattern in 4 error checks (deepSeq nativeBuildInputs -> seq drvPath)

## Decisions Made

- `builtins.seq devShell.drvPath null` is the correct way to force mkShell evaluation for error-catching checks. `drvPath` computes the derivation hash, which requires evaluating the full `packages` list, which triggers `resolve` and surfaces any throws. `builtins.deepSeq devShell.nativeBuildInputs devShell` causes stack overflow because `nativeBuildInputs` in `mkShell` triggers infinite recursion through the stdenv derivation chain.
- Pre-existing broken checks (`unsupported-version-error` and `unknown-tool-error`) were fixed as part of this task — same root cause as the new error checks would have had without the fix.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed stack overflow in pre-existing error-testing checks**
- **Found during:** Task 1 (Add backend resolution check derivations to flake.nix)
- **Issue:** The plan specified `builtins.tryEval (builtins.deepSeq devShell.nativeBuildInputs devShell)` for error checks. Evaluation of `unsupported-version-error` and `unknown-tool-error` (pre-existing) and `unknown-backend-error` and `unmapped-tool-error` (new) all produced `error: stack overflow (possible infinite recursion)` instead of evaluating to a derivation. `builtins.deepSeq` on `nativeBuildInputs` triggers the full stdenv derivation chain causing infinite recursion.
- **Fix:** Replaced `builtins.tryEval (builtins.deepSeq devShell.nativeBuildInputs devShell)` with `builtins.tryEval (builtins.seq devShell.drvPath null)` in all four error checks (2 pre-existing + 2 new). `drvPath` forces derivation hash computation which evaluates the packages list and surfaces throws without stack overflow.
- **Files modified:** `flake.nix`
- **Verification:** `nix flake check` exits 0 with all 18 checks evaluating to derivations successfully. The 06-01-SUMMARY explicitly documented these as pre-existing failures.
- **Committed in:** `ad460d3` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** Auto-fix necessary for correctness — the plan's force pattern caused stack overflow in all error checks. The fix brings the force pattern in line with how Nix evaluates mkShell. No scope creep.

## Issues Encountered

- Initial attempt using plan-specified `builtins.deepSeq devShell.nativeBuildInputs devShell` pattern caused `error: stack overflow (possible infinite recursion)` on all four error-testing checks. Root cause: `nativeBuildInputs` in mkShell triggers infinite recursion through stdenv chain. Solution: use `builtins.seq devShell.drvPath null` which forces the derivation hash computation (evaluating packages) without traversing the full stdenv chain.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 18 flake checks pass — CI baseline is clean for phases 7 and 8
- Backend detection and resolution are fully verified: pipx, npm, cargo resolution; unknown backend and unmapped tool errors; override priority
- Phase 7 (mise wrapper) can proceed — `pkgs.mise` is auto-included and ready to be replaced by the wrapper

---
*Phase: 06-backend-syntax-detection-mapping-tables*
*Completed: 2026-03-23*

## Self-Check: PASSED

- flake.nix: FOUND
- 06-02-SUMMARY.md: FOUND
- Commit ad460d3: FOUND (feat(06-02): add six backend resolution check derivations to flake.nix)
- All 6 check derivation names present in flake.nix: FOUND
- nix flake check exits 0 with 18 checks passing: VERIFIED
