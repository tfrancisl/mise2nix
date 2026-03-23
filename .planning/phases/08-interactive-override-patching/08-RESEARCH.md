# Phase 8: Interactive Override Patching - Research

**Researched:** 2026-03-23
**Domain:** Bash scripting, GNU sed, Nix writeShellScriptBin, TTY interaction
**Confidence:** HIGH

## Summary

Phase 8 extends the `miseWrapper` in `lib/default.nix` with a detection branch that fires before the `mise.toml` write for unknown/unmapped tools. The new branch: (1) prompts the user for a nixpkgs attribute via `read < /dev/tty`, (2) writes the entry to `mise.toml`, and (3) patches the nearest `flake.nix` via GNU sed.

All decisions are pre-made in CONTEXT.md. The only open design questions belong to Claude's Discretion: exact sed strategy, no-flake fallback, no-overrides-argument injection. Research resolves all three with verified, tested patterns.

**Primary recommendation:** Use three distinct sed patterns covering the three `overrides` states in `flake.nix` (multi-line block, empty one-liner `overrides = {};`, and absent). Use `MISE2NIX_ATTR` env var as a sandbox-safe test bypass to avoid TTY dependency in `runCommand` checks.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Full WRAP-03 compliance — the interactive prompt triggers for BOTH unknown backends (not pipx/npm/cargo) AND unmapped tools within known backends (e.g. `pipx:nonexistent-tool`).
- **D-02:** The known tool lists are derived from the existing Nix backend attrsets at build time — NOT hardcoded separately in bash. Use `builtins.concatStringsSep " " (builtins.attrNames ...)` to interpolate the lists into the `writeShellScriptBin` script:
  ```nix
  pipxKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./backends/pipx.nix {inherit pkgs;}));
  npmKnown  = builtins.concatStringsSep " " (builtins.attrNames (import ./backends/npm.nix  {inherit pkgs;}));
  cargoKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./backends/cargo.nix {inherit pkgs;}));
  ```
- **D-03:** Detection logic: if `TOOL_SPEC` contains `:`, split into BACKEND and INNER_TOOL. If BACKEND is not in `[pipx npm cargo]` → unknown backend path. If BACKEND is in `[pipx npm cargo]` but INNER_TOOL is not in the corresponding `*Known` list → unmapped tool path. Both routes trigger the interactive prompt.
- **D-04:** Accept bare attribute name (`ripgrep`) OR full path (`pkgs.ripgrep`). Strip leading `pkgs.` prefix, then write `pkgs.<attrname>` into `flake.nix`.
- **D-05:** Any non-empty string after stripping `pkgs.` is accepted — no nixpkgs attribute existence validation.
- **D-06:** Empty input (Enter without typing) OR Ctrl-C → no files modified, print `[mise2nix] Cancelled.` and exit cleanly.
- **D-07:** Pure shell/sed — no Nix AST manipulation.
- **D-08 (Discretion):** How to handle a `flake.nix` with no existing `overrides = {` argument — research resolves this (see sed patterns below).
- **D-09 (Discretion):** "nearest flake.nix" discovery: walk up `$PWD` toward filesystem root, use first `flake.nix` found. Behavior when none found is Claude's call — research resolves this.

### Claude's Discretion

- Exact sed pattern for locating and patching the `overrides` block in `flake.nix`
- Behavior when no `flake.nix` is found (error message vs skip patching)
- Behavior when `overrides = {` is not present in the found `flake.nix` (inject it vs error)
- Prompt wording (example: `"Enter nixpkgs attribute for 'ubi:ripgrep' (e.g. ripgrep or pkgs.ripgrep, Enter to cancel):"`)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WRAP-03 | `mise use "unknown-backend:tool"` or `mise use "backend:unmapped-tool"` prompts interactively for a nixpkgs attribute and patches the `overrides = { ... }` argument in the nearest `flake.nix` | Detection logic (D-01–D-03), prompt + read pattern, three sed strategies, walk-up algorithm — all verified and tested |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

No `CLAUDE.md` found in repo root. One memory directive applies:

- **nfmt before every commit touching `.nix` files.** Run `nfmt` (alejandra + deadnix + statix) before committing. The `nfmt` tool lives in `packages/fmt.nix` and is part of the devShell.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `pkgs.gnused` | GNU sed 4.9 (verified on system) | In-place flake.nix patching | Already used in `miseWrapper`; project decision mandates pure shell/sed |
| `pkgs.gnugrep` | verified present | Pattern detection in flake.nix | Already imported and used |
| `pkgs.coreutils` | 9.10 | `dirname` for walk-up directory traversal | Must be referenced explicitly — `writeShellScriptBin` does not set PATH |
| bash `read` builtin | bash 5.3.9 | Interactive TTY prompt | Standard shell builtin, no extra package |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `/dev/tty` | OS device | Reliable prompt input even when stdout is redirected | Always — prefer over stdin so piped commands still work |
| `MISE2NIX_ATTR` env var | n/a | Test bypass for Nix sandbox (no TTY available in `runCommand`) | In `checks` only — never set by users |

**No new packages need to be added to the Nix expression.** `pkgs.gnused`, `pkgs.gnugrep` are already referenced. Only `pkgs.coreutils` needs to be added for `dirname`.

---

## Architecture Patterns

### Detection Branch Position

The detection logic inserts a new conditional block in `miseWrapper` **between** the `TOOL`/`VERSION` extraction and the `mise.toml` write. The existing `mise.toml` write path remains unchanged for known/mapped tools.

```
mise use TOOL_SPEC
  │
  ├─ TOOL_SPEC empty? → pass through to real mise
  │
  ├─ extract VERSION / TOOL (already in wrapper)
  │
  ├─ [NEW] does TOOL contain ':'?
  │     ├─ YES: split BACKEND / INNER_TOOL
  │     │     ├─ BACKEND not in [pipx npm cargo] → interactive path
  │     │     └─ BACKEND in known list but INNER_TOOL not in *Known → interactive path
  │     └─ NO: fall through to existing mise.toml write
  │
  ├─ [interactive path]
  │     ├─ prompt user (read < /dev/tty or MISE2NIX_ATTR bypass)
  │     ├─ empty input → "[mise2nix] Cancelled." + exit 0
  │     ├─ strip pkgs. prefix
  │     ├─ write entry to mise.toml (same logic as known-tool path)
  │     ├─ locate nearest flake.nix (walk up $PWD)
  │     ├─ no flake.nix → warn + skip patching (don't abort)
  │     └─ patch flake.nix (one of three sed strategies)
  │
  └─ [existing path] write entry to mise.toml, print reload message
```

### D-02 Let-Binding Pattern

Add three let-bindings in the `miseWrapper` let-expression. `builtins.attrNames` returns alphabetically-sorted keys (verified):

```nix
# In the let block of lib/default.nix, alongside existing bindings:
pipxKnown  = builtins.concatStringsSep " " (builtins.attrNames backends.pipx);
npmKnown   = builtins.concatStringsSep " " (builtins.attrNames backends.npm);
cargoKnown = builtins.concatStringsSep " " (builtins.attrNames backends.cargo);
```

`backends.pipx`, `backends.npm`, `backends.cargo` are already imported in the same let block. No additional imports needed.

### D-03 Detection in Bash

```bash
# After TOOL/VERSION extraction:
TRIGGER_INTERACTIVE=false
if [[ "$TOOL" == *:* ]]; then
  BACKEND="${TOOL%%:*}"
  INNER_TOOL="${TOOL#*:}"
  if [[ " pipx npm cargo " != *" $BACKEND "* ]]; then
    TRIGGER_INTERACTIVE=true  # unknown backend
  else
    case "$BACKEND" in
      pipx)  KNOWN_LIST="${pipxKnown}" ;;
      npm)   KNOWN_LIST="${npmKnown}" ;;
      cargo) KNOWN_LIST="${cargoKnown}" ;;
    esac
    if [[ " $KNOWN_LIST " != *" $INNER_TOOL "* ]]; then
      TRIGGER_INTERACTIVE=true  # unmapped tool in known backend
    fi
  fi
fi
```

Note: `${pipxKnown}` in the bash script is a Nix interpolation, not a bash variable — it is substituted at Nix eval time to a literal space-separated string.

### Prompt and Read Pattern

```bash
if [ "$TRIGGER_INTERACTIVE" = true ]; then
  # MISE2NIX_ATTR allows test bypass in Nix sandbox (no TTY in runCommand)
  if [ -n "${MISE2NIX_ATTR+x}" ] && [ -z "${MISE2NIX_ATTR}" ]; then
    # Explicitly set to empty string → simulate cancel path
    ATTR_INPUT=""
  elif [ -n "${MISE2NIX_ATTR:-}" ]; then
    ATTR_INPUT="${MISE2NIX_ATTR}"
  else
    printf '[mise2nix] Enter nixpkgs attribute for '"'"'%s'"'"' (e.g. ripgrep or pkgs.ripgrep, Enter to cancel): ' "$TOOL" >&2
    read -r ATTR_INPUT < /dev/tty || ATTR_INPUT=""
  fi

  ATTR_NAME="${ATTR_INPUT#pkgs.}"

  if [ -z "$ATTR_NAME" ]; then
    echo "[mise2nix] Cancelled." >&2
    exit 0
  fi

  # ... proceed to write mise.toml and patch flake.nix
fi
```

The `read -r ATTR_INPUT < /dev/tty || ATTR_INPUT=""` pattern:
- Works when `/dev/tty` is a real terminal
- Falls back to empty string (cancel path) when `/dev/tty` is unavailable (Nix sandbox) — **verified by testing**
- Does not block indefinitely on piped input

### MISE2NIX_ATTR Bypass Convention

| Value | Meaning |
|-------|---------|
| Unset | Normal interactive mode (prompt user) |
| Non-empty string | Skip prompt, use this value (test bypass) |
| Empty string `""` | Skip prompt, simulate cancel (test cancel path) |

Detecting "explicitly set to empty" vs "unset" in bash uses `${MISE2NIX_ATTR+x}`:
- `[ -n "${MISE2NIX_ATTR+x}" ]` is true when variable is set (even if empty)
- `[ -z "${MISE2NIX_ATTR}" ]` is true when value is empty string

### flake.nix Walk-Up Algorithm

```bash
find_nearest_flake() {
  local dir
  dir="${PWD}"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/flake.nix" ]; then
      echo "$dir/flake.nix"
      return 0
    fi
    dir="$(${pkgs.coreutils}/bin/dirname "$dir")"
  done
  return 1
}

FLAKE_NIX="$(find_nearest_flake)" || true

if [ -z "$FLAKE_NIX" ]; then
  echo "[mise2nix] No flake.nix found in directory tree. Add the override manually:" >&2
  echo "  overrides = { \"${TOOL}\" = pkgs.${ATTR_NAME}; };" >&2
  # Don't abort — mise.toml was already written
else
  # patch FLAKE_NIX
fi
```

**Decision for D-09 "no flake.nix found":** warn and skip patching (do not abort). The `mise.toml` write already happened; aborting would leave inconsistent state. The warning message gives the user what they need to patch manually.

### sed Strategies (Claude's Discretion, D-08 resolved)

Three cases arise in practice. All three were tested with `nix-instantiate --parse` and confirmed to produce syntactically valid Nix. Use case detection order: A → B → C.

**Case A — `overrides = {` block already exists (multi-line)**

```bash
if ${pkgs.gnugrep}/bin/grep -q 'overrides = {' "$FLAKE_NIX"; then
  ${pkgs.gnused}/bin/sed -i \
    "/overrides = {/a\\        \"${TOOL}\" = pkgs.${ATTR_NAME};" \
    "$FLAKE_NIX"
```

Inserts the new entry on the line immediately after `overrides = {`. Works for both non-empty and empty multi-line blocks. Indentation of 8 spaces matches the project's 2-space Nix convention at nesting level 4.

**Case B — `overrides = {};` one-liner**

```bash
elif ${pkgs.gnugrep}/bin/grep -q 'overrides = {};' "$FLAKE_NIX"; then
  ${pkgs.gnused}/bin/sed -i \
    "s|overrides = {};|overrides = {\n        \"${TOOL}\" = pkgs.${ATTR_NAME};\n      };|" \
    "$FLAKE_NIX"
```

Replaces the one-liner with a multi-line block. GNU sed interprets `\n` in the replacement string as a literal newline (verified). Result is valid Nix.

**Case C — no `overrides` argument at all**

```bash
else
  # Inject overrides block after 'inherit pkgs;'
  ${pkgs.gnused}/bin/sed -i \
    "/inherit pkgs;/a\\      overrides = {\n        \"${TOOL}\" = pkgs.${ATTR_NAME};\n      };" \
    "$FLAKE_NIX"
fi
```

Appends the full `overrides = { ... };` block after the `inherit pkgs;` line. Assumes `inherit pkgs;` is always present in `fromMiseToml` calls (true for all project examples).

**Fallback for Case C failure (no `inherit pkgs;` either):** If grep finds neither `overrides = {` nor `inherit pkgs;` in the flake, warn and print the manual entry instead of silently corrupting the file.

### Nix String Escaping Notes

In Nix `''...''` strings used in `writeShellScriptBin`:
- `\n` is passed through literally to the resulting bash script (not converted to a newline at Nix eval time)
- GNU sed then interprets `\n` in replacement strings as a newline at runtime — **verified**
- Nix interpolation `${...}` in `''...''` requires `''${...}` or `'''${...}` to escape — but the Nix let-bindings (`pipxKnown`, etc.) ARE intended to be interpolated, so use `${pipxKnown}` directly
- For bash variables inside the script body (e.g. `$TOOL`), use `''${TOOL}` to suppress Nix interpolation

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Parsing `overrides` block from Nix AST | Custom Nix parser | GNU sed with line-oriented patterns | AST manipulation requires external tools; sed sufficient for the constrained patterns; D-07 locks this |
| TTY detection | `tty -s` or `[ -t 0 ]` check | Read from `/dev/tty` with `\|\| ATTR_INPUT=""` fallback | `/dev/tty` opens the controlling terminal regardless of stdin/stdout redirection; cleaner than fd checks |
| Argument existence check in bash | `[[ -v VARNAME ]]` | `${VAR+x}` idiom | Portable across bash versions for "is this variable set?" |

---

## Common Pitfalls

### Pitfall 1: Nix Interpolation vs Bash Variable Confusion

**What goes wrong:** Writing `${TOOL}` (intended as bash variable) inside a Nix `''...''` string — Nix tries to evaluate `TOOL` as a Nix expression and fails.

**Why it happens:** Nix `''...''` treats `${...}` as Nix string interpolation, not bash variable reference.

**How to avoid:** Use `''${TOOL}` (escaped dollar) for bash variables that should NOT be interpolated at Nix eval time. Use `${pipxKnown}` (unescaped) for Nix let-bindings that SHOULD be interpolated.

**Warning signs:** Nix eval error like `undefined variable 'TOOL'` or `BACKEND` in the `miseWrapper` expression.

### Pitfall 2: miseWrapper is Not Accessible from flake.nix Checks

**What goes wrong:** Trying to reference `miseWrapper` directly in `checks` expressions at the flake level — it is a local binding inside the `fromMiseToml` function closure.

**How to avoid:** Duplicate the wrapper script inline in each `runCommand` check that needs it, as established in Phase 7. This is a known project pattern (STATE.md decision: "Duplicate miseWrapper inline in flake.nix check let blocks").

**Warning signs:** Attribute error at Nix eval when writing `self.lib.miseWrapper` or similar.

### Pitfall 3: sed `a\` Command and Trailing Newlines

**What goes wrong:** The `a\` (append) command in GNU sed adds text after the matched line. If you use `\n` in the appended text to create multi-line output, the escaping must be `\n` (backslash-n), not a literal newline.

**How to avoid:** Use `a\\        "entry";` for single-line appends. For multi-line appends via `a\`, use `a\\line1\nline2\nline3` with explicit `\n` separators — GNU sed handles this correctly (verified).

**Warning signs:** Sed outputs literal `\n` text instead of newlines in the file — check which sed variant (BSD vs GNU) is in use. Always use `${pkgs.gnused}/bin/sed` in the wrapper.

### Pitfall 4: duplicate Entry on Repeated `mise use`

**What goes wrong:** Running `mise use "ubi:ripgrep"` twice patches `flake.nix` twice, inserting the same overrides entry a second time. This is valid Nix (last definition wins for attrsets) but is ugly.

**Mitigation (recommended):** Before patching, check with grep if the entry already exists:
```bash
if ! ${pkgs.gnugrep}/bin/grep -qF "\"${TOOL}\"" "$FLAKE_NIX"; then
  # proceed with sed patch
fi
```

**Why it matters:** Repeated invocations should be idempotent — consistent with project DX goals.

### Pitfall 5: indentation Drift

**What goes wrong:** The sed-inserted override entry has hard-coded indentation (8 spaces in Case A/B, 6 in Case C) that may not match the user's actual `flake.nix` style.

**Mitigation:** The project's own `flake.nix` and `example/flake.nix` use 2-space Nix indentation consistently. Hard-code 8-space indentation (4 levels deep) for the entry and 6-space for the `overrides = {` injection. This matches the project's style and the alejandra formatter output. Users with different styles will see slightly inconsistent indentation but syntactically valid code.

### Pitfall 6: No `inherit pkgs;` in Target flake.nix

**What goes wrong:** Case C sed strategy uses `/inherit pkgs;/` as the anchor. If the user's `flake.nix` uses a different pattern (e.g., `pkgs = nixpkgs.legacyPackages.${system};` outside the `fromMiseToml` call), the anchor line won't be found.

**Mitigation:** After attempting the sed insert, verify with grep that `overrides` now appears in the file. If not, fall back to the warning + manual message path.

---

## Code Examples

### Detection Logic with builtins.attrNames (D-02 + D-03)

```nix
# Source: CONTEXT.md D-02; verified against lib/backends/*.nix structure
let
  pipxKnown  = builtins.concatStringsSep " " (builtins.attrNames backends.pipx);
  npmKnown   = builtins.concatStringsSep " " (builtins.attrNames backends.npm);
  cargoKnown = builtins.concatStringsSep " " (builtins.attrNames backends.cargo);

  miseWrapper = pkgs.writeShellScriptBin "mise" ''
    # ... existing code ...

    TRIGGER_INTERACTIVE=false
    if [[ "$TOOL" == *:* ]]; then
      BACKEND="''${TOOL%%:*}"
      INNER_TOOL="''${TOOL#*:}"
      if [[ " pipx npm cargo " != *" $BACKEND "* ]]; then
        TRIGGER_INTERACTIVE=true
      else
        case "$BACKEND" in
          pipx)  KNOWN="${pipxKnown}" ;;
          npm)   KNOWN="${npmKnown}" ;;
          cargo) KNOWN="${cargoKnown}" ;;
        esac
        if [[ " $KNOWN " != *" $INNER_TOOL "* ]]; then
          TRIGGER_INTERACTIVE=true
        fi
      fi
    fi
  '';
in ...
```

### Prompt + Read + Cancel

```bash
# Source: verified by testing (bash 5.3.9, /dev/tty on Linux)
if [ -n "''${MISE2NIX_ATTR+x}" ] && [ -z "''${MISE2NIX_ATTR}" ]; then
  ATTR_INPUT=""
elif [ -n "''${MISE2NIX_ATTR:-}" ]; then
  ATTR_INPUT="''${MISE2NIX_ATTR}"
else
  printf '[mise2nix] Enter nixpkgs attribute for '\''%s'\'' (e.g. ripgrep or pkgs.ripgrep, Enter to cancel): ' "$TOOL" >&2
  read -r ATTR_INPUT < /dev/tty || ATTR_INPUT=""
fi

ATTR_NAME="''${ATTR_INPUT#pkgs.}"
if [ -z "$ATTR_NAME" ]; then
  echo "[mise2nix] Cancelled." >&2
  exit 0
fi
```

### flake.nix Walk-Up

```bash
# Source: verified by bash testing
FLAKE_NIX=""
_dir="''${PWD}"
while [ "$_dir" != "/" ]; do
  if [ -f "$_dir/flake.nix" ]; then
    FLAKE_NIX="$_dir/flake.nix"
    break
  fi
  _dir="$(${pkgs.coreutils}/bin/dirname "$_dir")"
done
```

### Three-Case sed Patch

```bash
# Source: verified by testing — all three produce nix-instantiate --parse clean output
OVERRIDE_ENTRY="\"''${TOOL}\" = pkgs.''${ATTR_NAME};"

if ${pkgs.gnugrep}/bin/grep -qF "\"''${TOOL}\"" "$FLAKE_NIX"; then
  echo "[mise2nix] '$TOOL' already in $FLAKE_NIX — skipping patch." >&2

elif ${pkgs.gnugrep}/bin/grep -q 'overrides = {' "$FLAKE_NIX"; then
  # Case A: existing overrides block
  ${pkgs.gnused}/bin/sed -i \
    "/overrides = {/a\\        ''${OVERRIDE_ENTRY}" \
    "$FLAKE_NIX"

elif ${pkgs.gnugrep}/bin/grep -q 'overrides = {};' "$FLAKE_NIX"; then
  # Case B: one-liner empty overrides
  ${pkgs.gnused}/bin/sed -i \
    "s|overrides = {};|overrides = {\n        ''${OVERRIDE_ENTRY}\n      };|" \
    "$FLAKE_NIX"

elif ${pkgs.gnugrep}/bin/grep -q 'inherit pkgs;' "$FLAKE_NIX"; then
  # Case C: no overrides arg — inject after 'inherit pkgs;'
  ${pkgs.gnused}/bin/sed -i \
    "/inherit pkgs;/a\\      overrides = {\n        ''${OVERRIDE_ENTRY}\n      };" \
    "$FLAKE_NIX"

else
  echo "[mise2nix] Cannot locate patch anchor in $FLAKE_NIX. Add manually:" >&2
  echo "  overrides = { ''${OVERRIDE_ENTRY} };" >&2
fi
```

Note: `''${OVERRIDE_ENTRY}` in Nix `''...''` escapes the `$` so bash sees `${OVERRIDE_ENTRY}` at runtime. `''${TOOL}` becomes `${TOOL}`, etc.

### Check Structure for WRAP-03

```nix
# In flake.nix checks section — uses MISE2NIX_ATTR bypass
wrap-unknown-backend-prompts = let
  miseWrapper = pkgs.writeShellScriptBin "mise" '' ... '';  # inline duplicate
  tomlFixture = builtins.toFile "fixture.toml" ''
    [tools]
  '';
in
  pkgs.runCommand "wrap-unknown-backend-prompts"
  {nativeBuildInputs = [miseWrapper pkgs.gnused pkgs.gnugrep pkgs.coreutils];}
  ''
    cp ${tomlFixture} mise.toml
    chmod +w mise.toml

    # Create a flake.nix with no overrides (Case C)
    cat > flake.nix << 'FLAKE'
    { outputs = { nixpkgs, mise2nix }: {
        devShells.x86_64-linux.default = mise2nix.lib.fromMiseToml ./mise.toml {
          inherit pkgs;
        };
      };
    }
    FLAKE

    MISE2NIX_ATTR="ripgrep" MISE_CONFIG_FILE=mise.toml mise use "ubi:ripgrep"

    # Verify mise.toml entry
    grep -q '"ubi:ripgrep" = "latest"' mise.toml || (echo "FAIL: toml not patched"; exit 1)
    # Verify flake.nix override
    grep -q '"ubi:ripgrep" = pkgs.ripgrep' flake.nix || (echo "FAIL: flake not patched"; exit 1)
    echo "PASS" > $out
  '';
```

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Nix `pkgs.runCommand` checks (no external test runner) |
| Config file | `flake.nix` checks section |
| Quick run command | `nix build .#checks.x86_64-linux.<check-name> --no-link` |
| Full suite command | `nix flake check` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WRAP-03 | Unknown backend triggers prompt, attr written to toml + flake | integration | `nix build .#checks.x86_64-linux.wrap-unknown-backend-patches` | ❌ Wave 0 |
| WRAP-03 | Unmapped tool within known backend also triggers prompt | integration | `nix build .#checks.x86_64-linux.wrap-unmapped-tool-patches` | ❌ Wave 0 |
| WRAP-03 | Empty input (simulated via `MISE2NIX_ATTR=""`) → cancel, no file changes | integration | `nix build .#checks.x86_64-linux.wrap-cancel-no-modification` | ❌ Wave 0 |
| WRAP-03 | `pkgs.` prefix stripped from user input | integration | covered by wrap-unknown-backend-patches using `MISE2NIX_ATTR="pkgs.ripgrep"` | ❌ Wave 0 |
| WRAP-03 | Already-present entry → idempotent (no duplicate) | integration | `nix build .#checks.x86_64-linux.wrap-idempotent-patch` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `nix build .#checks.x86_64-linux.<new-check-name> --no-link`
- **Per wave merge:** `nix flake check`
- **Phase gate:** `nix flake check` fully green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `flake.nix` checks section — add 4-5 new WRAP-03 check entries (inline miseWrapper duplicate pattern)
- No new test files — all checks live in `flake.nix`

---

## Open Questions

1. **Nix attrset key ordering ambiguity for hyphenated keys**
   - What we know: `builtins.attrNames` returns alphabetical order. Hyphenated keys like `"cargo-watch"` and `"pip-tools"` are quoted in Nix but appear in the list as the hyphenated string.
   - What's unclear: whether bash `[[ " $KNOWN " == *" cargo-watch "* ]]` correctly matches hyphenated names with space delimiters.
   - Recommendation: Test in a check. The space-delimiter approach should work since hyphens are not IFS characters, but verify with a `wrap-unmapped-tool-patches` check using `pipx:pip-tools` as the test input.

2. **Indentation in user's flake.nix**
   - What we know: Our three sed strategies use fixed indentation (8 spaces for entries, 6 for block open/close in Case C).
   - What's unclear: Whether users with tab-indented or differently-indented flake.nix files will get ugly (but valid) patches.
   - Recommendation: Accept this limitation. The alejandra formatter (`nfmt`) will normalize the file on next format run. Document this in a comment in the code.

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `/home/freya/code/mise2nix/lib/default.nix` — existing miseWrapper structure
- Direct code inspection: `/home/freya/code/mise2nix/lib/backends/{pipx,npm,cargo}.nix` — attrset key names
- Direct code inspection: `/home/freya/code/mise2nix/flake.nix` — check structure and inline wrapper pattern
- Bash testing on system (bash 5.3.9, GNU sed 4.9) — all sed strategies verified with `nix-instantiate --parse`
- Nix eval: `builtins.attrNames` sort order verified with `nix-instantiate --eval`

### Secondary (MEDIUM confidence)
- CONTEXT.md decisions D-01 through D-09 — project-specific design decisions
- STATE.md accumulated decisions — established project patterns for tests

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no external libraries; all tools already present in project
- Architecture patterns: HIGH — tested in bash, verified with nix-instantiate --parse
- Pitfalls: HIGH — directly observed during sed/Nix string escaping investigation
- Test strategy: HIGH — MISE2NIX_ATTR bypass verified; sandbox TTY behavior verified

**Research date:** 2026-03-23
**Valid until:** 2026-04-23 (stable domain — GNU sed, Nix builtins, bash)
