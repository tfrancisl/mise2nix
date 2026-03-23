# Phase 7: Mise Wrapper Core - Research

**Researched:** 2026-03-23
**Domain:** Nix shell script wrapping, bash argument parsing, TOML mutation via sed
**Confidence:** HIGH

## Summary

This phase delivers a `writeShellScriptBin "mise"` wrapper that intercepts `mise use` subcommands and passes everything else through to the real mise binary. The implementation is an inline `let`-binding in `lib/default.nix`. All decisions are already locked in CONTEXT.md — this research validates those decisions and identifies implementation specifics the planner needs.

The sed approach (`sed -i '/^\[tools\]/a "tool" = "version"' mise.toml`) works correctly for the common case. The critical cross-platform concern is that macOS BSD sed uses different `-i` syntax from GNU sed. The wrapper must use `${pkgs.gnused}/bin/sed` (a Nix store path) to guarantee GNU sed on all platforms, since `writeShellScriptBin` does not add runtimeInputs to PATH and the user's PATH at runtime may have BSD sed on macOS.

Testing wrapper behavior in Nix `checks` requires running the wrapper binary directly with `nativeBuildInputs`. The most practical approach is to define the wrapper derivation in the `checks` let block (duplicating the call) so it can be passed as a `nativeBuildInputs` dependency to `pkgs.runCommand` builders that exercise it.

**Primary recommendation:** Use `${pkgs.gnused}/bin/sed` and `${pkgs.grep}/bin/grep` as Nix store paths inside the wrapper script. Define a helper `mkMiseWrapper` function (or inline expression) that is also accessible in `flake.nix` checks.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** The wrapper does NOT call the real `mise use`. The wrapper handles `use` entirely in bash.
- **D-02:** The wrapper appends `"tool" = "version"` to the `[tools]` section of `mise.toml` using sed: `sed -i '/^\[tools\]/a "tool" = "version"' mise.toml`. Duplicate lines from repeated `mise use` are acceptable.
- **D-03:** For all non-`use` subcommands: `exec ${pkgs.mise}/bin/mise "$@"` — real mise binary, arguments verbatim, no overhead.
- **D-04:** All `mise use` invocations receive the same treatment — write entry to mise.toml, print Nix-managed message. No distinction between backend:tool forms, plain tool forms, or unknown backends.
- **D-05:** The wrapper is an inline `let`-binding in `lib/default.nix`: `miseWrapper = pkgs.writeShellScriptBin "mise" ''...'';`. Replaces `pkgs.mise` in packages list: `packages = [miseWrapper] ++ resolvedPackages ++ extraPackages`.

### Claude's Discretion

- Exact wording of the reload message (DX-05 requires it attributes the message to mise2nix and explains the action; exact phrasing is Claude's call)
- Whether to detect if `DIRENV_DIR` is set and suggest `direnv reload` vs `nix develop` accordingly — nice DX but not required

### Deferred Ideas (OUT OF SCOPE)

None.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WRAP-01 | The devShell includes a `mise` wrapper script (`writeShellScriptBin`) that intercepts `mise use` and passes all other subcommands to the real mise binary unchanged | `writeShellScriptBin` is available via `pkgs` in `lib/default.nix`; `exec ${pkgs.mise}/bin/mise "$@"` is the passthrough pattern |
| WRAP-02 | `mise use "known-backend:tool"` writes the entry to `mise.toml` and prints a clear message instructing the user to reload | sed append-after-`[tools]` verified working; message wording resolved in this research |
| DX-05 | Wrapper output explains clearly that tool resolution is Nix-managed and what action to take next | Message pattern documented in Code Examples section; DIRENV_DIR detection pattern documented |
| DX-06 | All non-`use` mise subcommands pass through to the real mise binary with no modification or overhead | `exec ${pkgs.mise}/bin/mise "$@"` provides zero-overhead passthrough; verified by wrapper script content check |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `pkgs.writeShellScriptBin` | nixpkgs built-in | Produces a derivation with `$out/bin/<name>` containing a bash script | Standard Nix pattern for wrapping binaries; already used via `pkgs` in scope |
| `pkgs.gnused` | nixpkgs built-in | GNU sed for cross-platform TOML mutation | BSD sed (macOS) uses different `-i` syntax; Nix store path guarantees GNU sed everywhere |
| `pkgs.grep` | nixpkgs built-in | Detecting `[tools]` section in mise.toml | Nix store path avoids PATH dependency at wrapper runtime |
| `pkgs.mise` | nixpkgs built-in | Real mise binary for passthrough | Already in scope; store path `${pkgs.mise}/bin/mise` used in `exec` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `writeShellScriptBin` | `writeShellApplication` | `writeShellApplication` adds runtimeInputs to PATH, enables strict mode, runs shellcheck — more correct but locked decision is `writeShellScriptBin`; mitigate by using Nix store paths for all external tools |
| `${pkgs.gnused}/bin/sed` | `sed` from PATH | PATH-based sed fails on macOS (BSD sed `-i` requires `sed -i ''`); store path is mandatory for cross-platform correctness |

**Installation:** No new packages — `pkgs.gnused` and `pkgs.grep` are standard nixpkgs, referenced by store path.

## Architecture Patterns

### Wrapper Structure in lib/default.nix

```nix
# Inside the fromMiseToml let block, before mkShell:
miseWrapper = pkgs.writeShellScriptBin "mise" ''
  if [ "$1" = "use" ]; then
    # ... handle use subcommand in bash
  else
    exec ${pkgs.mise}/bin/mise "$@"
  fi
'';
```

Then in `mkShell`:

```nix
packages = [miseWrapper] ++ resolvedPackages ++ extraPackages;
```

### Pattern 1: Non-use Passthrough (D-03, DX-06)

**What:** First argument check routes non-`use` subcommands directly to the real binary via `exec` (replaces wrapper process — zero overhead).
**When to use:** All subcommands except `use`.

```bash
# Source: verified via shell exec semantics
if [ "$1" != "use" ]; then
  exec ${pkgs.mise}/bin/mise "$@"
fi
```

### Pattern 2: TOML Write via sed (D-02)

**What:** Append `"tool" = "version"` line immediately after the `[tools]` header using GNU sed's `/a` command. If `[tools]` section is absent, append it.
**When to use:** Any `mise use` invocation.

```bash
# Source: manually verified with GNU sed 4.9 on Linux
# Tool spec extraction: first non-flag positional argument
TOOL_SPEC=""
for arg in "$@"; do
  case "$arg" in
    -*) ;;
    *) TOOL_SPEC="$arg"; break ;;
  esac
done

# Strip @version suffix: pipx:black@1.24.0 -> tool=pipx:black, ver=1.24.0
if [[ "$TOOL_SPEC" == *@* ]]; then
  VERSION="${TOOL_SPEC##*@}"
  TOOL="${TOOL_SPEC%@*}"
else
  VERSION="latest"
  TOOL="$TOOL_SPEC"
fi

TOML_FILE="${MISE_CONFIG_FILE:-mise.toml}"
ENTRY="\"${TOOL}\" = \"${VERSION}\""

if [ ! -f "$TOML_FILE" ]; then
  printf '[tools]\n%s\n' "$ENTRY" > "$TOML_FILE"
elif ${pkgs.grep}/bin/grep -q '^\[tools\]' "$TOML_FILE"; then
  ${pkgs.gnused}/bin/sed -i "/^\[tools\]/a ${ENTRY}" "$TOML_FILE"
else
  printf '\n[tools]\n%s\n' "$ENTRY" >> "$TOML_FILE"
fi
```

### Pattern 3: DX-05 Reload Message with Optional DIRENV_DIR Detection

**What:** Print a message attributing the behavior to mise2nix and telling the user what to do next.
**Note on DIRENV_DIR:** `DIRENV_DIR` is set by direnv to `-/path/to/project` (with a leading dash) when an `.envrc` is loaded. Presence of this variable reliably indicates the user is in a direnv-managed shell.

```bash
# Recommended message wording (attributing to mise2nix, explaining action):
if [ -n "${DIRENV_DIR:-}" ]; then
  RELOAD_CMD="direnv reload"
else
  RELOAD_CMD="nix develop"
fi

echo "[mise2nix] '${TOOL}' written to ${TOML_FILE}."
echo "[mise2nix] Tool resolution is Nix-managed. Run \`${RELOAD_CMD}\` to enter the updated shell."
```

### Anti-Patterns to Avoid

- **PATH-based `sed` or `grep`:** BSD sed on macOS uses `sed -i ''` syntax; `sed -i` without the empty string argument truncates the file. Always use `${pkgs.gnused}/bin/sed`.
- **Calling `${pkgs.mise}/bin/mise use`:** Triggers an explicit install even with `MISE_NOT_FOUND_AUTO_INSTALL=false`. Decision D-01 prohibits this.
- **`deepSeq` on `nativeBuildInputs` in checks:** Causes stack overflow (established project pattern from STATE.md). Use `builtins.seq devShell.drvPath null` for eval-level checks.
- **Testing wrapper as `nativeBuildInputs = [devShell]`:** `mkShell` is not a standard build derivation; pass the `miseWrapper` derivation directly to `nativeBuildInputs` instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-platform `sed -i` | Shell compat shim | `${pkgs.gnused}/bin/sed` | GNU sed Nix store path is available on all four platforms in `forAllSystems` |
| Bash script packaging | Custom build hook | `pkgs.writeShellScriptBin` | Standard nixpkgs primitive; produces correctly structured `$out/bin/<name>` with proper bash shebang |

**Key insight:** Any external tool used inside `writeShellScriptBin` should be referenced by its Nix store path, not by name, because the wrapper runs in the user's shell where PATH is unpredictable (especially on macOS with BSD tools).

## Common Pitfalls

### Pitfall 1: BSD sed on macOS
**What goes wrong:** `sed -i '/pattern/a text' file` truncates the file on macOS because BSD sed requires `sed -i '' '/pattern/a\\ text' file`.
**Why it happens:** `writeShellScriptBin` does not add anything to PATH; the wrapper runs in the user's login shell where `/usr/bin/sed` is BSD sed on macOS.
**How to avoid:** Use `${pkgs.gnused}/bin/sed` (absolute Nix store path) inside the wrapper script.
**Warning signs:** Tests pass on Linux but fail on macOS; `mise.toml` is empty after `mise use`.

### Pitfall 2: miseWrapper not accessible in flake.nix checks
**What goes wrong:** `miseWrapper` is a `let`-binding inside `fromMiseToml`, which is a function — the planner cannot access it directly from `flake.nix` checks.
**Why it happens:** The binding is local to the `fromMiseToml` closure.
**How to avoid:** In `flake.nix` checks that need to exercise the wrapper binary directly, define the wrapper inline in the check's `let` block: `miseWrapper = pkgs.writeShellScriptBin "mise" ''...''`. This duplicates the definition but keeps checks hermetic.
**Warning signs:** Check can't find a `miseWrapper` attribute; check tries to use `devShell` as a `nativeBuildInputs` entry.

### Pitfall 3: sed /a with no [tools] section
**What goes wrong:** If `mise.toml` has no `[tools]` section (e.g., `env`-only file), `sed '/^\[tools\]/a ...'` makes no change — the tool entry is silently dropped.
**Why it happens:** `sed /a` only fires when the pattern matches.
**How to avoid:** Check with `grep -q '^\[tools\]'` first; if absent, append `\n[tools]\n"tool" = "version"\n` to the file.
**Warning signs:** `mise use` appears to succeed but `mise.toml` has no `[tools]` section and no entry.

### Pitfall 4: Version in sed replacement getting misinterpreted
**What goes wrong:** If `VERSION` contains characters that sed interprets specially in the replacement string, the line written to `mise.toml` may be corrupted.
**Why it happens:** sed's `/a` appended text is not a regex pattern, but some shell expansions (backslashes, semicolons in GNU sed scripts) can cause issues.
**How to avoid:** Version strings in mise are typically `latest`, `x.y.z`, or `x` — no special characters. The current approach (CONTEXT.md D-02) is safe for all realistic mise version strings.

## Code Examples

### Full Wrapper Script (complete, verified approach)

```bash
# Source: composed from verified patterns above; embedded in writeShellScriptBin "mise"

if [ "$1" != "use" ]; then
  exec ${pkgs.mise}/bin/mise "$@"
fi

# Handle: mise use [flags] TOOL_SPEC
shift  # remove "use" from args

TOOL_SPEC=""
for arg in "$@"; do
  case "$arg" in
    -*) ;;
    *) TOOL_SPEC="$arg"; break ;;
  esac
done

if [ -z "$TOOL_SPEC" ]; then
  exec ${pkgs.mise}/bin/mise use "$@"
fi

if [[ "$TOOL_SPEC" == *@* ]]; then
  VERSION="${TOOL_SPEC##*@}"
  TOOL="${TOOL_SPEC%@*}"
else
  VERSION="latest"
  TOOL="$TOOL_SPEC"
fi

TOML_FILE="${MISE_CONFIG_FILE:-mise.toml}"
ENTRY="\"${TOOL}\" = \"${VERSION}\""

if [ ! -f "$TOML_FILE" ]; then
  printf '[tools]\n%s\n' "$ENTRY" > "$TOML_FILE"
elif ${pkgs.grep}/bin/grep -q '^\[tools\]' "$TOML_FILE"; then
  ${pkgs.gnused}/bin/sed -i "/^\[tools\]/a ${ENTRY}" "$TOML_FILE"
else
  printf '\n[tools]\n%s\n' "$ENTRY" >> "$TOML_FILE"
fi

if [ -n "${DIRENV_DIR:-}" ]; then
  RELOAD_CMD="direnv reload"
else
  RELOAD_CMD="nix develop"
fi

echo "[mise2nix] '${TOOL}' written to ${TOML_FILE}."
echo "[mise2nix] Tool resolution is Nix-managed. Run \`${RELOAD_CMD}\` to enter the updated shell."
```

### lib/default.nix Integration Point

```nix
# In the let block, before mkShell:
miseWrapper = pkgs.writeShellScriptBin "mise" ''
  # ... wrapper script ...
'';

# In mkShell:
packages = [miseWrapper] ++ resolvedPackages ++ extraPackages;
```

### flake.nix Check: wrapper-use-writes-toml

```nix
wrapper-use-writes-toml = let
  miseWrapper = pkgs.writeShellScriptBin "mise" ''
    # ... same script as in lib/default.nix ...
  '';
  tomlFixture = builtins.toFile "fixture.toml" ''
    [tools]
    node = "22"
  '';
in
  pkgs.runCommand "wrapper-use-writes-toml"
    {nativeBuildInputs = [miseWrapper pkgs.gnused pkgs.grep];}
    ''
      cp ${tomlFixture} mise.toml
      MISE_CONFIG_FILE=mise.toml mise use "pipx:black"
      if grep -q '"pipx:black" = "latest"' mise.toml; then
        echo "PASS: entry written to mise.toml" > $out
      else
        echo "FAIL: entry not found in mise.toml"
        cat mise.toml
        exit 1
      fi
    '';
```

### flake.nix Check: wrapper-use-prints-message

```nix
wrapper-use-prints-message = let
  miseWrapper = pkgs.writeShellScriptBin "mise" '' ... '';
  tomlFixture = builtins.toFile "fixture.toml" ''[tools]'';
in
  pkgs.runCommand "wrapper-use-prints-message"
    {nativeBuildInputs = [miseWrapper pkgs.gnused pkgs.grep];}
    ''
      cp ${tomlFixture} mise.toml
      MISE_CONFIG_FILE=mise.toml mise use "npm:prettier" > output.txt 2>&1
      if grep -q "mise2nix" output.txt; then
        echo "PASS: mise2nix attribution in output" > $out
      else
        echo "FAIL: no mise2nix attribution"
        cat output.txt
        exit 1
      fi
    '';
```

### flake.nix Check: wrapper-passthrough (DX-06)

```nix
wrapper-passthrough = let
  miseWrapper = pkgs.writeShellScriptBin "mise" '' ... '';
in
  pkgs.runCommand "wrapper-passthrough"
    {nativeBuildInputs = [miseWrapper pkgs.mise];}
    ''
      mise --version > $out
    '';
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `nix flake check` (existing pattern) |
| Config file | `flake.nix` checks attribute |
| Quick run command | `nix build .#checks.x86_64-linux.wrapper-use-writes-toml` |
| Full suite command | `nix flake check` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WRAP-01 | devShell packages contains mise wrapper, not bare pkgs.mise | unit (eval) | `nix build .#checks.x86_64-linux.wrapper-in-packages` | Wave 0 |
| WRAP-02 | `mise use "pipx:black"` writes entry to mise.toml | integration | `nix build .#checks.x86_64-linux.wrapper-use-writes-toml` | Wave 0 |
| DX-05 | Wrapper output contains "[mise2nix]" attribution | integration | `nix build .#checks.x86_64-linux.wrapper-use-prints-message` | Wave 0 |
| DX-06 | `mise --version` via wrapper exits 0 and calls real mise | integration | `nix build .#checks.x86_64-linux.wrapper-passthrough` | Wave 0 |

### Sampling Rate
- **Per task commit:** `nix build .#checks.x86_64-linux.<specific-check>`
- **Per wave merge:** `nix flake check`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] All four wrapper checks above — new entries in `flake.nix` checks attribute

## Environment Availability

Step 2.6: SKIPPED (no external dependencies beyond nixpkgs — `pkgs.gnused`, `pkgs.grep`, `pkgs.mise` are all nixpkgs built-ins, no external services or CLI tools required outside the Nix build sandbox).

## Open Questions

1. **Duplicate entries on repeated `mise use`**
   - What we know: D-02 accepts duplicate lines as intentional ("mise.toml is human-editable")
   - What's unclear: Whether a future check should verify this is benign for `fromMiseToml` (multiple identical keys in TOML are valid; last one wins per TOML spec)
   - Recommendation: No action needed; TOML spec allows it; resolution uses last value

2. **Empty TOOL_SPEC fallback**
   - What we know: `mise use` with no arguments is a real mise error case
   - What's unclear: Should the wrapper pass `mise use` (no args) through to real mise for its error message, or silently ignore?
   - Recommendation: If `TOOL_SPEC` is empty after arg parsing, fall through to `exec ${pkgs.mise}/bin/mise use "$@"` so the user gets real mise's help/error output

## Sources

### Primary (HIGH confidence)
- Manual testing: sed GNU 4.9 on Linux — verified `/a` command, edge cases (no `[tools]` section, colons in content, forward slashes, `@` symbols)
- Existing `flake.nix` patterns — `pkgs.runCommand`, `nativeBuildInputs`, `builtins.toFile` fixture approach
- Existing `lib/default.nix` — confirmed `pkgs` is in scope, confirmed `packages = [pkgs.mise] ++ ...` line to modify

### Secondary (MEDIUM confidence)
- DIRENV_DIR format: verified in current shell session (`-/home/freya/code/mise2nix`) — leading dash is the canonical direnv format
- `writeShellScriptBin` vs `writeShellApplication` semantics: verified via `packages/fmt.nix` which uses `writeShellApplication` pattern; `writeShellScriptBin` confirmed as simpler no-PATH alternative

### Tertiary (LOW confidence)
- BSD sed `-i` requires `''` argument: widely documented macOS behavior, not directly tested here (Linux environment only)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages are nixpkgs built-ins confirmed in scope
- Architecture: HIGH — exact code patterns verified via shell testing and reading existing implementation
- Pitfalls: HIGH (BSD sed, miseWrapper scope) / MEDIUM (sed injection edge cases)

**Research date:** 2026-03-23
**Valid until:** 2026-04-23 (stable domain)
