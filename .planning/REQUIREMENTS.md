# Requirements: mise2nix

**Defined:** 2026-03-22
**Core Value:** `mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; }` produces a working devShell — zero manual Nix required for common toolsets.

## v1 Requirements

### Core (parsing + resolution)

- [x] **CORE-01**: Library reads `mise.toml` using `builtins.fromTOML (builtins.readFile path)` *(Phase 1 Plan 01)*
- [ ] **CORE-02**: Major runtimes resolved to version-specific nixpkgs attrs (e.g. `node = "22"` → `pkgs.nodejs_22`, `python = "3.11"` → `pkgs.python311`)
- [ ] **CORE-03**: Utilities and `"latest"` version strings resolved to `pkgs.X` (latest at nixpkgs pin)
- [ ] **CORE-04**: Unknown tools accepted via `extraPackages` (list of packages) or `overrides` (attrset replacing a mapped tool) argument

### Shell (devShell output)

- [x] **SHELL-01**: Produces `devShells.${system}.default` accessible via a simple `forAllSystems` exposed directly in the flake (no flake-utils) *(Phase 1 Plan 01)*
- [ ] **SHELL-02**: `[env]` section from `mise.toml` mapped to `mkShell` env vars
- [x] **SHELL-03**: Uses `pkgs.mkShell` exclusively — no devenv, no home-manager *(Phase 1 Plan 01)*

### DX (developer experience)

- [ ] **DX-01**: Unknown tool with no override throws a helpful Nix eval error that names the unknown tool(s) and explains how to use `overrides` or `extraPackages`
- [ ] **DX-02**: README documents: what it is, installation, usage, supported tool table, overrides API
- [ ] **DX-03**: Example flake (`example/`) showing a realistic mise.toml → devShell workflow
- [ ] **DX-04**: Flake outputs interface is stable and versioned (README documents the API contract)

## v2 Requirements

### Task runner

- **TASK-01**: `[tasks]` section converted to shell scripts available in the devShell
- **TASK-02**: Tasks with dependencies resolved in correct order

### Extended tool coverage

- **EXT-01**: npm-backend tools (e.g. `npm:@anthropic-ai/claude-code`) fetched via fetchNpmDeps
- **EXT-02**: GitHub release tools fetched via fetchurl with checksums from mise.lock
- **EXT-03**: pipx/uvx tools resolved via Python packaging infrastructure

### Local overrides

- **LOCAL-01**: `mise.local.toml` merged with `mise.toml` (local takes precedence)

## Out of Scope

| Feature | Reason |
|---------|--------|
| flake-utils dependency | Adds a transitive dep for trivial `forAllSystems` — inline it instead |
| devenv / home-manager output | Not the intended workflow; user explicitly excluded |
| Exact patch-version fetching | Too complex for v1; nixpkgs pin provides reproducibility |
| mise.lock as primary version source | Tracks mise's own downloads (not nixpkgs); not useful for pure-Nix resolution |
| CLI code generator | Library model is more composable and Nix-idiomatic |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | Phase 1 | Complete (01-01, 01-02) |
| SHELL-01 | Phase 1 | Complete (01-01, 01-02) |
| SHELL-03 | Phase 1 | Complete (01-01, 01-02) |
| CORE-02 | Phase 2 | Pending |
| CORE-03 | Phase 2 | Pending |
| CORE-04 | Phase 3 | Pending |
| DX-01 | Phase 3 | Pending |
| SHELL-02 | Phase 4 | Pending |
| DX-02 | Phase 5 | Pending |
| DX-03 | Phase 5 | Pending |
| DX-04 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-22*
*Last updated: 2026-03-22 after initial definition*
