---
phase: 06-backend-syntax-detection-mapping-tables
verified: 2026-03-23T00:00:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
---

# Phase 6: Backend Syntax Detection and Mapping Tables — Verification Report

**Phase Goal:** `fromMiseToml` understands `backend:tool` syntax and resolves known backends (pipx, npm, cargo) via nixpkgs mapping tables — unknown backends and unmapped tools produce a clear error.
**Verified:** 2026-03-23
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                              | Status     | Evidence                                                                                                                    |
|----|------------------------------------------------------------------------------------|------------|-----------------------------------------------------------------------------------------------------------------------------|
| 1  | A mise.toml with 'pipx:black' resolves to pkgs.python3Packages.black              | VERIFIED   | `lib/backends/pipx.nix` line 2: `inherit (pkgs.python3Packages) black;`; `resolve-pipx-black` check in flake.nix evaluates to a derivation |
| 2  | A mise.toml with 'npm:prettier' resolves to pkgs.nodePackages.prettier            | VERIFIED   | `lib/backends/npm.nix` line 3: `inherit (pkgs.nodePackages) prettier;`; `resolve-npm-prettier` check evaluates successfully |
| 3  | A mise.toml with 'cargo:ripgrep' resolves to pkgs.ripgrep                         | VERIFIED   | `lib/backends/cargo.nix` line 6: `inherit (pkgs) ripgrep;`; `resolve-cargo-ripgrep` check evaluates successfully           |
| 4  | A mise.toml with 'ubi:some-tool' throws a descriptive error naming the backend    | VERIFIED   | `lib/default.nix` line 26: error message names backend, lists supported backends, explains escape hatches; `unknown-backend-error` check uses `builtins.tryEval` — `result.success` is false |
| 5  | A mise.toml with 'pipx:nonexistent' throws a descriptive error naming the tool    | VERIFIED   | `lib/default.nix` line 33-34: error names tool and backend; `unmapped-tool-error` check uses `pipx:nonexistent_tool_xyz` — `result.success` is false |
| 6  | overrides."pipx:black" takes priority over the backend mapping table              | VERIFIED   | `lib/default.nix` line 55: `overrides.${name} or (...)` is the outermost wrapper — runs before `isBackend` branch; `backend-overrides-win` check evaluates successfully |
| 7  | Plain tool names (no colon) still route through the existing runtime/utility cascade | VERIFIED | `lib/default.nix` lines 60-66: after `isBackend` check, falls through to `runtimes ? ${name}`, `utilities ? ${name}`, or throw; all 12 pre-existing checks pass including `runtime-resolution`, `resolve-utilities`, `full-integration` |

**Score:** 7/7 truths verified

---

### Required Artifacts

| Artifact                    | Expected                                          | Status   | Details                                                                                         |
|-----------------------------|---------------------------------------------------|----------|-------------------------------------------------------------------------------------------------|
| `lib/backends/pipx.nix`     | pipx backend mapping table (12 tools)             | VERIFIED | Exists, 12 entries (11 via `inherit (pkgs.python3Packages) X` + `pip-tools` explicit + `pkgs.poetry` top-level); all 12 tools present |
| `lib/backends/npm.nix`      | npm backend mapping table (12 tools)              | VERIFIED | Exists, 12 entries (3 via `pkgs.nodePackages.*`, 9 top-level `pkgs.*`); all 12 tools present   |
| `lib/backends/cargo.nix`    | cargo backend mapping table (12 tools)            | VERIFIED | Exists, 12 entries (10 via `inherit (pkgs) X` + 2 quoted hyphenated keys); all 12 tools present |
| `lib/default.nix`           | Backend detection via builtins.match and resolveBackend dispatch | VERIFIED | `resolveBackend` at line 22, `builtins.match "([^:]+):(.*)" name` at line 44, `backends` attrset at lines 9-13, `overrides.${name} or` outermost at line 55 |
| `flake.nix`                 | Six new check derivations for backend resolution  | VERIFIED | All six checks present at lines 200, 212, 224, 236, 253, 270; all 18 total checks evaluate to derivations under `nix flake check --no-build` |

---

### Key Link Verification

| From                              | To                        | Via                                    | Status   | Details                                                                           |
|-----------------------------------|---------------------------|----------------------------------------|----------|-----------------------------------------------------------------------------------|
| `lib/default.nix`                 | `lib/backends/pipx.nix`   | `import ./backends/pipx.nix`           | WIRED    | Line 10: `pipx = import ./backends/pipx.nix {inherit pkgs;};`                    |
| `lib/default.nix`                 | `lib/backends/npm.nix`    | `import ./backends/npm.nix`            | WIRED    | Line 11: `npm = import ./backends/npm.nix {inherit pkgs;};`                      |
| `lib/default.nix`                 | `lib/backends/cargo.nix`  | `import ./backends/cargo.nix`          | WIRED    | Line 12: `cargo = import ./backends/cargo.nix {inherit pkgs;};`                  |
| `lib/default.nix` resolve fn      | `resolveBackend` function | `builtins.match` colon detection       | WIRED    | Line 44: `builtins.match "([^:]+):(.*)" name`; line 59: `then resolveBackend backend tool v` |
| `flake.nix` backend checks        | `lib/default.nix` resolveBackend | `self.lib.fromMiseToml` with TOML fixtures | WIRED | Six check derivations each call `self.lib.fromMiseToml` with inline TOML containing `backend:tool` keys; `nix flake check --no-build` confirms all evaluate |

---

### Data-Flow Trace (Level 4)

Not applicable — this phase produces a Nix library (pure functional evaluation), not a component rendering dynamic data. The flake checks serve as the data-flow proof: TOML fixtures with backend keys flow through `fromMiseToml` → `resolve` → `resolveBackend` → backend table → derivation output. All 18 checks evaluate cleanly.

---

### Behavioral Spot-Checks

`nix flake check --no-build` was run and produced the following (eval-only, no builds executed):

| Behavior                                            | Check Name             | Result                                          | Status |
|-----------------------------------------------------|------------------------|-------------------------------------------------|--------|
| pipx:black resolves to a valid devShell derivation  | resolve-pipx-black     | Evaluated to `/nix/store/gq5kgqjii7ryp9mhq40bzgilhw6v01w6-resolve-pipx-black.drv`     | PASS   |
| npm:prettier resolves to a valid devShell derivation | resolve-npm-prettier  | Evaluated to `/nix/store/gmxfdh13cvskcvs7bck5ik23bdr61gxd-resolve-npm-prettier.drv`   | PASS   |
| cargo:ripgrep resolves to a valid devShell derivation | resolve-cargo-ripgrep | Evaluated to `/nix/store/n98608v9kgkf85gnk4bvs6qk9xj2nwfk-resolve-cargo-ripgrep.drv` | PASS   |
| ubi:some-tool throws for unknown backend             | unknown-backend-error  | Evaluated to `/nix/store/h7kig79lz35gynlc0m04h7jbab6aa5lk-unknown-backend-error.drv`  | PASS   |
| pipx:nonexistent_tool_xyz throws for unmapped tool   | unmapped-tool-error    | Evaluated to `/nix/store/9x0b2jyg6kvh6iqkph4xxzyfxppimb8b-unmapped-tool-error.drv`   | PASS   |
| overrides."pipx:black" wins over backend table       | backend-overrides-win  | Evaluated to `/nix/store/ajf85ligm7vli4k0g2wbkhbni2zkz4ah-backend-overrides-win.drv`  | PASS   |
| All 12 pre-existing checks still pass                | (12 checks)            | All 12 evaluated to valid derivations                                                  | PASS   |

**Total: 18/18 checks evaluate without error.**

---

### Requirements Coverage

| Requirement | Source Plan  | Description                                                                                           | Status    | Evidence                                                                              |
|-------------|--------------|-------------------------------------------------------------------------------------------------------|-----------|---------------------------------------------------------------------------------------|
| BACKEND-01  | 06-01, 06-02 | `fromMiseToml` detects `backend:tool` syntax and routes to the appropriate backend resolver           | SATISFIED | `builtins.match "([^:]+):(.*)" name` in `lib/default.nix:44`; `isBackend` branch at line 58 |
| BACKEND-02  | 06-01, 06-02 | `pipx:tool` resolves to `pkgs.python3Packages.*` via 12-tool mapping table                           | SATISFIED | `lib/backends/pipx.nix` has all 12 tools; `resolve-pipx-black` check passes          |
| BACKEND-03  | 06-01, 06-02 | `npm:tool` resolves to `pkgs.nodePackages.*` or top-level `pkgs.*` via 12-tool mapping table         | SATISFIED | `lib/backends/npm.nix` has all 12 tools; `resolve-npm-prettier` check passes. Note: requirement examples listed webpack/ts-node/rollup/svelte/nx (not in nixpkgs); actual table substitutes biome/pnpm/yarn/wrangler/tsx — all verifiably in nixpkgs. Requirement uses "e.g." and "≤12" constraint met. |
| BACKEND-04  | 06-01, 06-02 | `cargo:tool` resolves to `pkgs.*` via 12-tool mapping table                                          | SATISFIED | `lib/backends/cargo.nix` has all 12 tools; `resolve-cargo-ripgrep` check passes      |
| BACKEND-05  | 06-01, 06-02 | Unknown backend or unmapped tool in known backend throws a descriptive error with escape hatch info   | SATISFIED | Two distinct error messages in `lib/default.nix:25-26` and `lib/default.nix:33-34`; `unknown-backend-error` and `unmapped-tool-error` checks confirm throws fire |

All five BACKEND requirements declared in both plans are accounted for and satisfied.

**Orphaned requirements check:** No additional BACKEND-* requirements are mapped to Phase 6 in REQUIREMENTS.md beyond BACKEND-01 through BACKEND-05. No orphaned requirements.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | No anti-patterns found in phase 06 files |

Scanned: `lib/backends/pipx.nix`, `lib/backends/npm.nix`, `lib/backends/cargo.nix`, `lib/default.nix`, `flake.nix` (backend checks section). No TODO/FIXME/placeholder comments, no empty return values, no hardcoded stub data.

---

### Human Verification Required

None. All seven observable truths are verifiable programmatically via `nix flake check --no-build` and direct file inspection. The error message text is confirmed present in `lib/default.nix` (lines 26 and 33-34). No UI, visual, real-time, or external service behavior involved.

---

### Gaps Summary

No gaps. All must-have truths verified, all artifacts exist and are substantive and wired, all five BACKEND requirements satisfied, all 18 flake checks evaluate without error, and no anti-patterns found.

One note for the record: BACKEND-03 requirement text lists example npm tools (webpack, ts-node, rollup, svelte, nx) that are not currently packaged in nixpkgs. The implementation correctly substituted verified nixpkgs-available packages (biome, pnpm, yarn, wrangler, tsx). The requirement's "e.g." phrasing and "≤12 common tools" cap make this compliant — the goal is a useful mapping table, not exact reproduction of the example list.

---

_Verified: 2026-03-23_
_Verifier: Claude (gsd-verifier)_
