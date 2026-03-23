# Phase 7: Mise Wrapper Core - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-23
**Phase:** 07-mise-wrapper-core
**Areas discussed:** mise use passthrough strategy, trigger conditions, wrapper code organization

---

## mise use Passthrough Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Pass to real mise | Call real `mise use "$@"`, then print Nix-managed message on top | |
| Append entry in bash | Wrapper appends entry via sed, does NOT call real mise for `use` | ✓ |
| Skip write, instruct user | Print message telling user to edit mise.toml manually | |

**User's choice:** Append entry in bash
**Notes:** User raised that calling real `mise use` would trigger tool installs even with `MISE_NOT_FOUND_AUTO_INSTALL=false`, since that env var suppresses auto-installs but not the explicit install that `mise use` triggers. This ruled out the passthrough approach.

---

## Trigger Conditions

| Option | Description | Selected |
|--------|-------------|----------|
| All `mise use` — same behavior | Every `mise use` writes to mise.toml and prints the Nix-managed message | ✓ |
| Backend:tool only | Only intercept `backend:tool` forms; pass plain forms to real mise | |

**User's choice:** All `mise use` — same behavior
**Notes:** Uniform handling is simpler. Unknown backends still get written + messaged in phase 7; phase 8 adds interactive prompting on top.

---

## Wrapper Code Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Inline in lib/default.nix | `let miseWrapper = pkgs.writeShellScriptBin ...` binding in default.nix | ✓ |
| New lib/wrapper.nix file | Separate file following runtimes.nix / env.nix pattern | |

**User's choice:** Inline in lib/default.nix
**Notes:** Wrapper is tightly coupled to devShell assembly; no reason to split it out.

---

## Claude's Discretion

- Exact wording of the DX-05 reload message
- Whether to detect `DIRENV_DIR` and suggest `direnv reload` vs `nix develop`

## Deferred Ideas

None.
