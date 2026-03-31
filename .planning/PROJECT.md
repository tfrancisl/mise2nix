# mise2nix

A Nix flake library that reads `mise.toml` and produces a `devShells` output — no manual Nix required. Inspired by uv2nix: consume a config file, get Nix.

**Core value:** `mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; }` produces a working devShell.

## Current Milestone: v0.2.0 — complete (2026-03-24)

Phase 09 (mise-integration-layer) is in progress: Plan 09-01 done (`lib/mise-installs.nix` + `MISE_INSTALLS_DIR`); Plan 09-02 partial (shellHook done; README section + nix check pending).

## Constraints

- Pure Nix only — no external CLI, Rust binary, or Python script
- `builtins.fromTOML` for parsing (Nix ≥ 2.6, no parser deps)
- nixpkgs only in v1 — no fetchurl, no GitHub release fetching
- No flake-utils — inline a simple `forAllSystems` directly
- `pkgs.mkShell` output only — no devenv, no home-manager
- Two-tier resolution: runtimes (version-specific attrs) → utilities (pkgs.X at nixpkgs pin)
