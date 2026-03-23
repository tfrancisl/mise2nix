# Phase 2: Runtime Tool Resolution — Discussion Log

**Date:** 2026-03-23
**Phase:** 02-runtime-tool-resolution

## Gray Areas Presented

1. Runtime coverage
2. **Version mismatch handling** ← selected
3. Lookup mechanism

## Discussion

### Version mismatch handling

**Q:** What happens when a user writes `node = "16"` but nixpkgs-unstable no longer ships `nodejs_16`?

**Options presented:**
- Throw a Nix eval error (Recommended)
- Fall back to latest supported
- Leave it for Phase 3

**Selected:** Throw a Nix eval error

**Notes:** Phase 3 (DX-01) will enrich the message further to explain `overrides`/`extraPackages`. Phase 2 lays the foundation with `builtins.throw` + a message listing supported versions.

## Unselected Areas (Claude's Discretion)

- **Runtime coverage** — not discussed; left to Claude to cover all 13 from roadmap or a pragmatic subset
- **Lookup mechanism** — not discussed; left to Claude to choose hardcoded attrset vs dynamic attr construction
