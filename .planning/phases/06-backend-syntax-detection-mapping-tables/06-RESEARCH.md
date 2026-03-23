# Phase 6: Backend Syntax Detection + Mapping Tables - Research

**Researched:** 2026-03-23
**Domain:** Nix string manipulation, nixpkgs attribute verification, resolution cascade extension
**Confidence:** HIGH

## Summary

Phase 6 extends `fromMiseToml` to recognise `backend:tool` keys in `[tools]` and route them to three new mapping tables (pipx, npm, cargo). The core detection mechanism is `builtins.match "([^:]+):(.*)" name`, which returns `null` for plain tool names and a two-element list for `backend:tool` keys. This is pure `builtins`, requires no `lib` dependency, and evaluates lazily. All target nixpkgs attribute names have been verified against nixpkgs-unstable on the development machine.

The resolution cascade changes from a linear lookup (overrides → runtimes → utilities → throw) to a branch at the top: if the key contains `:`, dispatch to the backend resolver branch; otherwise, proceed through the existing cascade unchanged. User overrides continue to work by using the full `"pipx:black"` key — dynamic attrset access with colons and hyphens in the key string works correctly in Nix.

The main structural decision is where to put the new tables. The existing `lib/utilities.nix` pattern (`{pkgs}: { tool = _version: pkgs.x; }`) is simple and proven. Three small files (`lib/backends/pipx.nix`, `lib/backends/npm.nix`, `lib/backends/cargo.nix`) each exporting an attrset of tool-name → package is the recommended approach — consistent with how runtimes and utilities are already organised, easy to test in isolation, and easy to extend.

**Primary recommendation:** Use `builtins.match` for colon detection, create `lib/backends/` subdirectory with one file per backend, wire into `lib/default.nix` via a `resolveBackend` function added to the existing `resolve` let binding.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BACKEND-01 | `fromMiseToml` detects `backend:tool` syntax in `[tools]` entries and routes to the appropriate backend resolver | `builtins.match` pattern verified; cascade branch design documented in Architecture Patterns |
| BACKEND-02 | `pipx:tool` entries resolve to `pkgs.python3Packages.*` via a mapping table covering ≤12 common tools | All 12 pipx tools verified in nixpkgs-unstable; full attribute paths documented in Standard Stack |
| BACKEND-03 | `npm:tool` entries resolve to `pkgs.nodePackages.*` (or top-level `pkgs.*`) via a mapping table covering ≤12 common tools | 12 npm tools verified; attribute location varies (nodePackages vs top-level) — documented in Standard Stack |
| BACKEND-04 | `cargo:tool` entries resolve to `pkgs.*` via a mapping table covering ≤12 common tools | All 12 cargo tools verified at `pkgs.*`; attribute path documented in Standard Stack |
| BACKEND-05 | Unknown backend or unmapped tool throws a descriptive error naming the tool and explaining the escape hatches | Pattern follows existing `builtins.throw` style; two throw sites needed — one for unknown backend, one for unmapped tool within a known backend |
</phase_requirements>

## Standard Stack

### Core: Nix builtins Used

| Builtin | Purpose | Why Standard |
|---------|---------|--------------|
| `builtins.match "([^:]+):(.*)" name` | Detect and parse `backend:tool` keys | Pure, no lib dep, returns `null` for non-matches, O(1) |
| `builtins.elemAt list 0 / 1` | Extract backend name and tool name from match result | Standard list access after `builtins.match` |
| `builtins.throw` | Error on unknown backend / unmapped tool | Consistent with existing error pattern |
| `builtins.attrValues` / `builtins.mapAttrs` | Already used in `resolve` — unchanged | No change needed |

### Verified nixpkgs Attributes

**pipx backend — `lib/backends/pipx.nix`**

All map to `pkgs.python3Packages.*` except `poetry` (top-level `pkgs.poetry`).

| mise tool name | nixpkgs attribute | Verified version |
|---------------|-------------------|-----------------|
| `black` | `pkgs.python3Packages.black` | 25.1.0 |
| `mypy` | `pkgs.python3Packages.mypy` | 1.19.1 |
| `ruff` | `pkgs.python3Packages.ruff` | 0.15.5 |
| `isort` | `pkgs.python3Packages.isort` | 7.0.0 |
| `pylint` | `pkgs.python3Packages.pylint` | 4.0.4 |
| `flake8` | `pkgs.python3Packages.flake8` | 7.3.0 |
| `pyupgrade` | `pkgs.python3Packages.pyupgrade` | 3.21.2 |
| `bandit` | `pkgs.python3Packages.bandit` | 1.9.4 |
| `pip-tools` | `pkgs.python3Packages."pip-tools"` | 7.5.2 |
| `twine` | `pkgs.python3Packages.twine` | 6.2.0 |
| `mdformat` | `pkgs.python3Packages.mdformat` | 1.0.0 |
| `poetry` | `pkgs.poetry` | 2.3.1 |

NOTE: `poetry` is not in `python3Packages` — it lives at top-level `pkgs.poetry`. The `pip-tools` attribute requires a quoted string in a static Nix expression (`pkgs.python3Packages."pip-tools"`), but dynamic access via `pkgs.python3Packages.${tool}` works correctly for hyphenated names.

**npm backend — `lib/backends/npm.nix`**

Tools live in two locations: `pkgs.nodePackages.*` (the traditional home) and top-level `pkgs.*` (newer tools packaged as first-class derivations). The table must record which path each tool uses.

| mise tool name | nixpkgs attribute | Verified version |
|---------------|-------------------|-----------------|
| `prettier` | `pkgs.nodePackages.prettier` | 3.6.2 |
| `typescript` | `pkgs.nodePackages.typescript` | 5.9.3 |
| `eslint` | `pkgs.nodePackages.eslint` | 10.0.3 |
| `esbuild` | `pkgs.esbuild` | 0.27.2 |
| `vite` | `pkgs.vite` | 1.4 |
| `turbo` | `pkgs.turbo` | 2.8.15 |
| `vue` | `pkgs.vue` | 3.3.0 |
| `biome` | `pkgs.biome` | 2.4.7 |
| `pnpm` | `pkgs.pnpm` | 10.32.1 |
| `yarn` | `pkgs.yarn` | 1.22.22 |
| `wrangler` | `pkgs.wrangler` | 4.62.0 |
| `tsx` | `pkgs.tsx` | 4.21.0 |

NOTE: `webpack`, `rollup`, `ts-node`, `nx`, and `svelte` are NOT available as standalone packages in nixpkgs-unstable. The initial table uses 12 verified alternatives. Users who need webpack/rollup must use `overrides` or `extraPackages`.

**cargo backend — `lib/backends/cargo.nix`**

All 12 target tools are available at top-level `pkgs.*`.

| mise tool name | nixpkgs attribute | Verified version |
|---------------|-------------------|-----------------|
| `ripgrep` | `pkgs.ripgrep` | 15.1.0 |
| `bat` | `pkgs.bat` | 0.26.1 |
| `fd` | `pkgs.fd` | 10.4.2 |
| `eza` | `pkgs.eza` | 0.23.4 |
| `delta` | `pkgs.delta` | 0.18.2 |
| `zoxide` | `pkgs.zoxide` | 0.9.7 (approx) |
| `tokei` | `pkgs.tokei` | 14.0.0 |
| `hyperfine` | `pkgs.hyperfine` | 1.20.0 |
| `just` | `pkgs.just` | 1.46.0 |
| `cargo-watch` | `pkgs.cargo-watch` | 8.5.3 |
| `cargo-nextest` | `pkgs.cargo-nextest` | 0.9.130 |
| `watchexec` | `pkgs.watchexec` | 2.3.2 |

NOTE: Several cargo tools (`ripgrep`, `bat`, `fd`, `eza`, `delta`, `zoxide`, `tokei`, `hyperfine`, `just`) are already in `lib/utilities.nix`. The cargo backend table is a parallel path reached only when the user writes `cargo:ripgrep` — the plain `ripgrep` key still routes through utilities. Both paths return the same package. No conflict.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `builtins.match` for colon detection | `lib.strings.splitString ":"` | `splitString` also works, but `builtins.match` is more direct and avoids needing `lib` in the backends files themselves |
| `lib/backends/` subdirectory | Single `lib/backends.nix` flat file | Flat file works for 3 backends, but subdirectory scales better and mirrors the `lib/{runtimes,utilities}.nix` pattern |
| Explicit per-tool mapping (chosen) | Dynamic `pkgs.python3Packages.${tool}` lookup with fallback | Dynamic lookup would silently pass unknown tool names to nixpkgs; explicit table gives clear error at the right abstraction |

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── default.nix          # Extended with resolveBackend logic
├── runtimes.nix         # Unchanged
├── utilities.nix        # Unchanged
├── env.nix              # Unchanged
└── backends/
    ├── pipx.nix         # {pkgs}: { black = pkgs.python3Packages.black; ... }
    ├── npm.nix          # {pkgs}: { prettier = pkgs.nodePackages.prettier; ... }
    └── cargo.nix        # {pkgs}: { ripgrep = pkgs.ripgrep; ... }
```

### Pattern 1: Backend Detection in `resolve`

The `resolve` function in `lib/default.nix` gains a top-level branch before the existing cascade:

```nix
# Source: verified with nix eval on 2026-03-23
resolve = name: version: let
  v         = builtins.toString version;
  parsed    = builtins.match "([^:]+):(.*)" name;
  isBackend = parsed != null;
  backend   = if isBackend then builtins.elemAt parsed 0 else null;
  tool      = if isBackend then builtins.elemAt parsed 1 else null;
in
  if isBackend
  then resolveBackend backend tool v
  else
    overrides.${name} or (
      if runtimes ? ${name}
      then runtimes.${name} v
      else if utilities ? ${name}
      then utilities.${name} v
      else builtins.throw "mise2nix: unknown tool '${name}' ..."
    );
```

NOTE: `overrides.${name}` where `name = "pipx:black"` works correctly — Nix attrset keys can contain colons and hyphens when accessed with `${expr}` syntax. Verified with `nix eval`.

### Pattern 2: `resolveBackend` Function

```nix
# Source: verified with nix eval on 2026-03-23
backends = {
  pipx  = import ./backends/pipx.nix  {inherit pkgs;};
  npm   = import ./backends/npm.nix   {inherit pkgs;};
  cargo = import ./backends/cargo.nix {inherit pkgs;};
};

resolveBackend = backend: tool: _version:
  if !(backends ? ${backend})
  then builtins.throw
    "mise2nix: unknown backend '${backend}' — supported backends: pipx, npm, cargo. Use 'overrides = { \"${backend}:${tool}\" = pkgs.something; }' or 'extraPackages' to provide it."
  else
    let table = backends.${backend};
    in table.${tool} or (builtins.throw
      "mise2nix: tool '${tool}' is not in the '${backend}' mapping table. Use 'overrides = { \"${backend}:${tool}\" = pkgs.something; }' or 'extraPackages' to provide it.");
```

### Pattern 3: Backend File Structure

Each backend file follows the exact same pattern as `lib/utilities.nix`. The `_version` argument is dropped because the backend resolver does not need it (the table maps to a single nixpkgs-pinned package).

```nix
# lib/backends/cargo.nix
{pkgs}: {
  ripgrep      = pkgs.ripgrep;
  bat          = pkgs.bat;
  fd           = pkgs.fd;
  eza          = pkgs.eza;
  delta        = pkgs.delta;
  zoxide       = pkgs.zoxide;
  tokei        = pkgs.tokei;
  hyperfine    = pkgs.hyperfine;
  just         = pkgs.just;
  cargo-watch  = pkgs.cargo-watch;
  cargo-nextest = pkgs.cargo-nextest;
  watchexec    = pkgs.watchexec;
}
```

NOTE: In the backend files, entries are plain packages (not functions). The `resolveBackend` function accesses `table.${tool}` directly. The `_version` argument is accepted by `resolveBackend` but unused — backend resolution is always "latest at the nixpkgs pin."

### Pattern 4: pipx.nix Special Cases

`poetry` maps to `pkgs.poetry` (top-level), not `pkgs.python3Packages.poetry`. `pip-tools` uses the hyphenated attribute accessed dynamically.

```nix
# lib/backends/pipx.nix
{pkgs}: {
  black     = pkgs.python3Packages.black;
  mypy      = pkgs.python3Packages.mypy;
  ruff      = pkgs.python3Packages.ruff;
  isort     = pkgs.python3Packages.isort;
  pylint    = pkgs.python3Packages.pylint;
  flake8    = pkgs.python3Packages.flake8;
  pyupgrade = pkgs.python3Packages.pyupgrade;
  bandit    = pkgs.python3Packages.bandit;
  "pip-tools" = pkgs.python3Packages."pip-tools";
  twine     = pkgs.python3Packages.twine;
  mdformat  = pkgs.python3Packages.mdformat;
  poetry    = pkgs.poetry;  # NOTE: top-level, not python3Packages
}
```

### Pattern 5: npm.nix Mixed Attribute Paths

```nix
# lib/backends/npm.nix
{pkgs}: {
  prettier   = pkgs.nodePackages.prettier;
  typescript = pkgs.nodePackages.typescript;
  eslint     = pkgs.nodePackages.eslint;
  esbuild    = pkgs.esbuild;
  vite       = pkgs.vite;
  turbo      = pkgs.turbo;
  vue        = pkgs.vue;
  biome      = pkgs.biome;
  pnpm       = pkgs.pnpm;
  yarn       = pkgs.yarn;
  wrangler   = pkgs.wrangler;
  tsx        = pkgs.tsx;
}
```

### Anti-Patterns to Avoid

- **Dynamic nixpkgs lookup without a table:** Do not write `pkgs.python3Packages.${tool}` directly without checking the table first. Unknown tools would produce a cryptic nixpkgs evaluation error instead of the helpful mise2nix error.
- **Routing `backend:tool` through the runtime/utility cascade:** Keys containing `:` must be intercepted before the cascade, not passed through it. `runtimes ? "pipx:black"` is always false, but it wastes a lookup.
- **Using `lib.strings.splitString` when `builtins.match` works:** `splitString` requires `lib` to be passed into the backends files. `builtins.match` lives in `lib/default.nix` only, keeping backend files dependency-free.
- **Forgetting the `overrides` priority for backend keys:** `overrides."pipx:black"` must be checked before dispatching to the backend table. The current `overrides.${name} or (...)` pattern already handles this correctly since `name` is the full `"pipx:black"` key.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| String split for `backend:tool` | Custom recursive character scanner | `builtins.match "([^:]+):(.*)"` | Built-in, single expression, returns null for non-matches |
| Package lookup with helpful error | Try/catch on `pkgs.${attr}` | Explicit attrset table + `or (builtins.throw ...)` | nixpkgs errors are cryptic; explicit table gives mise2nix-branded message |
| Listing supported tools in error message | Introspect attrset keys at eval time | Hardcode the list in the throw string | The list is static; introspection adds complexity with no benefit |

## Common Pitfalls

### Pitfall 1: `poetry` is NOT in `python3Packages`

**What goes wrong:** Writing `pkgs.python3Packages.poetry` causes an eval error — the attribute does not exist.
**Why it happens:** Poetry is packaged as a top-level derivation in nixpkgs. It is NOT in `python3Packages`.
**How to avoid:** Map `pipx:poetry` to `pkgs.poetry` in the table.
**Warning signs:** `error: attribute 'poetry' missing` during `nix flake check`.

### Pitfall 2: `pip-tools` attribute has a hyphen

**What goes wrong:** `pkgs.python3Packages.pip-tools` is a subtraction expression in Nix (evaluates `pip` minus `tools`), not attribute access.
**Why it happens:** Hyphens are valid in identifiers in attribute keys, but NOT in attribute access paths without quoting.
**How to avoid:** Write `pkgs.python3Packages."pip-tools"` in static expressions, or use `pkgs.python3Packages.${tool}` where `tool = "pip-tools"` (dynamic access with `${}` handles hyphens correctly — verified).
**Warning signs:** `error: undefined variable 'pip'` or similar arithmetic error.

### Pitfall 3: `cargo-watch`, `cargo-nextest` hyphen issue

**What goes wrong:** Same hyphen problem as `pip-tools` — `pkgs.cargo-watch` is arithmetic in static context.
**Why it happens:** Same root cause.
**How to avoid:** In `lib/backends/cargo.nix`, use `"cargo-watch" = pkgs.cargo-watch;` with quoted key, OR rely on the fact that Nix allows hyphenated keys in attrsets as long as the LHS is quoted or is a string literal in context (the assignment `"cargo-watch" = pkgs.cargo-watch;` is valid).
**Warning signs:** Same arithmetic error.

### Pitfall 4: webpack, rollup, ts-node, nx, svelte are NOT in nixpkgs

**What goes wrong:** Trying to resolve `npm:webpack` via nixpkgs fails — the package does not exist.
**Why it happens:** These tools are not packaged in nixpkgs-unstable as of 2026-03-23 (verified via `nix search` and `nix eval`).
**How to avoid:** Do not include webpack, rollup, ts-node, nx, or svelte in the npm table. The unknown-tool error will fire for these, directing users to `extraPackages`.
**Warning signs:** `error: attribute 'webpack' missing` — but we will never hit this if the table is correct.

### Pitfall 5: Resolution order — `overrides` must precede backend dispatch

**What goes wrong:** If `resolveBackend` is called before checking `overrides.${name}`, a user-provided `overrides."pipx:black"` is silently ignored.
**Why it happens:** The `overrides` check only applied to the plain-name branch in the original code.
**How to avoid:** Check `overrides.${name}` first, before `isBackend` check, OR check inside the `isBackend` branch before calling `resolveBackend`. Either approach works; the important constraint is that overrides win for ALL key forms.

### Pitfall 6: Cargo table duplicates utilities

**What goes wrong:** `cargo:ripgrep` and plain `ripgrep` both resolve to `pkgs.ripgrep`. This is intentional and correct, but could cause confusion during code review.
**Why it happens:** The cargo table covers Rust-ecosystem tools that were already in utilities.nix.
**How to avoid:** No action needed — duplication is harmless. Both paths resolve to the same package. A comment in `cargo.nix` noting this is sufficient.

## Code Examples

### Detection + dispatch in `lib/default.nix`

```nix
# Source: verified with `nix eval --expr` on 2026-03-23
# builtins.match returns null for plain names, list for "backend:tool"
let
  parsed    = builtins.match "([^:]+):(.*)" name;
  isBackend = parsed != null;
  backend   = if isBackend then builtins.elemAt parsed 0 else null;
  tool      = if isBackend then builtins.elemAt parsed 1 else null;
in
  overrides.${name} or (
    if isBackend
    then resolveBackend backend tool v
    else if runtimes ? ${name}
    then runtimes.${name} v
    else if utilities ? ${name}
    then utilities.${name} v
    else builtins.throw "mise2nix: unknown tool '${name}' ..."
  )
```

NOTE: Placing `overrides.${name} or (...)` as the outermost `or` means overrides win for BOTH backend and plain keys. No special-casing needed.

### `resolveBackend` error messages

```nix
# Unknown backend error
builtins.throw
  "mise2nix: unknown backend '${backend}' for tool '${backend}:${tool}'. Supported backends: pipx, npm, cargo. Use 'overrides = { \"${backend}:${tool}\" = pkgs.something; }' or 'extraPackages = [ pkgs.something ]'."

# Unmapped tool within known backend error
builtins.throw
  "mise2nix: '${tool}' is not in the ${backend} mapping table. Use 'overrides = { \"${backend}:${tool}\" = pkgs.something; }' or 'extraPackages = [ pkgs.something ]'."
```

### nix flake check patterns for backend resolution

```nix
# Inline TOML fixture with backend:tool key
resolve-pipx-black = let
  toml = builtins.toFile "pipx-test.toml" ''
    [tools]
    "pipx:black" = "latest"
  '';
  devShell = self.lib.fromMiseToml toml {inherit pkgs;};
in pkgs.runCommand "resolve-pipx-black" {} ''
  echo "devShell: ${devShell}"
  echo "PASS: pipx:black resolved" > $out
'';

# Error check for unknown backend
unknown-backend-error = let
  toml = builtins.toFile "unknown-backend.toml" ''
    [tools]
    "ubi:some-tool" = "latest"
  '';
  devShell = self.lib.fromMiseToml toml {inherit pkgs;};
  result = builtins.tryEval (builtins.deepSeq devShell.nativeBuildInputs devShell);
in pkgs.runCommand "unknown-backend-error" {} ''
  ${if result.success
    then ''echo "FAIL: should have thrown for unknown backend" && exit 1''
    else ''echo "PASS: unknown backend correctly throws" > $out''}
'';
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| All npm tools in `pkgs.nodePackages.*` | Many npm tools now at top-level `pkgs.*` (esbuild, vite, biome, tsx, pnpm, turbo, wrangler, vue, yarn) | Ongoing nixpkgs evolution | The npm table must hardcode which path each tool uses — cannot assume a single namespace |
| `npm:webpack` resolvable in nixpkgs | Webpack removed from nixpkgs | Sometime 2024-2025 | Must exclude from npm table; users need `extraPackages` |

**Deprecated/outdated:**
- `pkgs.nodePackages.webpack`: No longer in nixpkgs-unstable as of 2026-03-23.
- `pkgs.nodePackages.rollup`: Not present in nixpkgs-unstable.
- `pkgs.nodePackages.ts-node`: Not present in nixpkgs-unstable.

## Open Questions

1. **TOML quoting of `backend:tool` keys**
   - What we know: `builtins.fromTOML` will parse `"pipx:black" = "latest"` correctly (quoted TOML key). The colon is valid in a TOML quoted key.
   - What's unclear: Whether mise writes `[tools]` entries as quoted or unquoted in `mise.toml`. Unquoted `pipx:black = "latest"` is NOT valid TOML — colons are not allowed in unquoted TOML keys.
   - Recommendation: In tests, always use TOML quoted keys (`"pipx:black" = "latest"`). The README and phase 7 wrapper work should confirm what mise actually writes.

2. **`poetry` placement in the pipx table**
   - What we know: `pkgs.poetry` exists at top-level; `python3Packages.poetry` does not exist.
   - What's unclear: Whether future nixpkgs adds `python3Packages.poetry`. If so, both paths work.
   - Recommendation: Map to `pkgs.poetry` in the table. If nixpkgs adds `python3Packages.poetry` later, it can be updated without breaking users.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified — this phase is pure Nix code and nixpkgs attribute access, no CLI tools or services required beyond existing `nix` toolchain already in use).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `nix flake check` (derivation-based checks) |
| Config file | `flake.nix` — `checks` output |
| Quick run command | `nix flake check --no-build` (eval only, ~2s) |
| Full suite command | `nix flake check` (builds all check derivations) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BACKEND-01 | `pipx:black` key routes to backend, not utility cascade | smoke | `nix flake check --no-build` | ❌ Wave 0 |
| BACKEND-02 | `pipx:black`, `pipx:mypy`, `pipx:ruff` resolve correctly | smoke | `nix flake check --no-build` | ❌ Wave 0 |
| BACKEND-03 | `npm:prettier`, `npm:typescript`, `npm:eslint` resolve correctly | smoke | `nix flake check --no-build` | ❌ Wave 0 |
| BACKEND-04 | `cargo:ripgrep`, `cargo:bat`, `cargo:fd` resolve correctly | smoke | `nix flake check --no-build` | ❌ Wave 0 |
| BACKEND-05 | Unknown backend throws; unmapped tool in known backend throws | smoke | `nix flake check --no-build` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `nix flake check --no-build` (eval-only, catches type errors and missing attrs without building)
- **Per wave merge:** `nix flake check` (full build, verifies derivations succeed)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `flake.nix` — add `resolve-pipx-black`, `resolve-npm-prettier`, `resolve-cargo-ripgrep` check derivations
- [ ] `flake.nix` — add `unknown-backend-error`, `unmapped-tool-error` check derivations that verify `builtins.tryEval` returns `success = false`
- [ ] `flake.nix` — add `backend-overrides-win` check: `overrides."pipx:black" = pkgs.hello` should produce devShell with hello, not python3Packages.black

## Sources

### Primary (HIGH confidence)

- `nix eval nixpkgs#python3Packages.{tool}.pname` — all 12 pipx tools verified live against nixpkgs-unstable on 2026-03-23
- `nix eval nixpkgs#nodePackages.{tool}.pname` — prettier, typescript, eslint verified live
- `nix eval nixpkgs#{tool}.pname` — esbuild, vite, turbo, vue, biome, pnpm, yarn, wrangler, tsx verified live
- `nix eval nixpkgs#{tool}.pname` — all 12 cargo tools verified live
- `nix eval --expr 'builtins.match "([^:]+):(.*)" "pipx:black"'` — detection pattern verified working
- `nix eval --impure --expr 'let pkgs = import <nixpkgs> {}; tool = "pip-tools"; in pkgs.python3Packages.${tool}.pname'` — dynamic hyphen access verified working
- `/home/freya/code/mise2nix/lib/default.nix` — existing `resolve` function and cascade structure
- `/home/freya/code/mise2nix/lib/utilities.nix` — file structure pattern to replicate
- `/home/freya/code/mise2nix/flake.nix` — check derivation pattern (`builtins.toFile` inline TOML, `builtins.tryEval`)

### Secondary (MEDIUM confidence)

- `nix search nixpkgs webpack` — confirmed webpack is NOT in nixpkgs-unstable
- `nix search nixpkgs rollup` — confirmed rollup is NOT in nixpkgs-unstable
- `nix eval nixpkgs#nodePackages.ts-node.pname` → missing — confirmed ts-node is NOT in nodePackages

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Nixpkgs attribute names: HIGH — all verified live with `nix eval` against nixpkgs-unstable on 2026-03-23
- Detection mechanism (`builtins.match`): HIGH — verified with `nix eval` expression
- Architecture patterns: HIGH — directly derived from existing code in `lib/default.nix`
- Error message content: MEDIUM — wording chosen for consistency with existing errors, but not externally validated

**Research date:** 2026-03-23
**Valid until:** 2026-06-23 (nixpkgs attribute paths are stable but nixpkgs-unstable versions advance; recheck versions if > 90 days)
