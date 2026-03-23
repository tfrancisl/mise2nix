---
phase: 08-interactive-override-patching
plan: "02"
subsystem: wrapper
tags: [nix, bash, writeShellScriptBin, checks, sed, interactive, flake]

requires:
  - phase: 08-interactive-override-patching
    provides: miseWrapper with WRAP-03 interactive prompt and flake.nix patching; pipxKnown/npmKnown/cargoKnown derived at eval time

provides:
  - 4 new nix flake check derivations verifying WRAP-03 behavior (unknown backend abort, unmapped tool abort, known tool no-prompt, sed flake.nix patch)
  - Total check count: 26 (22 existing + 4 new WRAP-03 checks)

affects: []

tech-stack:
  added: []
  patterns:
    - "Inline duplicate miseWrapper in check let blocks with pipxKnown/npmKnown/cargoKnown derived from builtins.attrNames — same pattern as phase 7 checks, extended with WRAP-03 detection logic"
    - "No-TTY abort test: in Nix sandbox /dev/tty is unavailable, read returns empty, wrapper exits 0 with Cancelled message — testable non-interactively"
    - "Sed patch check: exercise the exact sed command from the wrapper in isolation with a fixture flake.nix"

key-files:
  created: []
  modified:
    - flake.nix

key-decisions:
  - "Test no-TTY abort path by running in sandbox — /dev/tty unavailable causes read to return empty, wrapper exits with Cancelled; both 'Cancelled' and 'not in Nix backend tables' match is valid since sandbox may emit the prompt message before the empty-read abort"
  - "Sed patch check tests the patching step directly (not via wrapper) — avoids TTY dependency while still exercising the exact sed pattern"
  - "wrapper-known-tool-no-prompt verifies absence of 'not in Nix backend tables' message AND presence of mise.toml entry — confirms WRAP-02 path is unchanged"

patterns-established:
  - "WRAP-03 check pattern: grep output for 'Cancelled' OR 'not in Nix backend tables' (either is valid in no-TTY sandbox), verify no mise.toml created"

requirements-completed: []

duration: 3min
completed: 2026-03-24
---

# Phase 08 Plan 02: Interactive Override Patching — Check Derivations Summary

**4 nix flake checks covering WRAP-03 behavior: unknown-backend abort, unmapped-tool abort, known-tool WRAP-02 path, and sed flake.nix overrides patching — 26 total checks green**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-24T00:25:22Z
- **Completed:** 2026-03-24T00:28:55Z
- **Tasks:** 4 (all 4 check derivations added together in one commit)
- **Files modified:** 1

## Accomplishments

- Added `wrapper-unknown-backend-no-tty`: verifies that `mise use "ubi:some-tool"` triggers the WRAP-03 abort path in a Nix sandbox (no controlling terminal → empty read → Cancelled)
- Added `wrapper-unmapped-known-backend-no-tty`: verifies that `mise use "pipx:nonexistent_xyz_abc"` (unmapped tool within a known backend) also triggers the abort path
- Added `wrapper-known-tool-no-prompt`: verifies that a known/mapped tool (`pipx:black`) follows the WRAP-02 path — no prompt message, mise.toml written correctly
- Added `wrapper-flake-patch-overrides`: verifies the sed command correctly inserts a new override entry after the `overrides = {` line in a flake.nix fixture
- All 26 `nix flake check` checks pass (22 existing + 4 new)

## Task Commits

1. **Tasks 1-4: Add WRAP-03 check derivations** - `5e20abc` (feat)

## Files Created/Modified

- `flake.nix` — Added 4 new WRAP-03 check derivations (wrapper-unknown-backend-no-tty, wrapper-unmapped-known-backend-no-tty, wrapper-known-tool-no-prompt, wrapper-flake-patch-overrides)

## Decisions Made

- **No-TTY abort test strategy:** In a Nix build sandbox, `/dev/tty` is not a controlling terminal. The `read -r NIX_ATTR </dev/tty` returns empty (or the redirection fails silently), causing `NIX_ATTR` to be empty → wrapper prints `[mise2nix] Cancelled.` and exits 0. The check greps for either "Cancelled" or "not in Nix backend tables" since the sandbox may emit the prompt message before the empty-read abort.
- **Sed patch check in isolation:** Rather than trying to test the full interactive path with file patching (which requires user input), the `wrapper-flake-patch-overrides` check exercises the sed command directly on a fixture. This provides clean coverage of the patching logic without TTY dependency.
- **Known lists derived in check let blocks:** Used the same `builtins.attrNames` pattern as in `lib/default.nix` — `pipxKnown`/`npmKnown`/`cargoKnown` derived from the backend files in the check `let` block, ensuring perfect sync between what the inline wrapper and the real miseWrapper consider "known".

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 08 is now complete — all WRAP-03 checks pass, 26 total checks green
- v0.2.0 milestone is complete: backend syntax detection, mapping tables, mise wrapper core, and interactive override patching all implemented and verified
- No blockers for future development

## Self-Check: PASSED

- FOUND: flake.nix (modified with 4 new checks)
- FOUND: 08-02-SUMMARY.md
- FOUND: commit 5e20abc

---
*Phase: 08-interactive-override-patching*
*Completed: 2026-03-24*
