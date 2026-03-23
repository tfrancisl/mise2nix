# Phase 8: Interactive Override Patching - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-23
**Phase:** 08-interactive-override-patching
**Areas discussed:** detection scope, input validation

---

## Detection Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Unknown backend only | Prompt only when backend prefix is not pipx/npm/cargo | |
| Full WRAP-03 compliance | Prompt for unknown backends AND unmapped tools within known backends | ✓ |

**User's choice:** Full WRAP-03 compliance
**Notes:** User pointed out that known tool lists can be derived from existing Nix backend attrsets at build time using `builtins.attrNames`, interpolated into the `writeShellScriptBin` script — zero duplication, always in sync. This resolved the "replication fragility" concern with the full-compliance approach.

---

## Input Validation

| Option | Description | Selected |
|--------|-------------|----------|
| Accept bare name or full path | Strip `pkgs.` prefix if present, write `pkgs.<name>` | ✓ |
| Accept any non-empty string verbatim | Write exactly what user types | |

**User's choice:** Accept bare name or full path
**Notes:** `ripgrep` and `pkgs.ripgrep` both produce `pkgs.ripgrep` in the overrides entry.

---

## Claude's Discretion

- flake.nix patching sed strategy
- Behavior when no `flake.nix` found in walk-up
- Behavior when no `overrides = {` exists in the found `flake.nix`
- Exact prompt wording

## Deferred Ideas

None.
