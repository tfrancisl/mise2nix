---
phase: 03-utility-tool-resolution-overrides-api
plan: 03
subsystem: flake
tags: [nix, checks, utility-resolution, overrides, extraPackages, error-handling, testing]
dependency_graph:
  requires: [03-02]
  provides: [flake.nix checks for Phase 3 features]
  affects: [nix flake check, CI verification]
tech_stack:
  added: []
  patterns: [builtins.tryEval with deepSeq for error-path testing, builtins.toFile for inline TOML fixtures]
key_files:
  created: []
  modified: [flake.nix]
decisions:
  - "unknown-tool-error check uses builtins.deepSeq devShell.nativeBuildInputs to force lazy package evaluation before tryEval — mkShell is lazy so tryEval alone does not catch nested throws"
  - "builtins.toFile used for inline TOML fixtures (extra-test.toml, override-test.toml, unknown-test.toml) — no extra files added to repo"
metrics:
  duration: 3min
  completed: "2026-03-23"
  tasks: 1
  files: 1
---

# Phase 03 Plan 03: Check Derivations for Phase 3 Features Summary

**One-liner:** Four new nix flake check derivations verify utility resolution, extraPackages, overrides, and unknown tool error handling using deepSeq-forced lazy evaluation.

## What Was Built

`flake.nix` — extended with 4 new check derivations after the existing `resolve-latest` check:

1. **resolve-utilities:** Evaluates `fromMiseToml ./mise.toml { inherit pkgs; }` which now includes jq/ripgrep/fd utility tools — confirms utility tier works end-to-end.

2. **extra-packages:** Creates an inline TOML fixture with `node = "22"`, passes `extraPackages = [ pkgs.hello ]` — verifies the optional arg is accepted and appended to packages.

3. **overrides-work:** Creates an inline TOML fixture with `node = "22"`, passes `overrides = { node = pkgs.nodejs_20; }` — verifies the override replaces the version-resolved package.

4. **unknown-tool-error:** Creates an inline TOML fixture with `nonexistent_tool_xyz = "latest"`. Uses `builtins.tryEval (builtins.deepSeq devShell.nativeBuildInputs devShell)` to force the lazy mkShell evaluation and catch the descriptive throw error. Fails the check if the throw does NOT occur.

`nix flake check` now runs 8 checks total (4 existing + 4 new), all green.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add check derivations for utility resolution, extraPackages, overrides, and unknown tool error | cfd77e8 | flake.nix |

## Verification Results

- `nix flake check` exits 0 with all 8 checks passing
- `nix build .#checks.x86_64-linux.resolve-utilities --no-link` passes
- `nix build .#checks.x86_64-linux.extra-packages --no-link` passes
- `nix build .#checks.x86_64-linux.overrides-work --no-link` passes
- `nix build .#checks.x86_64-linux.unknown-tool-error --no-link` passes
- All 4 existing checks (parse-toml, devshell-builds, runtime-resolution, resolve-latest) still pass

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed unknown-tool-error check: tryEval alone does not catch nested throws in mkShell**

- **Found during:** Task 1 verification
- **Issue:** `builtins.tryEval (self.lib.fromMiseToml toml { inherit pkgs; })` returned `success = true` because `fromMiseToml` returns a lazy `pkgs.mkShell` derivation — the throw inside `builtins.mapAttrs resolve tools` is a lazy thunk that is not forced by `tryEval` alone.
- **Fix:** Changed to `builtins.tryEval (builtins.deepSeq devShell.nativeBuildInputs devShell)` — `deepSeq` forces the `nativeBuildInputs` list (which includes all resolved packages) before the tryEval captures any throw.
- **Files modified:** flake.nix
- **Commit:** cfd77e8

## Known Stubs

None.

## Self-Check: PASSED
