# Phase 8: Interactive Override Patching - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the `miseWrapper` in `lib/default.nix` to detect unknown backends (e.g. `ubi:`, `gh:`) and unmapped tools within known backends (e.g. `pipx:nonexistent`), then:
1. Prompt the user interactively for a nixpkgs attribute
2. Write the tool entry to `mise.toml` (same as phase 7 path)
3. Patch the `overrides = { ... }` argument in the nearest `flake.nix`

Abort cleanly (no file modification) on Ctrl-C or empty input.

Phase 7 `mise use` handling (write to `mise.toml` + message) is unchanged for known/mapped tools.

</domain>

<decisions>
## Implementation Decisions

### Detection Scope

- **D-01:** Full WRAP-03 compliance — the interactive prompt triggers for BOTH unknown backends (not pipx/npm/cargo) AND unmapped tools within known backends (e.g. `pipx:nonexistent-tool`).
- **D-02:** The known tool lists are derived from the existing Nix backend attrsets at build time — NOT hardcoded separately in bash. Use `builtins.concatStringsSep " " (builtins.attrNames ...)` to interpolate the lists into the `writeShellScriptBin` script:
  ```nix
  pipxKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./backends/pipx.nix {inherit pkgs;}));
  npmKnown  = builtins.concatStringsSep " " (builtins.attrNames (import ./backends/npm.nix  {inherit pkgs;}));
  cargoKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./backends/cargo.nix {inherit pkgs;}));
  ```
  This keeps the bash lists perfectly in sync with the Nix tables with zero duplication.
- **D-03:** Detection logic in bash: if `TOOL_SPEC` contains `:`, split into BACKEND and TOOL. If BACKEND is not in `[pipx npm cargo]` → unknown backend path. If BACKEND is in `[pipx npm cargo]` but TOOL is not in the corresponding `*Known` list → unmapped tool path. Both routes trigger the interactive prompt.

### Input Validation

- **D-04:** Accept bare attribute name (`ripgrep`) OR full path (`pkgs.ripgrep`). Wrapper strips a leading `pkgs.` prefix if present, then writes `pkgs.<attrname>` into `flake.nix`. Example: user types `ripgrep` or `pkgs.ripgrep` → both produce `"ubi:ripgrep" = pkgs.ripgrep;` in the overrides block.
- **D-05:** Any non-empty string after stripping `pkgs.` is accepted. The wrapper does not further validate that the attribute exists in nixpkgs — that's caught at Nix eval time.

### Abort Behavior (from WRAP-03, locked)

- **D-06:** Empty input (user presses Enter without typing) OR Ctrl-C → no files modified, print `[mise2nix] Cancelled.` and exit cleanly.

### flake.nix Patching

- **D-07:** Pure shell/sed — no Nix AST manipulation (carried from STATE.md decision).
- **D-08:** Claude's Discretion — how to handle the case where the nearest `flake.nix` has no existing `overrides = {` argument in its `fromMiseToml` call (inject fresh arg vs error out vs append comment). The planner/executor should pick the most robust approach given the sed constraint.
- **D-09:** Claude's Discretion — "nearest flake.nix" discovery: walk up `$PWD` toward filesystem root, use first `flake.nix` found. Behavior when none found is Claude's call.

### Claude's Discretion

- Exact sed pattern for locating and patching the `overrides` block in `flake.nix`
- Behavior when no `flake.nix` is found (error message vs skip patching)
- Behavior when `overrides = {` is not present in the found `flake.nix` (inject it vs error)
- Prompt wording (example from discussion: `"Enter nixpkgs attribute for 'ubi:ripgrep' (e.g. ripgrep or pkgs.ripgrep, Enter to cancel):"`)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing implementation (MUST read before modifying)
- `lib/default.nix` — current `miseWrapper` let-binding (lines 82–129); D-02 derivations go here
- `lib/backends/pipx.nix` — source of pipx tool names for `builtins.attrNames`
- `lib/backends/npm.nix` — source of npm tool names for `builtins.attrNames`
- `lib/backends/cargo.nix` — source of cargo tool names for `builtins.attrNames`

### Requirements
- `.planning/REQUIREMENTS.md` — WRAP-03 is the single active requirement for this phase

No external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `miseWrapper` let-binding in `lib/default.nix`: already parses `TOOL_SPEC`, handles `tool@version`, writes to `mise.toml`, detects `DIRENV_DIR` — phase 8 adds a conditional branch before the `mise.toml` write
- `${pkgs.gnused}/bin/sed`, `${pkgs.gnugrep}/bin/grep`: already in scope and used in miseWrapper — available for flake.nix patching
- `backends.pipx`, `backends.npm`, `backends.cargo` attrsets: already imported in the `let` block — `builtins.attrNames` on these gives the known tool lists

### Established Patterns
- Nix store paths for tools: `${pkgs.gnused}/bin/sed`, `${pkgs.coreutils}/bin/...` — mandatory since `writeShellScriptBin` doesn't add runtimeInputs to PATH
- Existing `writeShellScriptBin` uses `builtins.concatStringsSep` for list construction — same pattern for pipxKnown/npmKnown/cargoKnown

### Integration Points
- `lib/default.nix` `let` block: add `pipxKnown`, `npmKnown`, `cargoKnown` bindings; extend `miseWrapper` script with detection branch
- `flake.nix` checks: add check for the interactive prompt path (likely needs a fake TTY or non-interactive fallback for sandbox testing)

</code_context>

<specifics>
## Specific Ideas

- D-02 is the key insight from discussion: derive known-tool lists from `builtins.attrNames` on the existing backend attrsets, interpolated into the bash script at Nix eval time. This ensures zero drift between Nix tables and bash detection.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 08-interactive-override-patching*
*Context gathered: 2026-03-23*
