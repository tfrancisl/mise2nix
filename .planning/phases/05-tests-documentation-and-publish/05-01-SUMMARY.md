---
phase: "05"
plan: "01"
subsystem: checks
tags: [nix, flake-check, testing, error-handling, env-vars]
dependency_graph:
  requires: [04-02]
  provides: [unsupported-version-error-check, integer-env-var-check]
  affects: [flake.nix]
tech_stack:
  added: []
  patterns: [tryEval+deepSeq for lazy throw testing, builtins.toFile inline TOML fixtures]
key_files:
  created: []
  modified: [flake.nix]
decisions:
  - Added unsupported-version-error check using established tryEval+deepSeq pattern from unknown-tool-error
  - Added integer-env-var check to cover bare integer TOML coercion path in env.nix
  - Both checks use inline builtins.toFile TOML fixtures (no new .toml files added to repo)
metrics:
  duration: "1min"
  completed: "2026-03-23"
  tasks: 2
  files: 1
---

# Phase 05 Plan 01: Fill nix flake check Gaps Summary

**One-liner:** Added unsupported-version-error and integer-env-var checks to cover runtime version throw path and TOML integer coercion — flake now has 12 checks.

## What Was Built

Added two new `nix flake check` derivations to `flake.nix`:

1. **`unsupported-version-error`** — Tests that requesting `node = "18"` (not in the supported map: 20, 22, 24, 25) causes `resolveNode` in `lib/runtimes.nix` to throw a descriptive error. Uses the established `builtins.tryEval (builtins.deepSeq devShell.nativeBuildInputs devShell)` pattern from the existing `unknown-tool-error` check.

2. **`integer-env-var`** — Tests that a bare integer TOML value (`PORT = 8080`, no quotes) is correctly coerced to a string by `builtins.toString` in `lib/env.nix`. The existing `env-var-passthrough` check only used quoted strings (`PORT = "8080"`), leaving this integer path untested.

## Verification Results

```
nix flake check — 12 checks pass (all x86_64-linux)
```

- parse-toml: PASS
- devshell-builds: PASS
- runtime-resolution: PASS
- resolve-latest: PASS
- resolve-utilities: PASS
- extra-packages: PASS
- overrides-work: PASS
- unsupported-version-error: PASS (NEW)
- unknown-tool-error: PASS
- env-var-passthrough: PASS
- integer-env-var: PASS (NEW)
- full-integration: PASS

## Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Add unsupported-version-error check | e66dea6 | flake.nix |
| 2 | Add integer-env-var check | a047b16 | flake.nix |

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- flake.nix modified: confirmed (git log shows e66dea6, a047b16)
- unsupported-version-error check: confirmed (nix flake check passes 12 checks)
- integer-env-var check: confirmed (nix flake check passes 12 checks)
