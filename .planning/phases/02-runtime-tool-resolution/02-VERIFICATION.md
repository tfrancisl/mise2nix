---
phase: 02-runtime-tool-resolution
verified: 2026-03-22T00:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
gaps: []
human_verification: []
---

# Phase 2: Runtime Tool Resolution Verification Report

**Phase Goal:** Major language runtimes in `[tools]` resolve to the correct version-specific nixpkgs attribute (e.g. `node = "22"` -> `pkgs.nodejs_22`).
**Verified:** 2026-03-22
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                    | Status     | Evidence                                                                               |
| --- | ---------------------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------- |
| 1   | `lib/runtimes.nix` exports a mapping of mise tool names to version-resolving functions   | VERIFIED   | File exists, 15-key attrset confirmed via `nix eval builtins.attrNames runtimes`       |
| 2   | Covered runtimes: node/nodejs, python, go/golang, ruby, rust, java, erlang, elixir, deno, bun, php, terraform, kubectl | VERIFIED   | All 15 keys present: `bun deno elixir erlang go golang java kubectl node nodejs php python ruby rust terraform` |
| 3   | Version string parsing extracts major (and minor where needed): "22"->22, "3.11.9"->311  | VERIFIED   | `runtimes.node "22"` -> `nodejs-22.22.1`; `runtimes.python "3.11.9"` -> `python3-3.11.15` |
| 4   | `"latest"` falls through to unversioned utility package without error                    | VERIFIED   | `runtimes.node "latest"` -> `nodejs-24.13.0` (pkgs.nodejs); `resolve-latest` nix check exits 0 |
| 5   | Resolved runtime packages appear in devShell packages                                    | VERIFIED   | `nix build .#checks.x86_64-linux.runtime-resolution` exits 0; `nix build .#checks.x86_64-linux.devshell-builds` exits 0 |

**Score:** 5/5 truths verified

---

### Required Artifacts

| Artifact           | Expected                                              | Status     | Details                                                                                 |
| ------------------ | ----------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------- |
| `lib/runtimes.nix` | Runtime resolver attrset (15 keys, 13 runtimes + 2 aliases) | VERIFIED | 160 lines; `{ lib, pkgs }:` signature; `splitVer`, `major`, `majMin`, `majMinUs` helpers; `lib.splitString` (not `builtins.split`); `builtins.toString` at all call sites |
| `lib/default.nix`  | Updated `fromMiseToml` wiring runtimes into mkShell   | VERIFIED   | 22 lines; `import ./runtimes.nix { inherit lib pkgs; }` present; `builtins.mapAttrs` + null guard; `packages = resolvedPackages` |
| `flake.nix`        | `runtime-resolution` and `resolve-latest` check derivations | VERIFIED | Both derivations present; `builtins.toFile "mise-latest.toml"` inline fixture; all 4 checks intact |
| `mise.toml`        | Test fixture with `node = "22"`, `python = "3.11"`    | VERIFIED   | Contains `[tools]` with `node = "22"` and `python = "3.11"`                            |

---

### Key Link Verification

| From                               | To                          | Via                                                | Status   | Details                                                   |
| ---------------------------------- | --------------------------- | -------------------------------------------------- | -------- | --------------------------------------------------------- |
| `lib/default.nix`                  | `lib/runtimes.nix`          | `import ./runtimes.nix { inherit lib pkgs; }`      | WIRED    | Line 5 of lib/default.nix                                 |
| `lib/default.nix`                  | `pkgs.mkShell`              | `packages = resolvedPackages`                      | WIRED    | Line 21; resolvedPackages comes from filtered mapAttrs    |
| `flake.nix checks.runtime-resolution` | `self.lib.fromMiseToml` | String interpolation `${devShell}` forces eval     | WIRED    | Lines 44-50 of flake.nix                                  |
| `flake.nix checks.resolve-latest`  | `self.lib.fromMiseToml`     | `builtins.toFile` inline TOML with "latest" values | WIRED    | Lines 51-63 of flake.nix                                  |

---

### Data-Flow Trace (Level 4)

| Artifact           | Data Variable      | Source                             | Produces Real Data | Status   |
| ------------------ | ------------------ | ---------------------------------- | ------------------ | -------- |
| `lib/default.nix`  | `resolvedPackages` | `lib/runtimes.nix` resolver funcs  | Yes — real nixpkgs derivations (verified: nodejs-22.22.1, python3-3.11.15) | FLOWING  |
| `lib/runtimes.nix` | resolver return values | `pkgs.nodejs_22`, `pkgs.python311`, etc. | Yes — nixpkgs attrs bound at module import | FLOWING |

---

### Behavioral Spot-Checks

| Behavior                                          | Command / Check                                                           | Result                       | Status  |
| ------------------------------------------------- | ------------------------------------------------------------------------- | ---------------------------- | ------- |
| `node "22"` resolves to nodejs_22                 | `nix eval ... (runtimes.node "22").name`                                  | `"nodejs-22.22.1"`           | PASS    |
| `python "3.11.9"` parses to python311             | `nix eval ... (runtimes.python "3.11.9").name`                            | `"python3-3.11.15"`          | PASS    |
| `node "latest"` returns unversioned nodejs        | `nix eval ... (runtimes.node "latest").name`                              | `"nodejs-24.13.0"`           | PASS    |
| Unsupported version throws                        | `nix eval ... builtins.tryEval (runtimes.node "99")`                      | `{ success = false; ... }`   | PASS    |
| Unknown tool not in runtimes attrset              | `nix eval ... runtimes ? "unknowntool"`                                   | `false`                      | PASS    |
| `rust "1.80"` silently returns rustup             | `nix eval ... (runtimes.rust "1.80").name`                                | `"rustup-1.28.2"`            | PASS    |
| All 4 nix check derivations pass                  | `nix build .#checks.x86_64-linux.{runtime-resolution,resolve-latest,parse-toml,devshell-builds} --no-link` | exit 0 | PASS    |

---

### Requirements Coverage

| Requirement | Source Plan | Description                                                                 | Status    | Evidence                                                         |
| ----------- | ----------- | --------------------------------------------------------------------------- | --------- | ---------------------------------------------------------------- |
| CORE-02     | 02-01, 02-02 | Major runtimes resolved to version-specific nixpkgs attrs                  | SATISFIED | `runtimes.node "22"` -> `nodejs_22`; `runtimes.python "3.11"` -> `python311`; devshell-builds + runtime-resolution checks green |
| CORE-03     | 02-01, 02-02 | "latest" version strings resolved to `pkgs.X` (latest at nixpkgs pin)     | SATISFIED | `runtimes.node "latest"` -> `pkgs.nodejs`; `resolve-latest` check (node/python/go all "latest") exits 0 |

No orphaned requirements: REQUIREMENTS.md maps both CORE-02 and CORE-03 to Phase 2 Plan 01, and both are claimed in the plan frontmatter.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| —    | —    | —       | —        | —      |

No anti-patterns found. No TODO/FIXME/placeholder comments in `lib/`. `packages = []` stub replaced with `packages = resolvedPackages`.

---

### Human Verification Required

None — all success criteria are verifiable programmatically via Nix evaluation and check derivation builds.

---

### Gaps Summary

No gaps. All 5 observable truths verified. All artifacts exist and are substantive (not stubs). All key links wired. Data flows end-to-end from resolver functions to real nixpkgs derivations. Both CORE-02 and CORE-03 requirements satisfied with direct Nix evaluation evidence.

---

_Verified: 2026-03-22_
_Verifier: Claude (gsd-verifier)_
