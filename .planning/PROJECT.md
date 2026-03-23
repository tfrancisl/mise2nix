# mise2nix

## What This Is

A Nix flake library that reads `mise.toml` and produces a `devShells` output — no manual Nix
required. For developers who manage polyglot dev environments with mise and want reproducible,
cacheable Nix shells without translating their config by hand.

Inspired by [uv2nix](https://github.com/pyproject-nix/uv2nix): consume a configuration file,
get Nix.

## Core Value

`mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; }` produces a working devShell —
zero manual Nix required for common toolsets.

## Requirements

### Validated

- [x] Library reads `mise.toml` with `builtins.fromTOML` — *Validated in Phase 01: flake-scaffold-parser*
- [x] Produces `devShells.${system}.default` via `forAllSystems` — *Validated in Phase 01: flake-scaffold-parser*
- [x] Major runtimes (node, python, go, ruby, etc.) resolved to version-specific nixpkgs attrs — *Validated in Phase 02: runtime-tool-resolution*
- [x] Utilities and `"latest"` tools resolved to `pkgs.X` (latest-at-nixpkgs-pin, fully cached) — *Validated in Phase 03: utility-tool-resolution-overrides-api*
- [x] Unknown tools accepted via `extraPackages` or `overrides` argument — *Validated in Phase 03: utility-tool-resolution-overrides-api*
- [x] Unknown tool without override throws a helpful Nix eval error — *Validated in Phase 03: utility-tool-resolution-overrides-api*

### Active

- [ ] `[env]` section mapped to `mkShell` env vars
- [ ] README with usage examples and supported tool table
- [ ] Example flake demonstrating common mise.toml → devShell patterns
- [ ] Flake published with a stable outputs interface

### Out of Scope

- `[tasks]` section — v2; task runner integration is a separate concern
- devenv / home-manager output — not the intended use case
- Exact patch-version fetching via `fetchurl` — too complex for v1; nixpkgs pin handles reproducibility
- mise.lock as version source — mise.lock tracks mise's own downloads, not nixpkgs versions
- flake-utils — keep dependencies minimal; expose a simple `forAllSystems` attr directly

## Context

mise ([mise.jdx.dev](https://mise.jdx.dev/)) is a polyglot version manager and dev environment
tool. It consolidates what nvm, pyenv, rbenv, direnv, and make all do. Its primary config file
is `mise.toml` with a `[tools]` section (tool versions) and `[env]` section (environment vars).

mise supports multiple backends: asdf plugins, npm packages, pipx, GitHub releases, etc. v1 of
mise2nix targets the most common tools available in nixpkgs. GitHub release and npm-backend
tools are handled via the `overrides`/`extraPackages` escape hatch.

The two-tier resolution strategy:
- **Major runtimes** (node, python, go, etc.): `node = "22"` → `pkgs.nodejs_22`
- **Utilities** (`ripgrep = "latest"`): → `pkgs.ripgrep` (version = nixpkgs pin = cached)

This matches how Nix users actually think about version management and leverages cache.nixos.org
for all resolved packages.

## Constraints

- **Tech stack**: Pure Nix only — no external CLI, no Rust binary, no Python script
- **Parsing**: `builtins.fromTOML` (available since Nix 2.6) — no parser dependencies
- **Package source**: nixpkgs only in v1 — no fetchurl, no GitHub release fetching
- **Dependencies**: No flake-utils — expose a simple `forAllSystems` directly in the flake
- **Output format**: `pkgs.mkShell` — no devenv, no home-manager

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Pure Nix implementation | No install step; works anywhere Nix is available | — Pending |
| Two-tier resolution (runtimes vs utilities) | Runtimes need version pinning; utilities benefit from nixpkgs cache | — Pending |
| "latest" utilities → pkgs.X | Nixpkgs pin IS the version lock; cache.nixos.org has pre-built binaries | — Pending |
| overrides/extraPackages for unknowns | Fail loudly but provide escape hatch; better than silently ignoring | — Pending |
| No flake-utils | Minimize deps; a simple forAllSystems is trivial to inline | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-23 — Phase 03: utility-tool-resolution-overrides-api complete*
