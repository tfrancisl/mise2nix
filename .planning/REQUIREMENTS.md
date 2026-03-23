# Requirements: mise2nix

**Defined:** 2026-03-22
**Core Value:** `mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; }` produces a working devShell — zero manual Nix required for common toolsets.

## v1 Requirements

### Core (parsing + resolution)

- [x] **CORE-01**: Library reads `mise.toml` using `builtins.fromTOML (builtins.readFile path)` *(Phase 1 Plan 01)*
- [x] **CORE-02**: Major runtimes resolved to version-specific nixpkgs attrs (e.g. `node = "22"` → `pkgs.nodejs_22`, `python = "3.11"` → `pkgs.python311`) *(Phase 2 Plan 01)*
- [x] **CORE-03**: Utilities and `"latest"` version strings resolved to `pkgs.X` (latest at nixpkgs pin) *(Phase 2 Plan 01)*
- [x] **CORE-04**: Unknown tools accepted via `extraPackages` (list of packages) or `overrides` (attrset replacing a mapped tool) argument

### Shell (devShell output)

- [x] **SHELL-01**: Produces `devShells.${system}.default` accessible via a simple `forAllSystems` exposed directly in the flake (no flake-utils) *(Phase 1 Plan 01)*
- [x] **SHELL-02**: `[env]` section from `mise.toml` mapped to `mkShell` env vars
- [x] **SHELL-03**: Uses `pkgs.mkShell` exclusively — no devenv, no home-manager *(Phase 1 Plan 01)*

### DX (developer experience)

- [x] **DX-01**: Unknown tool with no override throws a helpful Nix eval error that names the unknown tool(s) and explains how to use `overrides` or `extraPackages`
- [x] **DX-02**: README documents: what it is, installation, usage, supported tool table, overrides API
- [x] **DX-03**: Example flake (`example/`) showing a realistic mise.toml → devShell workflow
- [x] **DX-04**: Flake outputs interface is stable and versioned (README documents the API contract)

## v2 Requirements (v0.2.0)

### Backend Resolution

- [x] **BACKEND-01**: `fromMiseToml` detects `backend:tool` syntax in `[tools]` entries and routes to the appropriate backend resolver
- [x] **BACKEND-02**: `pipx:tool` entries resolve to `pkgs.python3Packages.*` via a mapping table covering ≤12 common tools (e.g. black, mypy, mdformat, ruff, isort, pylint, flake8, pyupgrade, bandit, pip-tools, poetry, twine)
- [x] **BACKEND-03**: `npm:tool` entries resolve to `pkgs.nodePackages.*` via a mapping table covering ≤12 common tools (e.g. prettier, typescript, eslint, webpack, vite, ts-node, esbuild, rollup, svelte, vue, turbo, nx)
- [x] **BACKEND-04**: `cargo:tool` entries resolve to `pkgs.*` via a mapping table covering ≤12 common tools (e.g. ripgrep, bat, fd, eza, delta, zoxide, tokei, hyperfine, just, cargo-watch, cargo-nextest, watchexec)
- [x] **BACKEND-05**: Unknown backend in `[tools]` (e.g. `ubi:`, `gh:`, unmapped `pipx:`/`npm:`/`cargo:` tool) throws a descriptive error naming the tool and explaining the `overrides`/`extraPackages` escape hatches

### Wrapper

- [x] **WRAP-01**: The devShell includes a `mise` wrapper script (`writeShellScriptBin`) that intercepts `mise use` and passes all other subcommands to the real mise binary unchanged
- [x] **WRAP-02**: `mise use "known-backend:tool"` writes the entry to `mise.toml` and prints a clear message instructing the user to reload the devShell to apply the change
- [x] **WRAP-03**: `mise use "unknown-backend:tool"` or `mise use "backend:unmapped-tool"` prompts interactively for a nixpkgs attribute and patches the `overrides = { ... }` argument in the nearest `flake.nix`

### DX (v0.2.0)

- [x] **DX-05**: Wrapper output explains clearly that tool resolution is Nix-managed and what action to take next (e.g. "run `direnv reload` or `nix develop` to enter the updated shell")
- [x] **DX-06**: All non-`use` mise subcommands (`run`, `list`, `tasks`, `exec`, etc.) pass through to the real mise binary with no modification or overhead

---

## Future Requirements (v0.3.0+)

### Task runner

- **TASK-01**: `[tasks]` section converted to shell scripts available in the devShell
- **TASK-02**: Tasks with dependencies resolved in correct order

### Extended backend coverage

- **EXT-01**: Automated nixpkgs attribute lookup (avoid manual table maintenance)
- **EXT-02**: GitHub release tools fetched via fetchurl with checksums from mise.lock
- **EXT-03**: `direnv reload` triggered automatically after `mise use`

### Local overrides

- **LOCAL-01**: `mise.local.toml` merged with `mise.toml` (local takes precedence)

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| flake-utils dependency | Adds a transitive dep for trivial `forAllSystems` — inline it instead |
| devenv / home-manager output | Not the intended workflow; user explicitly excluded |
| Exact patch-version fetching | Too complex; nixpkgs pin provides reproducibility |
| mise.lock as primary version source | Tracks mise's own downloads (not nixpkgs); not useful for pure-Nix resolution |
| CLI code generator | Library model is more composable and Nix-idiomatic |
| ubi:/gh: automated resolution | Too complex for v0.2.0; handled via interactive override prompt |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | Phase 1 | Complete (01-01, 01-02) |
| SHELL-01 | Phase 1 | Complete (01-01, 01-02) |
| SHELL-03 | Phase 1 | Complete (01-01, 01-02) |
| CORE-02 | Phase 2 | Complete (02-01) |
| CORE-03 | Phase 2 | Complete (02-01) |
| CORE-04 | Phase 3 | Complete |
| DX-01 | Phase 3 | Complete |
| SHELL-02 | Phase 4 | Complete |
| DX-02 | Phase 5 | Complete |
| DX-03 | Phase 5 | Complete |
| DX-04 | Phase 5 | Complete |
| BACKEND-01 | Phase 6 | Complete |
| BACKEND-02 | Phase 6 | Complete |
| BACKEND-03 | Phase 6 | Complete |
| BACKEND-04 | Phase 6 | Complete |
| BACKEND-05 | Phase 6 | Complete |
| WRAP-01 | Phase 7 | Complete |
| WRAP-02 | Phase 7 | Complete |
| DX-05 | Phase 7 | Complete |
| DX-06 | Phase 7 | Complete |
| WRAP-03 | Phase 8 | Complete |

---
*Requirements defined: 2026-03-22*
*Last updated: 2026-03-23 — v0.2.0 traceability mapped to phases 6-8*
