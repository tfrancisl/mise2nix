# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] - 2026-03-30

### Breaking
- `fromMiseToml` renamed to `mkShellFromMise`; update all call sites

### Added
- `mkShellInputsFromMise` escape hatch: returns `{envVars, packages, shellHook}` for callers
  who need to compose their own `mkShell` without losing mise2nix-managed env vars
- `mkShellFromMise` now accepts `prefixShellHook`, `postfixShellHook`, `extraPackages`,
  `extraEnvVars` for augmenting the shell without losing managed content
- Backend tool resolution via `npm:`, `pipx:`, `cargo:` prefix syntax (40+ tools mapped)
- `mise` wrapper script automatically included in every devShell:
  - `mise use <tool>` writes back to `mise.toml` and prints guidance
  - `mise install` suppresses expected read-only Nix store errors
  - Unknown tools trigger an interactive prompt to specify a nixpkgs attribute,
    which is written to `flake.nix` as an override
  - All other subcommands pass through to the real `mise` binary

## [0.1.0] - 2026-03-23

### Added
- `fromMiseToml` function: reads `mise.toml` and returns a `mkShell` derivation
- Runtime resolution for `node`/`nodejs`, `python`, `go`/`golang`, `ruby`, `java`,
  `erlang`, `elixir`, `php`, `rust`, `deno`, `bun`, `terraform`, `kubectl` with
  version-specific nixpkgs attribute mapping
- Utility resolution for `ripgrep`/`rg`, `fd`, `bat`, `jq`, `fzf`, `git`, `curl`,
  `wget`, `make`, `cmake`, `gh`, `delta`, `eza`, `zoxide`, `starship`, `just`,
  `hyperfine`, `tokei`
- Environment variable passthrough from the `[env]` section of `mise.toml`
- `MISE_INSTALLS_DIR` shellHook export so tools appear in `mise ls` as active
- `MISE_NOT_FOUND_AUTO_INSTALL=false` set automatically
- `extraPackages` option to add arbitrary nixpkgs packages alongside resolved tools
- `overrides` option to replace specific tool resolutions with custom nixpkgs attributes
- Descriptive eval-time errors for unknown tools
- Multi-platform: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`
