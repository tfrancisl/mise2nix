---
phase: 08-interactive-override-patching
plan: "01"
subsystem: wrapper
tags: [nix, bash, writeShellScriptBin, sed, interactive, flake]

requires:
  - phase: 07-mise-wrapper-core
    provides: miseWrapper writeShellScriptBin intercepting mise use; all non-use subcommands pass through

provides:
  - pipxKnown/npmKnown/cargoKnown lists derived from backend attrsets via builtins.attrNames at eval time
  - miseWrapper detects unknown backends and unmapped tools within known backends
  - Interactive prompt reads nixpkgs attr from /dev/tty; strips pkgs. prefix
  - Empty input or Ctrl-C aborts cleanly with no file modifications
  - Walk-up flake.nix discovery and sed-patch of overrides = { block
  - Known/mapped tool path unchanged (WRAP-02 preserved)

affects: [08-02-checks, future-phases-using-miseWrapper]

tech-stack:
  added: []
  patterns:
    - "Derive known-tool lists from builtins.attrNames on backend attrsets; interpolate into bash via Nix string interpolation — zero drift between tables and detection logic"
    - "Read from /dev/tty for interactive prompt inside writeShellScriptBin (script's stdin may be redirected)"
    - "Walk-up directory traversal using dirname loop until parent == FLAKE_DIR (root sentinel)"

key-files:
  created: []
  modified:
    - lib/default.nix

key-decisions:
  - "Known-tool lists derived from builtins.attrNames at Nix eval time — zero drift with backend tables (D-02)"
  - "Empty input or Ctrl-C → no files modified, print [mise2nix] Cancelled. and exit 0 (D-06)"
  - "flake.nix patching: pure shell/sed, no Nix AST manipulation (D-07)"
  - "When no overrides = { block found: print manual hint rather than attempt fragile injection (D-08)"
  - "Walk up from $PWD toward filesystem root; skip patching if no flake.nix found (D-09)"
  - "Read interactive input via read -r NIX_ATTR </dev/tty — not stdin — so prompt works when wrapper called from scripts"

patterns-established:
  - "Interactive prompt pattern: trap SIGINT, read from /dev/tty, trap - INT after read"
  - "flake.nix patch: grep for 'overrides = {' then sed /overrides = {/a\\ new_entry"

requirements-completed: [WRAP-03]

duration: 2min
completed: 2026-03-24
---

# Phase 08 Plan 01: Interactive Override Patching — Wrapper Extension Summary

**miseWrapper extended with interactive nixpkgs attribute prompt and flake.nix overrides patching for unknown/unmapped backend tools**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-24T00:06:42Z
- **Completed:** 2026-03-24T00:08:58Z
- **Tasks:** 3 (implemented together in lib/default.nix)
- **Files modified:** 1

## Accomplishments

- Added `pipxKnown`, `npmKnown`, `cargoKnown` bindings derived from `builtins.attrNames` on backend attrsets — interpolated into the bash script at Nix eval time so detection logic is always in sync with Nix tables
- Extended miseWrapper with detection logic: unknown backend (not pipx/npm/cargo) or unmapped tool within a known backend triggers interactive prompt; known/mapped tools continue to the existing WRAP-02 path unchanged
- Interactive prompt reads from `/dev/tty`, handles empty input and Ctrl-C as clean aborts (no file modifications), strips `pkgs.` prefix from user input, writes to `mise.toml`, then patches nearest `flake.nix` overrides block via sed walk-up discovery
- All 22 existing `nix flake check` checks pass with no regressions

## Task Commits

1. **Tasks 1-3: Add known-tool lists + interactive prompt + flake.nix patching** - `7bc95ab` (feat)

## Files Created/Modified

- `lib/default.nix` — Added `pipxKnown`/`npmKnown`/`cargoKnown` let bindings; extended `miseWrapper` with WRAP-03 detection/prompt/patching logic

## Decisions Made

- **Known-tool list derivation (D-02):** Used `builtins.concatStringsSep " " (builtins.attrNames ...)` — the space-separated string gets interpolated into bash at Nix eval time; loop `for k in $KNOWN_LIST` iterates over it correctly.
- **TTY read (not stdin):** `read -r NIX_ATTR </dev/tty` ensures prompt works even when the wrapper is invoked from a script that redirects stdin.
- **flake.nix not found → skip with hint:** Walking up to filesystem root and finding nothing emits a warning + manual instruction. Better than failing loudly when the user is experimenting outside a flake project.
- **Missing overrides block → hint only (D-08):** Injecting a fresh `overrides = { ... }` argument with sed across arbitrary Nix syntax is fragile. A clear manual instruction is more robust and transparent.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 08-02 (check derivations) can now add non-interactive tests for the unknown-tool detection path
- The wrapper correctly handles all 4 WRAP-03 cases: unknown backend, unmapped known-backend tool, empty input abort, Ctrl-C abort
- Existing wrapper checks (wrapper-passthrough, wrapper-use-writes-toml, wrapper-use-prints-message) still pass — no regressions

## Self-Check: PASSED

- FOUND: lib/default.nix
- FOUND: 08-01-SUMMARY.md
- FOUND: commit 7bc95ab

---
*Phase: 08-interactive-override-patching*
*Completed: 2026-03-24*
