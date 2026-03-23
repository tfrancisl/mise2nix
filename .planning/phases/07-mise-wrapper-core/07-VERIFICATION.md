---
phase: 07-mise-wrapper-core
verified: 2026-03-23T00:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
gaps: []
human_verification: []
---

# Phase 7: Mise Wrapper Core Verification Report

**Phase Goal:** The devShell ships a `mise` wrapper script that handles `mise use "known-backend:tool"` gracefully and passes all other subcommands through to the real mise binary unchanged.
**Verified:** 2026-03-23
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                 | Status     | Evidence                                                                    |
|----|---------------------------------------------------------------------------------------|------------|-----------------------------------------------------------------------------|
| 1  | devShell contains a mise wrapper script instead of bare pkgs.mise                    | VERIFIED   | `lib/default.nix` line 138: `packages = [miseWrapper] ++ ...`; `pkgs.mise` absent from packages list |
| 2  | mise run/list/exec and all non-use subcommands pass through to real mise binary unchanged | VERIFIED   | `lib/default.nix` lines 83-85: `if [ "$1" != "use" ]; then exec ${pkgs.mise}/bin/mise "$@"` |
| 3  | mise use pipx:black writes the entry to mise.toml and prints a mise2nix reload message   | VERIFIED   | `wrapper-use-writes-toml` check passes (nix build exit 0); grep confirms `"pipx:black" = "latest"` written |
| 4  | mise use node@22 writes node entry with version 22 to mise.toml                      | VERIFIED   | `@` parsing at lines 102-108 extracts VERSION and TOOL correctly; sed path writes `"TOOL" = "VERSION"` |
| 5  | Wrapper output attributes messages to mise2nix and instructs user to reload           | VERIFIED   | `wrapper-use-prints-message` check passes (nix build exit 0); `echo "[mise2nix]"` at lines 127-128 |
| 6  | nix flake check passes with wrapper-specific checks                                    | VERIFIED   | All 22 checks pass, including the 4 new wrapper checks; `nix flake check` exits 0 |
| 7  | wrapper-passthrough check proves non-use subcommands reach real mise binary            | VERIFIED   | `flake.nix` lines 285-339: check runs `mise --version > $out` via wrapper; nix build exits 0 |
| 8  | wrapper-use-writes-toml check proves mise use writes TOML entry                       | VERIFIED   | `flake.nix` lines 353-420: check uses `cp + chmod +w` then `mise use "pipx:black"`, greps for entry; exits 0 |
| 9  | wrapper-use-prints-message check proves output contains mise2nix attribution           | VERIFIED   | `flake.nix` lines 422-488: check captures stdout, greps for "mise2nix"; exits 0 |

**Score:** 9/9 truths verified

---

### Required Artifacts

| Artifact       | Expected                                                           | Status    | Details                                                                                       |
|----------------|--------------------------------------------------------------------|-----------|-----------------------------------------------------------------------------------------------|
| `lib/default.nix` | miseWrapper let-binding and replacement of pkgs.mise in packages list | VERIFIED  | Lines 82-129: `miseWrapper = pkgs.writeShellScriptBin "mise" ''...''`; line 138: `[miseWrapper]` |
| `flake.nix`    | Four new check derivations for wrapper behavior                    | VERIFIED  | Lines 285-488: all four checks present — wrapper-passthrough, wrapper-in-packages, wrapper-use-writes-toml, wrapper-use-prints-message |

---

### Key Link Verification

| From                          | To                        | Via                              | Status   | Details                                                                    |
|-------------------------------|---------------------------|----------------------------------|----------|----------------------------------------------------------------------------|
| `lib/default.nix`             | `pkgs.writeShellScriptBin` | `miseWrapper` let-binding        | WIRED    | Line 82: `miseWrapper = pkgs.writeShellScriptBin "mise" ''...''`           |
| `lib/default.nix`             | `pkgs.mkShell packages`   | miseWrapper replaces pkgs.mise   | WIRED    | Line 138: `packages = [miseWrapper] ++ resolvedPackages ++ extraPackages`  |
| `flake.nix` wrapper checks    | `lib/default.nix miseWrapper` | Duplicated writeShellScriptBin in check let blocks | WIRED | Lines 286-333, 354-401, 423-470: exact script duplicated inline in each check per design (miseWrapper is local to fromMiseToml closure) |

---

### Data-Flow Trace (Level 4)

The wrapper is a `writeShellScriptBin` derivation — it does not render dynamic data. The data flow is:
- Input: bash arguments (`$@`, `$1`, `$TOOL_SPEC`)
- Transformation: sed writes to `$TOML_FILE`; echo writes to stdout
- This is a shell script, not a data-rendering component — Level 4 does not apply

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `fromMiseToml` still evaluates as a function | `nix eval .#lib.fromMiseToml --apply 'f: builtins.typeOf f'` | `"lambda"` | PASS |
| wrapper-passthrough check builds | `nix build .#checks.x86_64-linux.wrapper-passthrough` | exit 0 | PASS |
| wrapper-in-packages check builds | `nix build .#checks.x86_64-linux.wrapper-in-packages` | exit 0 | PASS |
| wrapper-use-writes-toml check builds | `nix build .#checks.x86_64-linux.wrapper-use-writes-toml` | exit 0 | PASS |
| wrapper-use-prints-message check builds | `nix build .#checks.x86_64-linux.wrapper-use-prints-message` | exit 0 | PASS |
| Full flake check suite (22 checks) | `nix flake check` | exit 0, 22 checks pass | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description                                                                                                   | Status    | Evidence                                                                                     |
|-------------|-------------|---------------------------------------------------------------------------------------------------------------|-----------|----------------------------------------------------------------------------------------------|
| WRAP-01     | 07-01, 07-02 | devShell includes a `mise` wrapper script (writeShellScriptBin) that intercepts `mise use` and passes all other subcommands to real mise unchanged | SATISFIED | `miseWrapper` in `lib/default.nix` line 82; `packages = [miseWrapper]` line 138; `wrapper-in-packages` check passes |
| WRAP-02     | 07-01, 07-02 | `mise use "known-backend:tool"` writes entry to mise.toml and prints clear reload message                     | SATISFIED | sed-based TOML write at lines 113-118; echo messages at lines 127-128; `wrapper-use-writes-toml` check passes |
| DX-05       | 07-01, 07-02 | Wrapper output explains tool resolution is Nix-managed and what action to take next                           | SATISFIED | Lines 127-128: `[mise2nix]` attribution + `Run \`...\` to enter the updated shell`; DIRENV_DIR detection picks `direnv reload` vs `nix develop`; `wrapper-use-prints-message` check passes |
| DX-06       | 07-01, 07-02 | All non-`use` mise subcommands pass through to real mise binary with no modification or overhead               | SATISFIED | Lines 83-85: `exec ${pkgs.mise}/bin/mise "$@"` for non-use; `wrapper-passthrough` check runs `mise --version` and exits 0 |

No orphaned requirements: REQUIREMENTS.md traceability table maps WRAP-01, WRAP-02, DX-05, DX-06 to Phase 7 and all four are satisfied.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | No anti-patterns found |

Scan notes:
- No `TODO/FIXME/PLACEHOLDER` comments in modified files
- No `return null` / `return {}` / stub implementations
- `packages = [miseWrapper]` is the active wiring, not empty
- Nix store path references (`${pkgs.gnugrep}/bin/grep`, `${pkgs.gnused}/bin/sed`) used throughout — correct cross-platform practice per project decisions

---

### Human Verification Required

None. All behaviors verified programmatically via `nix flake check` and individual check builds.

---

### Gaps Summary

No gaps. All nine must-have truths verified. Phase goal is fully achieved.

The devShell produced by `fromMiseToml` ships a `writeShellScriptBin "mise"` wrapper that:
- Intercepts `mise use TOOL_SPEC`, writes `"tool" = "version"` to `mise.toml` via GNU sed, and prints a `[mise2nix]`-attributed reload instruction
- Detects `$DIRENV_DIR` to suggest `direnv reload` vs `nix develop`
- Routes all non-`use` subcommands to the real `${pkgs.mise}/bin/mise` via `exec` with zero overhead
- Is exercised by four passing `nix flake check` derivations covering every requirement

---

_Verified: 2026-03-23_
_Verifier: Claude (gsd-verifier)_
