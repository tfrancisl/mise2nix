---
phase: 03-utility-tool-resolution-overrides-api
plan: 02
subsystem: lib
tags: [nix, utilities, overrides, extraPackages, tool-resolution, error-handling]
dependency_graph:
  requires: [03-01]
  provides: [lib/default.nix updated, overrides API, extraPackages API]
  affects: [flake.nix devShells, flake.nix checks]
tech_stack:
  added: []
  patterns: [4-step resolution cascade, backward-compatible optional args, descriptive throw errors]
key_files:
  created: []
  modified: [lib/default.nix, mise.toml]
decisions:
  - "overrides values are derivations directly (not functions) — simpler API matching CORE-04 requirement"
  - "Resolution cascade order: overrides -> runtimes -> utilities -> throw (user overrides always win)"
  - "Error message names the specific tool and explains both escape hatches (extraPackages and overrides)"
  - "No null filtering — every tool must resolve or throw, no silent drops"
metrics:
  duration: 1min
  completed: "2026-03-23"
  tasks: 2
  files: 2
---

# Phase 03 Plan 02: Integrate Utilities + Overrides API Summary

**One-liner:** fromMiseToml extended with 4-step resolution cascade (overrides->runtimes->utilities->throw), extraPackages/overrides optional args, and descriptive unknown tool errors; mise.toml fixture updated with jq/ripgrep/fd utility entries.

## What Was Built

`lib/default.nix` — rewritten with the complete resolution pipeline:

1. **Extended function signature:** `{ pkgs, extraPackages ? [], overrides ? {} }:` — fully backward compatible with existing `fromMiseToml ./mise.toml { inherit pkgs; }` call sites.
2. **utilities.nix wired in:** `import ./utilities.nix { inherit lib pkgs; }` alongside runtimes.nix.
3. **4-step resolution cascade per tool:**
   - Step 1: overrides (user-provided derivation, highest priority)
   - Step 2: runtimes (version-specific nixpkgs attrs)
   - Step 3: utilities (pkgs.X direct mapping)
   - Step 4: `builtins.throw` with descriptive error naming the tool and both escape hatches
4. **No null filtering:** Every tool must resolve or throw — no silent drops of unknown tools.
5. **extraPackages appended** after resolved tools in `pkgs.mkShell { packages = ... }`.

`mise.toml` — updated with three representative utility tool entries (`jq`, `ripgrep`, `fd`) alongside existing runtime entries (`node`, `python`).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend fromMiseToml with utilities, overrides, extraPackages, error handling | 6681c46 | lib/default.nix |
| 2 | Add utility tools to mise.toml fixture | d68bbb6 | mise.toml |

## Verification Results

- `nix flake check` passes all 4 checks (parse-toml, devshell-builds, runtime-resolution, resolve-latest)
- `nix build .#checks.x86_64-linux.devshell-builds --no-link` passes with jq/ripgrep/fd in devShell
- `nix build .#checks.x86_64-linux.runtime-resolution --no-link` passes (runtime tools unaffected)
- Unknown tool error: `foobar123` produces `mise2nix: unknown tool 'foobar123' — not found in runtimes or utilities. Use 'overrides = { foobar123 = pkgs.something; }' or 'extraPackages = [ pkgs.something ]' to provide it.`
- Existing `fromMiseToml ./mise.toml { inherit pkgs; }` call continues to work (backward compatible)

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- lib/default.nix exists and contains `extraPackages ? []`, `overrides ? {}`, `import ./utilities.nix`, `builtins.throw` with "unknown tool" and "overrides" and "extraPackages"
- mise.toml contains jq, ripgrep, and fd entries
- Commit 6681c46 verified in git log
- Commit d68bbb6 verified in git log
- All nix flake checks pass
