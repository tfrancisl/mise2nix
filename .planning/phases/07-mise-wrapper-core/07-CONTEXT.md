# Phase 7: Mise Wrapper Core - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a `pkgs.writeShellScriptBin "mise"` wrapper that replaces bare `pkgs.mise` in the devShell packages list. The wrapper intercepts all `mise use` subcommand invocations, writes the requested tool entry to `mise.toml` via shell (without calling the real mise binary for `use`), and prints a Nix-managed reload message. All non-`use` subcommands are passed through to the real mise binary unchanged via `exec`.

Phase 8 scope (interactive override patching for unknown backends) is NOT included here.

</domain>

<decisions>
## Implementation Decisions

### mise use Passthrough Strategy

- **D-01:** The wrapper does NOT call the real `mise use` for `use` subcommands. Calling the real `mise use` would trigger tool installs — `MISE_NOT_FOUND_AUTO_INSTALL=false` blocks auto-installs but does not suppress the explicit install that `mise use` triggers. The wrapper handles `use` entirely in bash.
- **D-02:** The wrapper appends `"tool" = "version"` to the `[tools]` section of `mise.toml` using sed. The approach is: `sed -i '/^\[tools\]/a "tool" = "version"' mise.toml`. Duplicate lines if the user runs `mise use` twice are acceptable — mise.toml is human-editable.
- **D-03:** For all non-`use` subcommands: `exec ${pkgs.mise}/bin/mise "$@"` — real mise binary, arguments verbatim, no overhead.

### Trigger Conditions

- **D-04:** All `mise use` invocations receive the same treatment — write entry to mise.toml, print Nix-managed message. No distinction between backend:tool forms, plain tool forms (`node@22`), or unknown backends. Unknown backend handling (interactive prompting) is phase 8's responsibility.

### Wrapper Code Organization

- **D-05:** The wrapper is an inline `let`-binding in `lib/default.nix`:
  ```nix
  miseWrapper = pkgs.writeShellScriptBin "mise" ''...'';
  ```
  Replaces `pkgs.mise` in the `packages` list: `packages = [miseWrapper] ++ resolvedPackages ++ extraPackages`.
  No new file needed — the wrapper is tightly coupled to devShell assembly.

### Claude's Discretion

- Exact wording of the reload message (DX-05 requires it attributes the message to mise2nix and explains the action; exact phrasing is Claude's call)
- Whether to detect if `DIRENV_DIR` is set and suggest `direnv reload` vs `nix develop` accordingly — nice DX but not required

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements
- `.planning/REQUIREMENTS.md` — WRAP-01, WRAP-02, DX-05, DX-06 are the active requirements for this phase

### Existing implementation
- `lib/default.nix` — current `fromMiseToml` implementation; wrapper replaces `pkgs.mise` in packages list here
- `flake.nix` — existing check patterns; new checks for wrapper behavior go here

No external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `pkgs.writeShellScriptBin`: available in scope inside `fromMiseToml` via the `pkgs` argument — no new imports needed
- `${pkgs.mise}/bin/mise`: Nix store path for the real mise binary — used in `exec` passthrough and in the sed-based write logic is bash-only

### Established Patterns
- `packages = [pkgs.mise] ++ resolvedPackages ++ extraPackages` — existing line in `lib/default.nix`; swap `pkgs.mise` for `miseWrapper`
- `MISE_NOT_FOUND_AUTO_INSTALL = "false"` — already injected as a shell env var; wrapper does not need to re-set it

### Integration Points
- `lib/default.nix` `let` block — add `miseWrapper = pkgs.writeShellScriptBin ...` here
- `pkgs.mkShell { packages = ... }` — replace `pkgs.mise` with `miseWrapper`
- `flake.nix` `checks` — add wrapper behavior checks (non-use passthrough, use writes toml, message output)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for message wording and direnv detection.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 07-mise-wrapper-core*
*Context gathered: 2026-03-23*
