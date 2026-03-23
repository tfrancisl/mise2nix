---
phase: "05"
plan: "03"
subsystem: example-and-publish
tags: [example, flake, publish, git-tag, v0.1.0]
dependency_graph:
  requires: [05-02]
  provides: [example/flake.nix, example/mise.toml, example/flake.lock, v0.1.0-tag]
  affects: []
tech_stack:
  added: []
  patterns: [standalone flake with path input, forAllSystems via lib.genAttrs, flake.lock committed]
key_files:
  created: [example/flake.nix, example/mise.toml, example/flake.lock]
  modified: []
decisions:
  - example/flake.nix is a standalone flake with its own inputs and flake.lock (not part of parent flake)
  - mise2nix input uses path:.. to reference parent repo for local dev
  - mise2nix.inputs.nixpkgs.follows = "nixpkgs" deduplicates nixpkgs between mise2nix and example
  - example/mise.toml uses node 22 + python 3.11 + ripgrep + fd + NODE_ENV=development (polyglot demo)
  - git tag v0.1.0 created at HEAD (8fb9060) — not pushed; user pushes manually
  - flake.lock committed alongside flake.nix so example is immediately reproducible without nix flake lock
metrics:
  duration: "1min"
  completed: "2026-03-23"
  tasks: 2
  files: 3
---

# Phase 05 Plan 03: Example Directory + Publish v0.1.0 Summary

**One-liner:** Created standalone example/flake.nix with polyglot mise.toml (node+python+ripgrep+fd+env), committed flake.lock, and tagged v0.1.0.

## What Was Built

### Task 1: example/ directory

Created three files in `example/`:

- **`example/mise.toml`** — polyglot project config: node 22, python 3.11, ripgrep (latest), fd (latest), plus `NODE_ENV = "development"`. Demonstrates runtimes, utilities, and env vars all working together.

- **`example/flake.nix`** — standalone flake with:
  - Its own `nixpkgs` input (github:NixOS/nixpkgs/nixpkgs-unstable)
  - `mise2nix` input using `path:..` (references parent repo for local development)
  - `mise2nix.inputs.nixpkgs.follows = "nixpkgs"` to deduplicate nixpkgs
  - `forAllSystems` using `lib.genAttrs` with all 4 systems
  - `devShells.default = mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; }`

- **`example/flake.lock`** — generated via `nix flake lock` inside the example/ directory. Records nixpkgs at `9cf7092bdd603554bd8b63c216e8943cf9b12512` (2026-03-18 nixpkgs-unstable). Committed so the example is immediately reproducible.

### Task 2: git tag v0.1.0

- Tag `v0.1.0` created at commit `8fb9060` (the example commit)
- Tag is local only — user pushes manually with `git push origin v0.1.0`

## Verification Results

- `ls example/` shows flake.nix, mise.toml, flake.lock — all three present
- `git tag -l v0.1.0` returns `v0.1.0`
- `git rev-parse v0.1.0` resolves to `8fb9060` (example commit)
- flake.lock correctly records mise2nix as `path:..` with nixpkgs follows

## Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Add example/ directory with polyglot mise.toml and standalone flake | 8fb9060 | example/flake.nix, example/mise.toml, example/flake.lock |
| — | git tag v0.1.0 | v0.1.0 → 8fb9060 | (tag, no commit) |

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

- `path:..` in example/flake.nix is intentional for local development. When the repo is published to GitHub, users should update to `github:OWNER/REPO` (as noted in README.md). This is not a stub — it's the correct local dev pattern.

## Self-Check: PASSED

- example/flake.nix exists: FOUND
- example/mise.toml exists: FOUND
- example/flake.lock exists: FOUND
- Commit 8fb9060 exists: confirmed (git log shows feat(05-03) commit)
- Tag v0.1.0 exists: confirmed (git tag -l v0.1.0 returns v0.1.0)
