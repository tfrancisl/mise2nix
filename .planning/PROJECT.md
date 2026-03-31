# mise2nix

A Nix flake library that reads `mise.toml` and produces a `devShells` output — no manual Nix required. Inspired by uv2nix: consume a config file, get Nix.

**Core value:** `mise2nix.lib.mkShellFromMise { tomlPath = ./mise.toml; inherit pkgs; }` produces a working devShell. `mkShellInputsFromMise` (returns `{envVars, packages, shellHook}`) is also public for users who need to compose their own shell.

## Current Milestone: v0.2.0 — complete (2026-03-24)

Phase 09 (mise-integration-layer) is complete: `lib/mise-installs.nix`, `MISE_INSTALLS_DIR`, `MISE_OFFLINE = "1"`, and `shellHook` with `mise activate bash` are all wired in. The `mise-installs-dir` nix check from plan 09-02 was not written (see IDEAS.md).

## Constraints

- Pure Nix only — no external CLI, Rust binary, or Python script
- `builtins.fromTOML` for parsing (Nix ≥ 2.6, no parser deps)
- nixpkgs only in v1 — no fetchurl, no GitHub release fetching
- No flake-utils — inline a simple `forAllSystems` directly
- `pkgs.mkShell` output only — no devenv, no home-manager
- Two-tier resolution: runtimes (version-specific attrs) → utilities (pkgs.X at nixpkgs pin)
