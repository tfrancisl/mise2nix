---
phase: 03-utility-tool-resolution-overrides-api
plan: 01
subsystem: lib
tags: [nix, utilities, tool-resolution, nixpkgs]
dependency_graph:
  requires: []
  provides: [lib/utilities.nix]
  affects: [lib/default.nix]
tech_stack:
  added: []
  patterns: [single-version resolver, _version unused argument, pkgs.X direct attr]
key_files:
  created: [lib/utilities.nix]
  modified: []
decisions:
  - "All utility resolvers take _version (ignored) — nixpkgs pin provides a single version per tool"
  - "make maps to pkgs.gnumake (pkgs.make does not exist in nixpkgs)"
  - "rg provided as alias for ripgrep so both mise tool names work"
metrics:
  duration: 1min
  completed: "2026-03-23"
  tasks: 1
  files: 1
---

# Phase 03 Plan 01: Utility Tool Mapping Summary

**One-liner:** lib/utilities.nix with 19 resolver entries mapping CLI utility tool names (ripgrep, fd, bat, jq, fzf, etc.) to their nixpkgs attrs via ignored _version pattern.

## What Was Built

`lib/utilities.nix` — a Nix module following the `{ lib, pkgs }:` signature from `lib/runtimes.nix`, returning a flat attrset of 19 tool-name -> (version -> derivation) resolver functions.

Every resolver ignores the version argument (using `_version`) and returns the pkgs attr directly. This is the utilities tier of mise2nix's two-tier resolution strategy: runtimes get version-matched attrs, utilities get the nixpkgs-pinned version.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create lib/utilities.nix with complete tool mapping | 0b87cfb | lib/utilities.nix |

## Verification Results

- `builtins.attrNames utils` returns 19 keys (all tools + rg alias)
- `utils.ripgrep "latest"` == `pkgs.ripgrep` (same derivation name)
- `utils.rg "latest"` == `utils.ripgrep "latest"` (alias works)
- `utils.make "latest"` == `pkgs.gnumake` (correct nixpkgs attr used)
- Module evaluates without error via `nix eval --impure`

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- lib/utilities.nix exists at the correct path
- Commit 0b87cfb verified in git log
- nix eval returns 19 keys with all acceptance criteria passing
