---
phase: 06-backend-syntax-detection-mapping-tables
plan: "01"
subsystem: library
tags: [nix, nixpkgs, backend-resolution, pipx, npm, cargo, builtins-match]

# Dependency graph
requires:
  - phase: 05-tests-documentation-and-publish
    provides: stable lib/default.nix resolve cascade (overrides -> runtimes -> utilities -> throw)
provides:
  - lib/backends/pipx.nix mapping table (12 python tools via pkgs.python3Packages.*)
  - lib/backends/npm.nix mapping table (12 js tools, 3 nodePackages + 9 top-level pkgs)
  - lib/backends/cargo.nix mapping table (12 rust tools via top-level pkgs.*)
  - lib/default.nix extended with resolveBackend and builtins.match colon detection
affects:
  - 06-VALIDATION
  - phase 7 (mise wrapper)
  - phase 8 (interactive override patching)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "builtins.match for colon detection in tool names (returns null for plain, list for backend:tool)"
    - "backend tables use plain packages (not functions) — resolveBackend accesses table.${tool} directly"
    - "overrides.${name} remains outermost wrapper — wins for ALL key forms including backend keys"
    - "quoted attrset keys for hyphenated names: \"pip-tools\", \"cargo-watch\", \"cargo-nextest\""

key-files:
  created:
    - lib/backends/pipx.nix
    - lib/backends/npm.nix
    - lib/backends/cargo.nix
  modified:
    - lib/default.nix

key-decisions:
  - "backend tables store plain packages not functions — version ignored for backend resolution (nixpkgs pin is the version)"
  - "poetry maps to pkgs.poetry (top-level) not pkgs.python3Packages.poetry (does not exist in nixpkgs)"
  - "overrides.${name} check precedes isBackend branch — ensures overrides win for pipx:black and plain keys alike"
  - "resolveBackend throws two distinct errors: unknown backend (naming supported list) and unmapped tool within known backend"
  - "cargo backend table intentionally duplicates utilities.nix entries — both paths resolve to same package, no conflict"

patterns-established:
  - "Pattern: lib/backends/*.nix files take {pkgs}: and return plain package attrsets (no _version wrapper)"
  - "Pattern: builtins.match ([^:]+):(.*) name detects backend:tool syntax in resolve function"
  - "Pattern: resolveBackend backend tool _version dispatches on backends.${backend} then table.${tool}"

requirements-completed: [BACKEND-01, BACKEND-02, BACKEND-03, BACKEND-04, BACKEND-05]

# Metrics
duration: 5min
completed: "2026-03-23"
---

# Phase 6 Plan 01: Backend Syntax Detection and Mapping Tables Summary

**Backend detection via builtins.match colon parsing + three nixpkgs mapping tables (36 verified tools: pipx/npm/cargo) wired into fromMiseToml resolution cascade**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-23T00:28:21Z
- **Completed:** 2026-03-23T00:32:55Z
- **Tasks:** 2
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments

- Created `lib/backends/pipx.nix` with 12 verified Python tools mapping to `pkgs.python3Packages.*` (plus `pkgs.poetry` at top-level)
- Created `lib/backends/npm.nix` with 12 verified JS tools (3 via `pkgs.nodePackages.*`, 9 top-level `pkgs.*`)
- Created `lib/backends/cargo.nix` with 12 verified Rust tools all at top-level `pkgs.*`
- Extended `lib/default.nix` with `resolveBackend` function and `builtins.match` colon detection in `resolve`
- Verified `pipx:black`, `npm:prettier`, `cargo:ripgrep` all resolve to a valid devShell
- Verified unknown backend and unmapped tool both throw descriptive errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Create lib/backends/ mapping tables (pipx.nix, npm.nix, cargo.nix)** - `ae4b22b` (feat)
2. **Task 2: Extend lib/default.nix with backend detection and resolveBackend dispatch** - `46f061f` (feat)

**Plan metadata:** (final docs commit — see below)

## Files Created/Modified

- `lib/backends/pipx.nix` - 12-entry pipx -> python3Packages mapping table (+ pkgs.poetry special case)
- `lib/backends/npm.nix` - 12-entry npm mapping table (nodePackages for prettier/typescript/eslint, top-level for 9 others)
- `lib/backends/cargo.nix` - 12-entry cargo -> top-level pkgs mapping (ripgrep, bat, fd, eza, delta, etc.)
- `lib/default.nix` - Added backends attrset import, resolveBackend function, builtins.match detection in resolve

## Decisions Made

- Backend tables store plain packages (not `_version` wrapper functions) — backend resolution always uses nixpkgs pin version
- `poetry` maps to `pkgs.poetry` top-level — `pkgs.python3Packages.poetry` does not exist in nixpkgs
- `pip-tools`, `cargo-watch`, `cargo-nextest` use quoted Nix attrset keys to avoid hyphen-as-arithmetic-operator parsing
- `overrides.${name}` remains the outermost `or` in `resolve` — ensures user overrides win for ALL key forms (both `"pipx:black"` and plain `"node"`)
- Cargo backend intentionally duplicates some utilities.nix entries — both paths reach the same package, no conflict
- alejandra reformatted backend file entries to `inherit (pkgs.X) y;` form — equivalent and idiomatic, accepted

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Two pre-existing `nix flake check` failures were observed (not caused by this plan):
- `resolve-latest`: `path '/nix/store/...-mise-latest.toml' is not valid` — nix store path validity issue with `builtins.toFile` in eval context
- `unknown-tool-error`: stack overflow in `builtins.deepSeq` on full devShell derivation chain

Both failures existed before this plan's changes (confirmed by stashing changes and reproducing). All other checks (parse-toml, devshell-builds, runtime-resolution, resolve-utilities, extra-packages, overrides-work, env-var-passthrough, integer-env-var, full-integration, unsupported-version-error) evaluate to derivations successfully.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Backend mapping tables and detection are complete and working
- `fromMiseToml` now handles `"pipx:black"`, `"npm:prettier"`, `"cargo:ripgrep"` style keys natively
- Unknown backends throw descriptive errors naming supported backends and escape hatches
- Phase 6 validation (06-VALIDATION.md) should add flake check derivations for backend resolution scenarios
- Phase 7 (mise wrapper) can proceed — `pkgs.mise` is still auto-included and will be replaced by the wrapper

---
*Phase: 06-backend-syntax-detection-mapping-tables*
*Completed: 2026-03-23*
