---
gsd_state_version: 1.0
milestone: v0.1.0
milestone_name: Foundation
status: completed
stopped_at: Completed 06-backend-syntax-detection-mapping-tables/06-02-PLAN.md — Phase 6 complete, 18 flake checks passing
last_updated: "2026-03-23T22:26:51.745Z"
last_activity: 2026-03-23
progress:
  total_phases: 3
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
  percent: 50
---

# Project State: mise2nix

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-23)

**Core value:** `mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; }` produces a working devShell — zero manual Nix required for common toolsets.
**Current focus:** Phase 06 — backend-syntax-detection-mapping-tables

## Current Phase

Phase: 7 of 8 (mise wrapper core)
Plan: Not started
Status: Phase 6 complete — ready for phase 7
Last activity: 2026-03-23

Progress: [█████░░░░░] 50% (v0.2.0 phases)

## Phase Status

| Phase | Goal | Status |
|-------|------|--------|
| 6. Backend Syntax Detection + Mapping Tables | `fromMiseToml` detects backend:tool syntax; pipx/npm/cargo tables resolve; unknowns throw | Complete |
| 7. Mise Wrapper Core | Wrapper intercepts `mise use known-backend:tool`; all other subcommands pass through | Not started |
| 8. Interactive Override Patching | `mise use unknown-backend:tool` prompts for nixpkgs attr and patches flake.nix | Not started |

## Decisions (Accumulated from v0.1.0)

- lib output is NOT wrapped in forAllSystems — fromMiseToml takes pkgs as argument
- forAllSystems uses explicit 4-system list via nixpkgs.lib.genAttrs
- Single-version runtimes (rust, deno, bun, terraform, kubectl) silently map all version strings
- Resolution cascade order: overrides -> runtimes -> utilities -> throw
- builtins.toFile used for inline TOML fixtures in checks
- MISE_NOT_FOUND_AUTO_INSTALL=false injected into every devShell
- pkgs.mise auto-included in every devShell (will be replaced by wrapper in phase 7)
- backend tables store plain packages not functions — version ignored for backend resolution (nixpkgs pin is the version)
- overrides.${name} check precedes isBackend branch — ensures overrides win for pipx:black and plain keys alike
- resolveBackend throws two distinct errors: unknown backend (naming supported list) and unmapped tool within known backend
- Use builtins.seq devShell.drvPath null (not deepSeq nativeBuildInputs) to force mkShell eval in tryEval error checks — avoids stack overflow

## Notes

- Phase 6 depends on Phase 5 (v0.1.0 must ship first)
- Wrapper (phase 7) replaces bare `pkgs.mise` with `writeShellScriptBin` wrapper
- flake.nix patching (phase 8) is pure shell/sed — no Nix AST manipulation
- direnv reload integration remains deferred to v0.3.0+

## Session Continuity

Last session: 2026-03-23
Stopped at: Completed 06-backend-syntax-detection-mapping-tables/06-02-PLAN.md — Phase 6 complete, 18 flake checks passing
Resume file: None
