---
phase: 02-runtime-tool-resolution
plan: 01
subsystem: lib
tags: [nix, runtimes, version-resolution, nixpkgs]
dependency_graph:
  requires: [01-flake-scaffold-parser/01-01-PLAN.md, 01-flake-scaffold-parser/01-02-PLAN.md]
  provides: [runtime-resolver-functions, wired-fromMiseToml]
  affects: [lib/runtimes.nix, lib/default.nix]
tech_stack:
  added: []
  patterns:
    - Hardcoded version-map lookup with builtins.throw on miss (D-01, D-02)
    - lib.splitString for safe version string parsing (avoids builtins.split null-interleaving)
    - builtins.toString applied at call site before parsing (handles TOML bare integers)
    - Shared let-bound resolver functions for aliases (nodejs->node, golang->go) to avoid rec
    - builtins.filter null before passing to pkgs.mkShell (prevents opaque mkShell errors)
key_files:
  created:
    - lib/runtimes.nix
  modified:
    - lib/default.nix
decisions:
  - builtins.toString applied in lib/default.nix at call site (consistent location for future Phase 3 utility tier)
  - Single-version runtimes (rust, deno, bun, terraform, kubectl) silently map all version strings rather than throwing
  - Resolver aliases (nodejs, golang) use shared let-bound functions rather than rec attrset to avoid self-reference
metrics:
  duration: 2min
  completed: 2026-03-23
  tasks_completed: 2
  files_modified: 2
---

# Phase 2 Plan 1: Runtime Tool Resolution Summary

**One-liner:** Hardcoded nixpkgs version maps for 13 runtimes (15 keys) in lib/runtimes.nix wired into fromMiseToml — node="22" resolves to pkgs.nodejs_22, python="3.11" to pkgs.python311.

## What Was Built

### lib/runtimes.nix (new)

Module signature `{ lib, pkgs }:` returning an attrset of 15 resolver functions covering all 13 mise runtimes plus two aliases:

- **node / nodejs** — major version map: 20, 22, 24, 25; latest = pkgs.nodejs
- **python** — major.minor map (concatenated): 311, 312, 313, 314, 315; latest = pkgs.python3
- **go / golang** — major.minor map (underscore): 1_24, 1_25, 1_26; latest = pkgs.go
- **ruby** — major.minor map (underscore): 3_3, 3_4, 3_5, 4_0; latest = pkgs.ruby
- **java** — major version map: 8, 11, 17, 21, 25; latest = pkgs.jdk
- **erlang** — major version map: 26, 27, 28, 29; latest = pkgs.erlang
- **elixir** — major.minor map (underscore): 1_15, 1_16, 1_17, 1_18, 1_19; latest = pkgs.elixir
- **php** — major.minor map (concatenated): 82, 83, 84, 85; latest = pkgs.php
- **rust** — all versions map to pkgs.rustup (no per-version attrs in nixpkgs)
- **deno / bun / terraform / kubectl** — single-version runtimes; all versions map silently to pkgs.X

Version maps exclude all EOL/removed attrs: no nodejs_16/18, python38-310, go_1_23, ruby_3_1/3_2, jdk23/24, php81, erlang_25.

### lib/default.nix (updated)

`fromMiseToml` now:
1. Imports `./runtimes.nix { inherit lib pkgs; }`
2. Maps over `tools` attrset — known runtimes resolved to derivations, unknown tools yield null
3. Filters nulls with `builtins.filter` before passing to `pkgs.mkShell`
4. `packages = resolvedPackages` (was `packages = []`)

## Verification Results

- `nix build .#checks.x86_64-linux.devshell-builds --no-link` — PASS (built nodejs-22.22.1 + python3-3.11.15 from mise.toml)
- `nix build .#checks.x86_64-linux.parse-toml --no-link` — PASS
- `nix eval builtins.attrNames runtimes` — returns all 15 keys: bun, deno, elixir, erlang, go, golang, java, kubectl, node, nodejs, php, python, ruby, rust, terraform

## Commits

- `9b873e0` — feat(02-01): add lib/runtimes.nix with 15 runtime resolvers
- `e63bba5` — feat(02-01): wire runtimes.nix into fromMiseToml in lib/default.nix

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None — all resolver functions return real nixpkgs derivations. The `packages = resolvedPackages` path is fully wired end-to-end; the devShell check builds actual packages from mise.toml.

## Self-Check: PASSED

- `lib/runtimes.nix` exists: FOUND
- `lib/default.nix` contains `import ./runtimes.nix`: FOUND
- Commit `9b873e0` exists: FOUND
- Commit `e63bba5` exists: FOUND
- devshell-builds check: PASS
- parse-toml check: PASS
