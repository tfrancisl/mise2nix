# Roadmap: mise2nix

## Overview

Build mise2nix — a pure Nix flake library that reads `mise.toml` and produces a `devShells` output. Five phases take the project from a flake skeleton to a published, documented library covering tool resolution, env vars, overrides, and tests.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work

- [x] **Phase 1: Flake Scaffold + Parser** - Initialize flake.nix and fromMiseToml skeleton that returns an empty devShell
- [ ] **Phase 2: Runtime Tool Resolution** - Map major runtimes to version-specific nixpkgs attributes
- [ ] **Phase 3: Utility Tool Resolution + Overrides API** - Map utilities and expose extraPackages/overrides
- [ ] **Phase 4: Env Vars + Full devShell Assembly** - Read [env] section and wire full devShell integration
- [ ] **Phase 5: Tests, Documentation, and Publish** - nix flake check, README, example flake, git tag

## Phase Details

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
**Plans**: TBD

Plans:
- [ ] 02-01: Write lib/runtimes.nix with tool→nixpkgs attr mapping and version parser
- [ ] 02-02: Integrate runtime resolution into fromMiseToml

### Phase 3: Utility Tool Resolution + Overrides API
**Goal**: All `[tools]` entries resolve — either via utility mapping, user overrides, or a descriptive error message.
**Depends on**: Phase 2
**Requirements**: CORE-03, CORE-04, DX-01
**Success Criteria** (what must be TRUE):
  1. `lib/utilities.nix` exports a mapping covering: ripgrep/rg, fd, bat, jq, fzf, git, curl, wget, make, cmake, gh, delta, eza, zoxide, starship, just, hyperfine, tokei
  2. `extraPackages` argument appends additional packages to buildInputs
  3. `overrides` argument (attrset keyed by mise tool name) replaces a resolved package
  4. Completely unknown tool with no override throws `builtins.throw` with message naming the tool and explaining extraPackages/overrides
**Plans**: TBD

Plans:
- [ ] 03-01: Write lib/utilities.nix with common tool mapping
- [ ] 03-02: Implement extraPackages and overrides arguments in fromMiseToml
- [ ] 03-03: Implement unknown tool error with helpful message

### Phase 4: Env Vars + Full devShell Assembly
**Goal**: `[env]` section from `mise.toml` flows into the devShell as environment variables; full end-to-end integration works.
**Depends on**: Phase 3
**Requirements**: SHELL-01, SHELL-02
**Success Criteria** (what must be TRUE):
  1. `lib/env.nix` reads the `[env]` attrset from parsed TOML and returns a list of env var name/value pairs
  2. `mkShell` receives env vars from `[env]` section (visible in `nix develop` shell)
  3. A `mise.toml` with both `[tools]` and `[env]` produces a devShell with correct packages and environment variables
  4. `forAllSystems` wiring verified: flake exposes `devShells.x86_64-linux.default` and `devShells.aarch64-darwin.default`
**Plans**: TBD

Plans:
- [ ] 04-01: Write lib/env.nix and integrate into fromMiseToml
- [ ] 04-02: Wire forAllSystems and verify full devShell assembly end-to-end

### Phase 5: Tests, Documentation, and Publish
**Goal**: mise2nix is ready for public use — tested, documented, and git-tagged.
**Depends on**: Phase 4
**Requirements**: DX-02, DX-03, DX-04
**Success Criteria** (what must be TRUE):
  1. `nix flake check` passes with checks covering: runtime version mapping, utility mapping, env var passthrough, overrides API, unknown tool error
  2. `README.md` contains: project description, quickstart, supported tools table, API docs for `fromMiseToml`, overrides pattern, limitations
  3. `example/` directory contains a realistic `mise.toml` and `flake.nix` showing mise2nix usage
  4. Git tag `v0.1.0` exists; flake URL is documented in README
**Plans**: TBD

Plans:
- [ ] 05-01: Write nix flake checks for all major code paths
- [ ] 05-02: Write README.md with full documentation
- [ ] 05-03: Create example/ directory with realistic usage example and publish v0.1.0

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Flake Scaffold + Parser | 2/2 | Complete | 2026-03-23 |
| 2. Runtime Tool Resolution | 0/2 | Not started | - |
| 3. Utility Tool Resolution + Overrides API | 0/3 | Not started | - |
| 4. Env Vars + Full devShell Assembly | 0/2 | Not started | - |
| 5. Tests, Documentation, and Publish | 0/3 | Not started | - |
