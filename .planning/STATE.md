---
gsd_state_version: 1.0
milestone: v0.2.0
milestone_name: Backend Tool Resolution
status: Roadmap defined
stopped_at: v0.2.0 roadmap created (phases 6-8)
last_updated: "2026-03-23T00:00:00.000Z"
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State: mise2nix

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-23)

**Core value:** `mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; }` produces a working devShell — zero manual Nix required for common toolsets.
**Current focus:** Milestone v0.2.0 — Backend Tool Resolution (phases 6-8)

## Current Phase

Phase: 6 of 8 (Backend Syntax Detection + Mapping Tables)
Plan: —
Status: Ready to plan
Last activity: 2026-03-23 — v0.2.0 roadmap created

Progress: [░░░░░░░░░░] 0% (v0.2.0 phases)

## Phase Status

| Phase | Goal | Status |
|-------|------|--------|
| 6. Backend Syntax Detection + Mapping Tables | `fromMiseToml` detects backend:tool syntax; pipx/npm/cargo tables resolve; unknowns throw | Not started |
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

## Notes

- Phase 6 depends on Phase 5 (v0.1.0 must ship first)
- Wrapper (phase 7) replaces bare `pkgs.mise` with `writeShellScriptBin` wrapper
- flake.nix patching (phase 8) is pure shell/sed — no Nix AST manipulation
- direnv reload integration remains deferred to v0.3.0+

## Session Continuity

Last session: 2026-03-23
Stopped at: v0.2.0 roadmap written — phases 6, 7, 8 defined
Resume file: None
