# Roadmap: mise2nix

## Milestones

- 🚧 **v0.1.0 Foundation** - Phases 1-5 (in progress)
- 📋 **v0.2.0 Backend Tool Resolution** - Phases 6-8 (planned)

## Phases

<details>
<summary>🚧 v0.1.0 Foundation (Phases 1-5) - In Progress</summary>

**Milestone Goal:** A pure Nix flake library that reads `mise.toml` and produces a working `devShells` output — covering major runtimes, utilities, env vars, overrides, tests, and docs.

### Phase 1: Flake Scaffold + Parser
**Goal**: A working flake skeleton that reads `mise.toml` and returns an empty devShell — `nix flake show` and `nix develop` both work.
**Depends on**: Nothing (first phase)
**Requirements**: CORE-01, SHELL-01, SHELL-03
**Success Criteria** (what must be TRUE):
  1. `flake.nix` exists with `nixpkgs` as sole input and a `lib.forAllSystems` helper
  2. `mise2nix.lib.fromMiseToml` is exported and accepts a path + `{ pkgs }` args
  3. `fromMiseToml` parses `mise.toml` using `builtins.fromTOML` without error
  4. `nix flake show` succeeds and shows `devShells` output
  5. `nix develop` opens a shell (even if empty)
**Plans**: 2 plans (2/2 complete)

Plans:
- [x] 01-01-PLAN.md — Create flake.nix, lib/default.nix, and mise.toml skeleton
- [x] 01-02-PLAN.md — Add checks output and verify full Phase 1 integration

### Phase 2: Runtime Tool Resolution
**Goal**: Major language runtimes in `[tools]` resolve to the correct version-specific nixpkgs attribute (e.g. `node = "22"` → `pkgs.nodejs_22`).
**Depends on**: Phase 1
**Requirements**: CORE-02, CORE-03
**Success Criteria** (what must be TRUE):
  1. `lib/runtimes.nix` exports a mapping of mise tool names to version-resolving functions
  2. Covered runtimes: node/nodejs, python, go/golang, ruby, rust, java, erlang, elixir, deno, bun, php, terraform, kubectl
  3. Version string parsing correctly extracts major (and minor where needed): "22" → 22, "3.11.9" → 311
  4. `"latest"` version string falls through to utility resolution without error
  5. Resolved runtime packages appear in devShell `buildInputs`
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — Create lib/runtimes.nix with all 13 runtime resolvers and wire into fromMiseToml
- [ ] 02-02-PLAN.md — Add check derivations and verify full Phase 2 integration

### Phase 3: Utility Tool Resolution + Overrides API
**Goal**: All `[tools]` entries resolve — either via utility mapping, user overrides, or a descriptive error message.
**Depends on**: Phase 2
**Requirements**: CORE-03, CORE-04, DX-01
**Success Criteria** (what must be TRUE):
  1. `lib/utilities.nix` exports a mapping covering: ripgrep/rg, fd, bat, jq, fzf, git, curl, wget, make, cmake, gh, delta, eza, zoxide, starship, just, hyperfine, tokei
  2. `extraPackages` argument appends additional packages to buildInputs
  3. `overrides` argument (attrset keyed by mise tool name) replaces a resolved package
  4. Completely unknown tool with no override throws `builtins.throw` with message naming the tool and explaining extraPackages/overrides
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md — Create lib/utilities.nix with common tool mapping
- [x] 03-02-PLAN.md — Wire utilities into fromMiseToml, add extraPackages/overrides args, unknown tool error
- [ ] 03-03-PLAN.md — Add check derivations for utility resolution, overrides, and error handling

### Phase 4: Env Vars + Full devShell Assembly
**Goal**: `[env]` section from `mise.toml` flows into the devShell as environment variables; full end-to-end integration works.
**Depends on**: Phase 3
**Requirements**: SHELL-01, SHELL-02
**Success Criteria** (what must be TRUE):
  1. `lib/env.nix` reads the `[env]` attrset from parsed TOML and returns a list of env var name/value pairs
  2. `mkShell` receives env vars from `[env]` section (visible in `nix develop` shell)
  3. A `mise.toml` with both `[tools]` and `[env]` produces a devShell with correct packages and environment variables
  4. `forAllSystems` wiring verified: flake exposes `devShells.x86_64-linux.default` and `devShells.aarch64-darwin.default`
**Plans**: 2 plans

Plans:
- [x] 04-01-PLAN.md — Create lib/env.nix and integrate env vars into fromMiseToml mkShell call
- [ ] 04-02-PLAN.md — Add check derivations for env var passthrough and full end-to-end integration

### Phase 5: Tests, Documentation, and Publish
**Goal**: mise2nix is ready for public use — tested, documented, and git-tagged.
**Depends on**: Phase 4
**Requirements**: DX-02, DX-03, DX-04
**Success Criteria** (what must be TRUE):
  1. `nix flake check` passes with checks covering: runtime version mapping, utility mapping, env var passthrough, overrides API, unknown tool error
  2. `README.md` contains: project description, quickstart, supported tools table, API docs for `fromMiseToml`, overrides pattern, limitations
  3. `example/` directory contains a realistic `mise.toml` and `flake.nix` showing mise2nix usage
  4. Git tag `v0.1.0` exists; flake URL is documented in README
**Plans**: 3 plans

Plans:
- [ ] 05-01: Write nix flake checks for all major code paths
- [ ] 05-02: Write README.md with full documentation
- [ ] 05-03: Create example/ directory with realistic usage example and publish v0.1.0

</details>

### v0.2.0 Backend Tool Resolution (Planned)

**Milestone Goal:** Make `mise use "backend:tool"` work naturally inside a mise2nix devShell — resolving known backends via nixpkgs tables and prompting interactively for unknowns.

### Phase 6: Backend Syntax Detection + Mapping Tables
**Goal**: `fromMiseToml` understands `backend:tool` syntax and resolves known backends (pipx, npm, cargo) via nixpkgs mapping tables — unknown backends and unmapped tools produce a clear error.
**Depends on**: Phase 5
**Requirements**: BACKEND-01, BACKEND-02, BACKEND-03, BACKEND-04, BACKEND-05
**Success Criteria** (what must be TRUE):
  1. `fromMiseToml` detects `backend:tool` entries in `[tools]` and routes them through backend resolvers rather than the runtime/utility cascade
  2. `pipx:black`, `pipx:mypy`, `pipx:ruff` (and ≤9 other common tools) resolve to the correct `pkgs.python3Packages.*` attribute
  3. `npm:prettier`, `npm:typescript`, `npm:eslint` (and ≤9 other common tools) resolve to the correct `pkgs.nodePackages.*` attribute
  4. `cargo:ripgrep`, `cargo:bat`, `cargo:fd` (and ≤9 other common tools) resolve to the correct `pkgs.*` attribute
  5. An unknown backend or an unmapped tool within a known backend throws a `builtins.throw` error naming the tool and explaining the `overrides`/`extraPackages` escape hatches
**Plans**: TBD

### Phase 7: Mise Wrapper Core
**Goal**: The devShell ships a `mise` wrapper script that handles `mise use "known-backend:tool"` gracefully and passes all other subcommands through to the real mise binary unchanged.
**Depends on**: Phase 6
**Requirements**: WRAP-01, WRAP-02, DX-05, DX-06
**Success Criteria** (what must be TRUE):
  1. The devShell contains a `mise` wrapper (`writeShellScriptBin`) that shadows the real `pkgs.mise` binary
  2. `mise run`, `mise list`, `mise exec`, and all non-`use` subcommands invoke the real `mise` binary with arguments passed through verbatim and no observable overhead
  3. `mise use "pipx:black"` (or any known-backend tool) writes `pipx:black = "latest"` to `mise.toml` and prints a message explaining that tool resolution is Nix-managed and instructing the user to reload (e.g. `direnv reload` or `nix develop`)
  4. Wrapper output clearly attributes the message to mise2nix so the user understands Nix is managing the resolution
**Plans**: TBD
**UI hint**: yes

### Phase 8: Interactive Override Patching
**Goal**: `mise use "unknown-backend:tool"` (or any unmapped tool) prompts the user interactively for a nixpkgs attribute and patches the `overrides = { ... }` argument in the nearest `flake.nix`.
**Depends on**: Phase 7
**Requirements**: WRAP-03
**Success Criteria** (what must be TRUE):
  1. Running `mise use "ubi:some-tool"` triggers an interactive prompt asking for the nixpkgs attribute path (e.g. `pkgs.some-tool`)
  2. After the user supplies an attribute, the tool entry is written to `mise.toml` and the `overrides` attrset in the nearest `flake.nix` is patched with the new mapping
  3. The patched `flake.nix` remains syntactically valid Nix after the write
  4. If the user aborts the prompt (Ctrl-C or empty input), no files are modified and a clear cancellation message is shown
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Flake Scaffold + Parser | v0.1.0 | 2/2 | Complete | 2026-03-23 |
| 2. Runtime Tool Resolution | v0.1.0 | 1/2 | In Progress | - |
| 3. Utility Tool Resolution + Overrides API | v0.1.0 | 2/3 | In Progress | - |
| 4. Env Vars + Full devShell Assembly | v0.1.0 | 1/2 | In Progress | - |
| 5. Tests, Documentation, and Publish | v0.1.0 | 0/3 | Not started | - |
| 6. Backend Syntax Detection + Mapping Tables | v0.2.0 | 0/TBD | Not started | - |
| 7. Mise Wrapper Core | v0.2.0 | 0/TBD | Not started | - |
| 8. Interactive Override Patching | v0.2.0 | 0/TBD | Not started | - |
