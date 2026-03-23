---
phase: 02-runtime-tool-resolution
plan: 02
subsystem: flake
tags: [nix, checks, runtime-resolution, integration-test]
dependency_graph:
  requires: [02-runtime-tool-resolution/02-01-PLAN.md]
  provides: [runtime-resolution-check, resolve-latest-check]
  affects: [flake.nix]
tech_stack:
  added: []
  patterns:
    - builtins.toFile for inline TOML fixture in check derivation (avoids extra fixture file)
    - String interpolation of devShell derivation forces eval-time resolution check
    - pkgs.runCommand check derivation pattern for regression gating
key_files:
  created: []
  modified:
    - flake.nix
decisions:
  - builtins.toFile used for inline "latest" TOML fixture to avoid adding a mise-latest.toml file to the repo
  - runtime-resolution check forces eval of the main mise.toml devShell (node=22, python=3.11)
  - resolve-latest check verifies node/python/go "latest" strings resolve without throw
metrics:
  duration: 3min
  completed: 2026-03-23
  tasks_completed: 2
  files_modified: 1
---

# Phase 2 Plan 2: Flake Check Derivations Summary

**One-liner:** Added runtime-resolution and resolve-latest check derivations to flake.nix — flake check now gates on all 4 checks passing, and nix develop provides node v22.22.1 and python3.11.15.

## What Was Built

### flake.nix (updated)

Two new check derivations added to the `checks` attrset (4 total: parse-toml, devshell-builds, runtime-resolution, resolve-latest):

**runtime-resolution check:**
Forces eval of `self.lib.fromMiseToml ./mise.toml { inherit pkgs; }` (node="22", python="3.11") by string-interpolating the devShell into the build script. If any resolver throws (bad version, missing attr), this check fails at build time.

**resolve-latest check:**
Uses `builtins.toFile` to create an inline TOML fixture with node/python/go all set to "latest". Forces eval of the resulting devShell to confirm "latest" paths through all three resolvers don't throw. `go = pkgs.go` is fetched from cache.nixos.org at the nixpkgs pin version.

## Verification Results

- `nix build .#checks.x86_64-linux.runtime-resolution --no-link` — PASS
- `nix build .#checks.x86_64-linux.resolve-latest --no-link` — PASS (fetched go-1.25.7 from cache.nixos.org)
- `nix build .#checks.x86_64-linux.parse-toml --no-link` — PASS (regression)
- `nix build .#checks.x86_64-linux.devshell-builds --no-link` — PASS (regression)
- `nix flake check` — exits 0, 4 checks running for x86_64-linux
- `nix flake show` — checks for 4 systems with 4 derivations each, devShells for 4 systems, lib: unknown
- `nix develop --command bash -c "which node"` — `/nix/store/gi0p7azcixb20pddx39k5mwnkj6xl4bz-nodejs-22.22.1/bin/node`
- `nix develop --command bash -c "node --version"` — `v22.22.1`
- `nix develop --command bash -c "which python3"` — `/nix/store/m0px3sm97qw6s187sq2vjyjl6jvhhgmk-python3-3.11.15/bin/python3`
- `nix develop --command bash -c "python3 --version"` — `Python 3.11.15`

## Commits

- `c0bf448` — feat(02-02): add runtime-resolution and resolve-latest check derivations

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None — all checks force real derivation evaluation. No placeholder text or unresolved data paths.

## Self-Check: PASSED

- `flake.nix` contains `runtime-resolution = `: FOUND
- `flake.nix` contains `resolve-latest = `: FOUND
- `flake.nix` contains `builtins.toFile "mise-latest.toml"`: FOUND
- `flake.nix` still contains `parse-toml` and `devshell-builds`: FOUND
- Commit `c0bf448` exists: FOUND
- nix flake check: exits 0
- nix develop node: v22.22.1
- nix develop python3: Python 3.11.15
