# Phase 2: Runtime Tool Resolution - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Resolve major language runtimes from `[tools]` to version-specific nixpkgs packages. `node = "22"` → `pkgs.nodejs_22`, `python = "3.11"` → `pkgs.python311`. The `fromMiseToml` function is updated to pass resolved packages into `pkgs.mkShell { packages = [...]; }`. Utility tools ("latest" version), `[env]` vars, and the overrides API are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Version mismatch handling
- **D-01:** When a user specifies a version not available in nixpkgs (e.g. `node = "16"` when nixpkgs-unstable no longer ships `nodejs_16`), throw a Nix eval error via `builtins.throw`. The error must name the specific tool and version requested.
- **D-02:** The error message should list which versions ARE supported. Example: `"mise2nix: node version 16 not available in nixpkgs — supported: 18, 20, 22"`.
- **D-03:** Phase 3 (DX-01) will enrich these error messages further (explaining `overrides`/`extraPackages`). Phase 2 should use `builtins.throw` with a clear message as the foundation.

### Claude's Discretion
- Runtime coverage list (all 13 from roadmap: node/nodejs, python, go/golang, ruby, rust, java, erlang, elixir, deno, bun, php, terraform, kubectl — or a pragmatic first-tier subset)
- Version string parsing mechanism (`lib.splitString`, string manipulation, etc.)
- Lookup strategy: hardcoded attrset vs dynamic attr construction (e.g. `pkgs."nodejs_${major}"`)
- File structure: whether `lib/runtimes.nix` is a single flat attrset or contains helper functions

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs — requirements are fully captured in decisions above and REQUIREMENTS.md.

### Project requirements
- `.planning/REQUIREMENTS.md` — CORE-02 (runtime resolution), CORE-03 (utilities/"latest" fall-through)
- `.planning/PROJECT.md` — Two-tier resolution strategy, constraints (pure Nix, pkgs.mkShell, no flake-utils)

### Existing implementation
- `lib/default.nix` — Current `fromMiseToml` skeleton; `packages = []` is the integration point
- `flake.nix` — How `lib` is imported and `fromMiseToml` is called; `checks` output for regression tests

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/default.nix`: `fromMiseToml = path: { pkgs }:` — already parses `config.tools or {}`. Phase 2 maps over `tools` attrset to resolve packages.

### Established Patterns
- Module signature: `{ lib }:` at the top of lib files; `lib` passed from flake.nix as `nixpkgs.lib`
- `pkgs.mkShell { packages = []; }` → becomes `pkgs.mkShell { packages = resolvedPackages; }`
- `checks` in `flake.nix` serve as the regression gate — new checks for Phase 2 should verify tool resolution

### Integration Points
- `lib/default.nix` line `packages = [];` — replace with resolved packages list
- New file: `lib/runtimes.nix` — imported by `lib/default.nix`
- `flake.nix` checks output — add Phase 2 integration checks

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-runtime-tool-resolution*
*Context gathered: 2026-03-23*
