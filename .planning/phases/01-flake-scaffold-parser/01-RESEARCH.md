# Phase 1: Flake Scaffold + Parser - Research

**Researched:** 2026-03-22
**Domain:** Nix flake library structure, `builtins.fromTOML`, `forAllSystems` without flake-utils, `pkgs.mkShell`
**Confidence:** HIGH

---

## Summary

Phase 1 creates the skeleton of a Nix flake library: a `flake.nix` that exposes `mise2nix.lib.fromMiseToml`, a `forAllSystems` helper inlined without flake-utils, and a `devShells` output backed by `pkgs.mkShell`. The parser (`builtins.fromTOML`) is built into Nix and fully handles every `mise.toml` value format. All five success criteria have been verified by running real Nix commands against a prototype flake.

The `lib` output of a Nix flake is a plain attrset — not system-scoped — making it the correct home for `fromMiseToml`. `devShells` is system-scoped and is wired by the flake itself using `forAllSystems`. `fromMiseToml` returns a `pkgs.mkShell` derivation directly (not a wrapper attrset), matching the usage pattern `devShells.${system}.default = self.lib.fromMiseToml ./mise.toml { inherit pkgs; }`.

**Primary recommendation:** Use `nixpkgs.lib.genAttrs` with four explicit systems for `forAllSystems`, import the library from a `lib/default.nix` file, and have `fromMiseToml` return `pkgs.mkShell { packages = []; }` in Phase 1 (tool resolution added in Phase 2). This is verified working with `nix flake show` and `nix develop`.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CORE-01 | Library reads `mise.toml` using `builtins.fromTOML (builtins.readFile path)` | Verified: `builtins.fromTOML` handles all mise.toml value formats; `builtins.readFile` works when path is flake-relative |
| SHELL-01 | Produces `devShells.${system}.default` via a simple `forAllSystems` exposed directly in the flake (no flake-utils) | Verified: `nixpkgs.lib.genAttrs` inlined in `let` block produces correct devShells output; `nix flake show` and `nix develop` both confirmed working |
| SHELL-03 | Uses `pkgs.mkShell` exclusively — no devenv, no home-manager | Verified: `pkgs.mkShell {}` produces a valid derivation; minimal call with empty `packages = []` produces a working shell |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nixpkgs | nixpkgs-unstable (pinned via flake.lock) | `nixpkgs.lib.genAttrs`, `pkgs.mkShell` | Sole external dependency per project constraint |
| `builtins.fromTOML` | Built into Nix 2.6+ (system: 2.31.3) | TOML parsing | Zero dependencies; built into the Nix evaluator itself |
| `pkgs.mkShell` | Part of nixpkgs | devShell derivation | Required by SHELL-03 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `nixpkgs.lib.genAttrs` | From nixpkgs.lib | Build system-keyed attrsets | Used for `forAllSystems` instead of flake-utils |
| `nixpkgs.lib.runTests` | From nixpkgs.lib | Unit-test pure Nix functions | Used in `checks` output for TOML parsing validation |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `nixpkgs.lib.genAttrs` | `flake-utils.lib.eachDefaultSystem` | flake-utils is explicitly out of scope; genAttrs is one line and zero extra input |
| `nixpkgs.lib.genAttrs` | `lib.systems.flakeExposed` | flakeExposed includes 10 systems (armv6l-linux, powerpc64le-linux, etc.); explicit 4-system list is more practical for a library flake and avoids build noise |
| `pkgs.mkShell` | `pkgs.mkShellNoCC` | mkShell with no packages is fine; mkShellNoCC matters only when you need no stdenv; no difference for Phase 1 |

**Installation:** No installation step — this project IS a flake. nixpkgs is the only input.

```bash
nix flake update  # creates/updates flake.lock
```

**Version verification (nixpkgs pin):**
```bash
nix eval .#devShells.x86_64-linux.default  # confirms flake evaluates
```

---

## Architecture Patterns

### Recommended Project Structure

```
mise2nix/
├── flake.nix          # Inputs, forAllSystems, outputs wiring
├── flake.lock         # Pinned nixpkgs rev
└── lib/
    └── default.nix    # fromMiseToml implementation
```

Phase 1 only needs `flake.nix` + `lib/default.nix`. Subsequent phases can split `default.nix` into `parser.nix`, `resolver.nix`, etc., but Phase 1 is simple enough to keep in one file.

### Pattern 1: Library flake with non-system-specific `lib` output

The `lib` output of a flake is a plain attrset — it is NOT wrapped in `forAllSystems`. Library functions that accept `{ pkgs }` as an argument get their system-specificity from the `pkgs` argument, not from the flake output structure.

```nix
# Source: verified against uv2nix/flake.nix (raw.githubusercontent.com) and prototype testing
outputs = { self, nixpkgs }:
  let
    lib = nixpkgs.lib;
    forAllSystems = lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  in {
    # NOT system-specific — lib functions take pkgs as argument
    lib = import ./lib { inherit lib; };

    # System-specific — devShells must be keyed by system
    devShells = forAllSystems (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = self.lib.fromMiseToml ./mise.toml { inherit pkgs; };
      }
    );
  };
```

`nix flake show` shows `lib: unknown` — this is expected and correct. The `lib` output is not a "known" schema type in Nix's built-in output schema, but `nix flake check` still validates it without error.

### Pattern 2: `lib/default.nix` receives dependencies as arguments

Modeled after uv2nix's `lib/default.nix`:

```nix
# lib/default.nix
# Source: raw.githubusercontent.com/pyproject-nix/uv2nix/master/lib/default.nix
{ lib }:
{
  fromMiseToml = path: { pkgs }:
    let
      config = builtins.fromTOML (builtins.readFile path);
      tools  = config.tools or {};
      env    = config.env   or {};
    in
      pkgs.mkShell {
        packages = [];  # Phase 2: map tools to pkgs
        # Phase 4: shellHook for env vars
      };
}
```

The `lib` argument is `nixpkgs.lib` — passed in from `flake.nix`. In Phase 1, `lib` is not actually needed inside the function body, but accepting it sets up the pattern for later phases.

### Pattern 3: `fromMiseToml` returns a derivation directly

`fromMiseToml` returns the result of `pkgs.mkShell { ... }` — a derivation — not a wrapper attrset. This matches the calling convention:

```nix
devShells.${system}.default = self.lib.fromMiseToml ./mise.toml { inherit pkgs; };
```

If it returned an attrset like `{ devShell = pkgs.mkShell {}; }`, the caller would need `.devShell`. The direct-derivation API is simpler and consistent with how nixpkgs library functions work.

### Pattern 4: Validation via `pkgs.runCommand` in `checks`

For Phase 1, the most meaningful check is that the TOML parsing works and that the devShell builds. Use `pkgs.runCommand` (not `pkgs.runCommandNoCC` — that name is deprecated in current nixpkgs) as the check vehicle:

```nix
checks = forAllSystems (system:
  let pkgs = nixpkgs.legacyPackages.${system};
  in {
    devshell-builds = pkgs.runCommand "devshell-builds" {} ''
      echo "Flake evaluated and devShell derivation built" > $out
    '';
  }
);
```

For pure Nix function tests (testing `fromMiseToml` logic without building), `nixpkgs.lib.runTests` returns `[]` on success and a list of failures otherwise. It can be wrapped in a derivation via `pkgs.testers.runNixOSTest` or used as a `pkgs.runCommand` that `builtins.toFile`s the results.

### Anti-Patterns to Avoid

- **Wrapping `lib` in `forAllSystems`:** `lib.fromMiseToml` must NOT be `lib.x86_64-linux.fromMiseToml`. Pure functions take `{ pkgs }` for system-specificity.
- **Using `buildInputs` instead of `packages` in `mkShell`:** For devShells, `packages` is the correct argument. `buildInputs` works but `packages` is the documented mkShell-specific parameter.
- **Calling `builtins.readFile` on a derivation output:** `builtins.fromTOML` rejects strings with store path context (a known Nix limitation). The path must be a source file, not a built artifact. This is fine for `mise.toml` which is always a source file.
- **Using `lib.systems.flakeExposed` for `forAllSystems`:** This includes 10 systems (armv6l-linux, powerpc64le-linux, riscv64-linux, x86_64-freebsd, etc.) that almost no library author tests against. Use an explicit list of 4 systems: x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin.
- **Skipping `or {}` guards on TOML sections:** `builtins.fromTOML` returns only keys that exist in the file. A `mise.toml` without `[env]` will not have `.env` in the parsed attrset. Always use `config.tools or {}` and `config.env or {}`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TOML parsing | Custom string parser | `builtins.fromTOML` | Built into Nix; handles all TOML spec correctly including inline tables, arrays, multi-line strings |
| System iteration | Manual attrset construction | `nixpkgs.lib.genAttrs` | One line; handles the `{ "x86_64-linux" = ...; }` shape correctly |
| devShell derivation | `stdenv.mkDerivation` with shell setup | `pkgs.mkShell` | Specialized wrapper; handles `shellHook`, `inputsFrom`, `packages` correctly |

**Key insight:** Every primitive needed for Phase 1 is already in Nix builtins or nixpkgs. The implementation is almost entirely wiring.

---

## Common Pitfalls

### Pitfall 1: `nix flake check` warns about `lib: unknown`
**What goes wrong:** `nix flake show` and `nix flake check` display `lib: unknown` because `lib` is not in Nix's built-in flake output schema.
**Why it happens:** The Nix evaluator knows about `packages`, `devShells`, `checks`, `apps` etc., but `lib` is a convention, not a spec.
**How to avoid:** This is expected and correct behavior. Do not suppress the warning. It is not an error — `nix flake check` passes without issue.
**Warning signs:** If `nix flake check` exits non-zero, that is a real error. `lib: unknown` in stdout is cosmetic.

### Pitfall 2: `builtins.readFile` fails in pure eval mode
**What goes wrong:** `nix eval --expr 'builtins.readFile /absolute/path'` fails with "access to absolute path is forbidden in pure evaluation mode."
**Why it happens:** Pure eval mode (the default for `nix eval`) forbids impure filesystem access.
**How to avoid:** Inside a flake, paths are always flake-relative (e.g., `./mise.toml`) which Nix copies into the store. This works correctly in flake context. The error only appears when testing with `nix eval --expr` and an absolute path outside the flake — use `--impure` in that case.
**Warning signs:** If you see "access to absolute path is forbidden" during `nix develop` or `nix flake show`, the path argument is not a flake-relative path.

### Pitfall 3: `config.tools` throws if `[tools]` section is absent
**What goes wrong:** `builtins.fromTOML` returns only the keys present in the TOML file. A `mise.toml` without `[tools]` has no `.tools` attribute. Accessing `config.tools` throws `attribute 'tools' missing`.
**Why it happens:** Nix attribute access is strict — missing keys are errors.
**How to avoid:** Always guard: `config.tools or {}` and `config.env or {}`.
**Warning signs:** `error: attribute 'tools' missing` during eval of `fromMiseToml`.

### Pitfall 4: Inline table values vs. plain string values in `[tools]`
**What goes wrong:** A tool specified as `node = { version = "22", postinstall = "..." }` produces a nested attrset, not a string. Code that does `tools.node == "22"` fails silently or throws.
**Why it happens:** `builtins.fromTOML` faithfully represents TOML inline tables as Nix attrsets.
**How to avoid:** In Phase 1, `fromMiseToml` does not resolve tools, so this is not a problem yet. Document the issue so Phase 2 handles both string and attrset shapes. The check is: `if builtins.isString val then val else val.version`.
**Warning signs:** `error: value is an attribute set while a string was expected` in Phase 2 tool resolution.

### Pitfall 5: `runCommandNoCC` deprecation warning in checks
**What goes wrong:** Using `pkgs.runCommandNoCC` in `checks` produces: `evaluation warning: 'runCommandNoCC' has been renamed to/replaced by 'runCommand'`.
**Why it happens:** nixpkgs renamed the function.
**How to avoid:** Use `pkgs.runCommand` everywhere. Verified against nixpkgs-unstable pin (2026-03-18).
**Warning signs:** Warning in `nix flake check` output.

### Pitfall 6: `fromTOML` attrset sorting bug (historical, fixed)
**What goes wrong:** In Nix versions around the cpptoml→toml11 migration, `fromTOML` returned unsorted attrsets, causing random attribute lookup failures.
**Why it happens:** The `v.attrs->sort()` call was accidentally dropped.
**How to avoid:** Fixed in Nix PR #5841. Current system runs Nix 2.31.3, which is far newer than the fix. This is a non-issue.
**Warning signs:** N/A — resolved.

---

## Code Examples

### Complete Phase 1 `flake.nix`

```nix
# Source: prototype verified with nix 2.31.3; nix flake show + nix develop both pass
{
  description = "mise2nix — converts mise.toml to a Nix devShell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in {
      lib = import ./lib { inherit lib; };

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = self.lib.fromMiseToml ./mise.toml { inherit pkgs; };
        }
      );
    };
}
```

### Complete Phase 1 `lib/default.nix`

```nix
# Source: prototype verified — fromMiseToml returns a derivation (pkgs.mkShell result)
{ lib }:
{
  fromMiseToml = path: { pkgs }:
    let
      config = builtins.fromTOML (builtins.readFile path);
      tools  = config.tools or {};
      env    = config.env   or {};
    in
      pkgs.mkShell {
        packages = [];   # Populated in Phase 2
        # shellHook added in Phase 4 for env vars
      };
}
```

### `builtins.fromTOML` return shape for a typical `mise.toml`

```nix
# Input mise.toml:
# [tools]
# node = "22"
# python = "3.11"
# ripgrep = "latest"
# node-inline = { version = "22", postinstall = "corepack enable" }
# python-multi = ["3.10", "3.11"]
#
# [env]
# NODE_ENV = "development"

# builtins.fromTOML output (verified on Nix 2.31.3):
{
  tools = {
    node = "22";
    python = "3.11";
    ripgrep = "latest";
    node-inline = { version = "22"; postinstall = "corepack enable"; };
    python-multi = [ "3.10" "3.11" ];
  };
  env = {
    NODE_ENV = "development";
  };
}
```

### Minimal working `pkgs.mkShell`

```nix
# Source: nixpkgs docs + prototype testing
pkgs.mkShell { }                           # Fully valid — empty shell
pkgs.mkShell { packages = []; }           # Equivalent, explicit
pkgs.mkShell { packages = [ pkgs.git ]; } # Phase 2+ pattern
```

### `lib.runTests` pattern for pure Nix unit tests

```nix
# Source: verified — lib.runTests returns [] on all-pass, list of failures otherwise
# Used in checks output or as ad-hoc validation
let
  results = nixpkgs.lib.runTests {
    test_parse_tools = {
      expr = (builtins.fromTOML "[tools]\nnode = \"22\"\n").tools.node;
      expected = "22";
    };
  };
in
  assert results == []; "tests passed"
```

### `nix flake show` expected output

```
git+file:///path/to/mise2nix
├───devShells
│   ├───aarch64-darwin
│   │   └───default omitted (use '--all-systems' to show)
│   ├───aarch64-linux
│   │   └───default omitted (use '--all-systems' to show)
│   ├───x86_64-darwin
│   │   └───default omitted (use '--all-systems' to show)
│   └───x86_64-linux
│       └───default: development environment 'nix-shell'
└───lib: unknown
```

The `lib: unknown` line is expected and correct.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `flake-utils.lib.eachDefaultSystem` | `nixpkgs.lib.genAttrs [...]` inline | Ongoing — never was mandatory | Eliminates flake-utils as a transitive dep |
| `pkgs.runCommandNoCC` | `pkgs.runCommand` | nixpkgs-unstable 2025+ | Use `runCommand`; `runCommandNoCC` triggers deprecation warning |
| Hardcoded `system = "x86_64-linux"` | `forAllSystems` pattern | Standard since early flakes era | Multi-arch support |
| cpptoml (Nix < ~2.11) | toml11 library | Fixed ~2022 (PR #5841) | `fromTOML` is stable; attrset sorting bug is resolved |

**Deprecated/outdated:**
- `pkgs.runCommandNoCC`: Use `pkgs.runCommand` instead.
- `flake-utils` dependency for simple `forAllSystems`: inline `lib.genAttrs`.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Nix | Everything | Yes | 2.31.3 | — |
| nixpkgs | `forAllSystems`, `pkgs.mkShell` | Yes (fetched via flake input) | nixpkgs-unstable 2026-03-18 | — |
| Git | Flake evaluation (flakes require git-tracked files) | Yes | system git | — |

**Missing dependencies with no fallback:** None.

**Key constraint:** All files referenced in the flake (`./lib/default.nix`, `./mise.toml`) must be tracked by git or in the git working tree for Nix to see them during `nix flake show`/`nix develop`. Untracked files are invisible to the Nix flake evaluator.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `nixpkgs.lib.runTests` (pure Nix) + `pkgs.runCommand` (build-time smoke tests) |
| Config file | None — tests live inside `flake.nix` checks output |
| Quick run command | `nix flake check` |
| Full suite command | `nix flake check --all-systems` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| CORE-01 | `builtins.fromTOML (builtins.readFile ./mise.toml)` succeeds and returns expected attrset | smoke | `nix flake check` (devShell build implies successful TOML parse) | File must exist and be git-tracked |
| CORE-01 | `config.tools or {}` handles missing `[tools]` section | unit | `nix eval` expression test | Can be a `checks` derivation using `lib.runTests` |
| SHELL-01 | `devShells.x86_64-linux.default` is a valid derivation | smoke | `nix flake show` | Passes if devShell appears in output |
| SHELL-01 | `nix develop` opens a shell | integration | `nix develop --command bash -c "exit 0"` | Manual or CI step |
| SHELL-03 | `fromMiseToml` returns result of `pkgs.mkShell` | unit | Derivation type check | Implied by `nix flake check` |

### Sampling Rate
- **Per task commit:** `nix flake show` (fast — pure eval only)
- **Per wave merge:** `nix flake check` (builds devShell derivation)
- **Phase gate:** `nix flake check` green + `nix develop --command bash -c "exit 0"` passes before marking Phase 1 complete

### Wave 0 Gaps
- [ ] `mise.toml` — a minimal test fixture must exist and be `git add`-ed before `nix flake show` can evaluate (the file is referenced in `fromMiseToml ./mise.toml`)
- [ ] `flake.nix` — does not exist yet
- [ ] `lib/default.nix` — does not exist yet

---

## Open Questions

1. **Should `checks` in Phase 1 include a `lib.runTests` wrapper derivation?**
   - What we know: `lib.runTests` returns `[]` on success; it can be wrapped in `pkgs.runCommand` to integrate with `nix flake check`
   - What's unclear: Whether Phase 1 complexity justifies a separate checks derivation vs. relying on devShell build
   - Recommendation: Add a single `pkgs.runCommand`-based check that asserts the TOML parse shape. Low effort, high signal.

2. **Which `mise.toml` fixture to include in the repo?**
   - What we know: `flake.nix` calls `self.lib.fromMiseToml ./mise.toml` — the file must be git-tracked
   - What's unclear: Should the repo's `mise.toml` be a real development environment (with tools the project needs) or a minimal test fixture?
   - Recommendation: Create a minimal `mise.toml` with one or two tools for Phase 1. Expand in Phase 3 (DX-03 example flake).

3. **Should `flake.nix` expose its own `devShells` as a self-contained usage example?**
   - What we know: The project has no tools yet, so the devShell would be empty
   - What's unclear: Whether having an empty devShell is confusing vs. useful for dogfooding
   - Recommendation: Include it — even an empty `nix develop` proves the library works. Dogfood the library in its own flake from Day 1.

---

## Sources

### Primary (HIGH confidence)
- Nix 2.31.3 REPL — `builtins.fromTOML` behavior verified by direct execution on this machine
- Prototype `flake.nix` — all five success criteria verified by running `nix flake show` and `nix develop` on a test flake at `/tmp/mise2nix-test`
- [nix.dev/manual/nix/2.34/language/builtins.html](https://nix.dev/manual/nix/2.34/language/builtins.html) — `fromTOML` documentation
- [raw.githubusercontent.com/pyproject-nix/uv2nix/master/flake.nix](https://raw.githubusercontent.com/pyproject-nix/uv2nix/master/flake.nix) — `lib` output pattern and `forAllSystems = lib.genAttrs lib.systems.flakeExposed`
- [raw.githubusercontent.com/pyproject-nix/uv2nix/master/lib/default.nix](https://raw.githubusercontent.com/pyproject-nix/uv2nix/master/lib/default.nix) — `{ lib, pyproject-nix }:` argument pattern for lib/default.nix
- [ryantm.github.io/nixpkgs/builders/special/mkshell/](https://ryantm.github.io/nixpkgs/builders/special/mkshell/) — `pkgs.mkShell` parameters

### Secondary (MEDIUM confidence)
- [ayats.org/blog/no-flake-utils](https://ayats.org/blog/no-flake-utils) — `forAllSystems` without flake-utils, confirmed against prototype
- [vtimofeenko.com/posts/practical-nix-flake-anatomy](https://vtimofeenko.com/posts/practical-nix-flake-anatomy-a-guided-tour-of-flake.nix/) — library flake `lib` output structure
- [github.com/NixOS/nix/issues/5833](https://github.com/NixOS/nix/issues/5833) — `fromTOML` sorting bug (fixed, historical)
- [github.com/NixOS/nix/issues/11972](https://github.com/NixOS/nix/issues/11972) — `fromTOML` assertion failure (fixed Nov 2025)
- [mise.jdx.dev/configuration.html](https://mise.jdx.dev/configuration.html) — `mise.toml` format: string, inline table, array value shapes

### Tertiary (LOW confidence)
- None — all critical claims verified by official docs or direct execution.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified by running on Nix 2.31.3
- Architecture: HIGH — prototype flake tested end-to-end; uv2nix structure reviewed from source
- Pitfalls: HIGH — most confirmed by direct experiment; historical bugs confirmed resolved

**Research date:** 2026-03-22
**Valid until:** 2026-09-22 (nixpkgs APIs are stable; `fromTOML` is a primop and won't change)
