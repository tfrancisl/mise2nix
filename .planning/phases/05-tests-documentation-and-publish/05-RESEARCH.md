# Phase 05: Tests, Documentation, and Publish - Research

**Researched:** 2026-03-22
**Domain:** Nix flake checks, documentation conventions, flake publishing
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Target reader is a Nix user who knows flakes — assume familiarity with `nix develop`, flake inputs, and `pkgs`. Skip Nix 101.
- **D-02:** README structure: lean — description, quickstart (10-line flake.nix snippet), supported tools table, `fromMiseToml` API reference, limitations. No contributing guide, no troubleshooting section in v1.
- **D-03:** Supported tools table lists all 13 runtimes (with supported versions) and all 18 utilities (flat list). This is the key reference users need.
- **D-04:** `example/` contains a realistic polyglot project: `mise.toml` with node + python + ripgrep + fd + at least one `[env]` var. Demonstrates runtimes, utilities, and env vars all working together.
- **D-05:** Single example (not split into basic/advanced).

### Claude's Discretion
- Flake URL format in README (e.g. `github:owner/repo` — use the actual repo path once known, or use a placeholder)
- Exact git tag process (`git tag v0.1.0` + push)
- Whether 05-01 adds new checks or just documents the 10 existing ones
- README quickstart snippet style (inline flake.nix vs reference to example/)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DX-02 | README documents: what it is, installation, usage, supported tool table, overrides API | README conventions analysis, tool inventory from runtimes.nix + utilities.nix, API signature from lib/default.nix |
| DX-03 | Example flake (`example/`) showing a realistic mise.toml → devShell workflow | example/ structure analysis, standalone flake pattern, forAllSystems pattern from flake.nix |
| DX-04 | Flake outputs interface is stable and versioned (README documents the API contract) | Git tag conventions, github: URL format, flake input pinning patterns |
</phase_requirements>

## Summary

Phase 05 is a documentation and publish phase — no new library features. The 10 existing `nix flake check` derivations cover all major code paths from Phases 1–4. Gap analysis reveals 3 missing test scenarios (integer env vars via builtins.toString, empty `[env]` section, empty `[tools]` section) that are low-risk edge cases given the implementation's simplicity. Adding 1–2 targeted checks is discretionary, not required for the phase to succeed.

The README should be tightly scoped: description, 10-line quickstart, tool table (13 runtimes + 18 utilities), `fromMiseToml` API, and limitations. Comparable Nix library flakes (flake-utils) use function-by-function API docs with type signatures and examples. The `example/` directory must be a standalone flake with its own `flake.nix` referencing `mise2nix` as a flake input.

Publishing a Nix flake is simply `git tag v0.1.0 && git push --tags`. No registry submission is required. Users reference it as `github:OWNER/REPO` (default branch) or `github:OWNER/REPO/v0.1.0` (pinned tag). The `flake.lock` provides reproducibility at the nixpkgs pin level.

**Primary recommendation:** Write one focused implementation plan covering all three deliverables — tests (minor gap fill), README.md, example/, and git tag — since they are small, sequential, and share no dependencies.

## Test Coverage Analysis

### Existing 10 Checks (flake.nix)

| Check Name | What It Tests | Assessment |
|------------|--------------|------------|
| `parse-toml` | TOML read + basic value extraction | Covers CORE-01 |
| `devshell-builds` | fromMiseToml returns derivation at all | Foundational smoke test |
| `runtime-resolution` | Runtime packages resolve (same mise.toml) | Overlaps with `full-integration`; redundant but harmless |
| `resolve-latest` | `"latest"` version string for node/python/go | Covers CORE-03 partial |
| `resolve-utilities` | Utility packages resolve (same mise.toml) | Overlaps with `full-integration`; redundant but harmless |
| `extra-packages` | `extraPackages` argument accepted | Covers CORE-04 (extraPackages path) |
| `overrides-work` | `overrides` argument accepted | Covers CORE-04 (overrides path) |
| `unknown-tool-error` | Single unknown tool throws + `tryEval` catches | Covers DX-01 |
| `env-var-passthrough` | String env vars pass through mkShell | Covers SHELL-02 (string case) |
| `full-integration` | Combined tools + env var with project mise.toml | Integration smoke test |

### Coverage Gaps (discretionary additions)

| Gap | Risk Level | Suggested Check Name |
|-----|-----------|---------------------|
| Integer env var (`PORT = 8080` without quotes in TOML — coerced by builtins.toString) | LOW — env.nix explicitly calls builtins.toString; but the existing `env-var-passthrough` uses quoted string `"8080"`, not bare integer | `integer-env-var` |
| Empty `[tools]` section (no tools key) | LOW — `config.tools or {}` handles this; resolvedPackages would be `[]` | skip — covered by `or {}` pattern |
| Empty `[env]` section | LOW — same `config.env or {}` guard | skip — covered by `or {}` pattern |
| Runtime version mismatch throws (e.g. `node = "18"`) | MEDIUM — unsupported version should throw descriptive error; not yet directly tested | `unsupported-version-error` |

**Recommendation:** Add 1 new check (`unsupported-version-error`) to verify the version-mismatch throw path for runtimes. The integer env var gap is worth testing but is a second-priority addition. All three empty-section cases are adequately covered by the `or {}` guards.

### Integer env var note
The TOML fixture in `env-var-passthrough` uses `PORT = "8080"` (quoted string). Real mise.toml files often use bare integers (`PORT = 8080`). Since `env.nix` applies `builtins.toString`, this works, but it's untested in the current suite. A bare-integer env var check would close this gap.

## Standard Stack

### Core (no new dependencies)
| Component | Version | Purpose | Status |
|-----------|---------|---------|--------|
| nixpkgs | unstable (pinned by flake.lock) | All tool derivations | Already in flake.lock |
| builtins.fromTOML | Nix built-in | TOML parsing | Already used |
| pkgs.mkShell | nixpkgs built-in | devShell assembly | Already used |
| pkgs.runCommand | nixpkgs built-in | check derivations | Already used |

No new package dependencies are introduced in this phase.

### Tools used in this phase
| Tool | Purpose | Command |
|------|---------|---------|
| git | Tag and push v0.1.0 | `git tag v0.1.0 && git push --tags` |
| nix | Verify flake check passes | `nix flake check` |

## Architecture Patterns

### Recommended Project Structure after Phase 05

```
mise2nix/
├── flake.nix            # (updated: 1-2 new checks)
├── flake.lock
├── mise.toml            # (unchanged — project fixture)
├── README.md            # (new: description + quickstart + tool table + API + limitations)
├── lib/
│   ├── default.nix
│   ├── runtimes.nix
│   ├── utilities.nix
│   └── env.nix
└── example/
    ├── flake.nix        # (new: standalone flake, mise2nix as input)
    └── mise.toml        # (new: polyglot — node + python + ripgrep + fd + env var)
```

### Pattern 1: Standalone example/ flake

The `example/` directory must be a self-contained flake — its own `flake.nix` that references `mise2nix` as a flake input. This is how users will actually consume mise2nix, so the example demonstrates the real workflow.

```nix
# example/flake.nix
{
  description = "Example: mise2nix polyglot devShell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    mise2nix.url = "github:OWNER/REPO";         # placeholder until repo is known
    mise2nix.inputs.nixpkgs.follows = "nixpkgs"; # pin to same nixpkgs
  };

  outputs = { self, nixpkgs, mise2nix }:
    let
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs [
        "x86_64-linux" "aarch64-linux"
        "x86_64-darwin" "aarch64-darwin"
      ];
    in {
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; };
        }
      );
    };
}
```

**Key detail:** `mise2nix.inputs.nixpkgs.follows = "nixpkgs"` avoids two copies of nixpkgs being fetched. This is a standard Nix pattern that belongs in the example.

### Pattern 2: README quickstart inline snippet

The README quickstart should be an inline `flake.nix` snippet (10 lines), NOT a reference to `example/`. The example/ is for hands-on use; the README snippet is for skimmable documentation. They will differ only in the `inputs` URL being a real repo URL vs. the example's placeholder.

```nix
# flake.nix (quickstart)
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.mise2nix.url = "github:OWNER/REPO";
  inputs.mise2nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, mise2nix }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"
      ];
    in {
      devShells = forAllSystems (system: {
        default = mise2nix.lib.fromMiseToml ./mise.toml {
          pkgs = nixpkgs.legacyPackages.${system};
        };
      });
    };
}
```

### Pattern 3: API documentation style (from flake-utils precedent)

flake-utils uses function-by-function API docs with type signatures. For mise2nix's single public function, the README API section should follow this pattern:

```
### fromMiseToml

fromMiseToml :: path -> { pkgs, extraPackages?, overrides? } -> derivation

Takes a path to a mise.toml file and returns a mkShell derivation.

Arguments:
  path           — Path to mise.toml (e.g. ./mise.toml)
  pkgs           — nixpkgs package set for the target system
  extraPackages  — (optional) list of additional derivations to include
  overrides      — (optional) attrset of tool name -> derivation replacements

Resolution order: overrides > runtimes > utilities > throw
```

### Anti-Patterns to Avoid
- **`example/` as snippets only:** The example must be a runnable standalone flake, not just code snippets. Users need to be able to `cd example && nix develop`.
- **Skipping `follows = "nixpkgs"`:** Not following nixpkgs in the example causes two copies of nixpkgs to be fetched (large, slow). This is a well-known Nix anti-pattern.
- **Using `flake-utils` in example:** Project decision is no flake-utils. The example must mirror the inline `genAttrs` pattern from the project's own flake.nix.
- **Tagging before `nix flake check` passes:** The git tag should only be created after all checks pass cleanly.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TOML parsing in checks | Custom bash TOML parser | `builtins.fromTOML` (already used) | It's a Nix built-in |
| Error path testing | Re-implementing eval logic | `builtins.tryEval` + `builtins.deepSeq` (already used) | Pattern already established in `unknown-tool-error` check |
| Multi-system iteration | Custom looping | `nixpkgs.lib.genAttrs` (already used) | Matches existing flake.nix pattern |

**Key insight:** All patterns needed for new checks already exist in flake.nix. New checks should replicate the structure of `unknown-tool-error` (for throw-path tests) and `env-var-passthrough` (for value-assertion tests).

## Common Pitfalls

### Pitfall 1: example/flake.lock not committed
**What goes wrong:** `example/` has no `flake.lock`, which means `nix develop` inside example/ requires network access and produces a non-reproducible result. Some CI setups fail on missing lock files.
**Why it happens:** Developers forget that each standalone flake needs its own lock file.
**How to avoid:** Run `nix flake update` inside `example/` after writing the flake.nix to generate `example/flake.lock`. Commit both files.
**Warning signs:** `nix develop` inside `example/` warns "warning: updating lock file".

### Pitfall 2: github: URL format for tags
**What goes wrong:** Using `github:OWNER/REPO?ref=v0.1.0` to pin a tag fails — Nix prefixes `ref=` values with `refs/heads/` (branch namespace), not `refs/tags/`.
**Why it happens:** Known Nix issue (NixOS/nix#8790). The `github:` fetcher does not auto-detect tags vs. branches for the `ref` parameter.
**How to avoid:** Use the third path segment for tags: `github:OWNER/REPO/v0.1.0`. This form accepts both commit hashes and tag names correctly. Alternatively use `git+https://github.com/OWNER/REPO?ref=refs/tags/v0.1.0`.
**For v0.1.0 README:** Document `github:OWNER/REPO` (default branch) as the standard input URL. Pin-by-tag (`github:OWNER/REPO/v0.1.0`) can be shown as an optional stability note.

### Pitfall 3: `builtins.deepSeq` required for lazy throw tests
**What goes wrong:** A new check testing a throw path succeeds when it should fail, because `builtins.tryEval` only shallowly evaluates — nested throw inside nativeBuildInputs is never forced.
**Why it happens:** mkShell is lazy; the package list isn't evaluated until something forces it.
**How to avoid:** Use the established pattern from `unknown-tool-error`: `builtins.tryEval (builtins.deepSeq devShell.nativeBuildInputs devShell)`. This forces deep evaluation before tryEval catches the throw.

### Pitfall 4: Bare integer TOML values in check fixtures
**What goes wrong:** TOML bare integers (e.g. `PORT = 8080` without quotes) are parsed by `builtins.fromTOML` as Nix integers, not strings. Shell variable interpolation in `pkgs.runCommand` requires strings.
**Why it happens:** TOML distinguishes `"8080"` (string) from `8080` (integer); Nix preserves this distinction.
**How to avoid:** `env.nix` already applies `builtins.toString` to all env values. In check derivations that verify env var values, compare against the string form: `"8080"` not `8080`.

### Pitfall 5: README tool table version staleness
**What goes wrong:** The supported versions listed in the README diverge from `lib/runtimes.nix` as the codebase evolves.
**Why it happens:** The table is manually maintained in two places.
**How to avoid:** In the README, note that the table reflects the current nixpkgs-unstable pin. Add a comment in `lib/runtimes.nix` pointing to the README table so future maintainers know to update both.

## Code Examples

Verified patterns from existing flake.nix:

### New check: unsupported-version-error (reuses unknown-tool-error pattern)
```nix
# Source: flake.nix unknown-tool-error check — same tryEval + deepSeq pattern
unsupported-version-error =
  let
    toml = builtins.toFile "bad-version.toml" ''
      [tools]
      node = "18"
    '';
    devShell = self.lib.fromMiseToml toml { inherit pkgs; };
    result = builtins.tryEval (builtins.deepSeq devShell.nativeBuildInputs devShell);
  in pkgs.runCommand "unsupported-version-error" {} ''
    ${if result.success then
      ''echo "FAIL: should have thrown for unsupported node version" && exit 1''
    else
      ''echo "PASS: unsupported version correctly throws error" > $out''
    }
  '';
```

### New check: integer-env-var (reuses env-var-passthrough pattern)
```nix
# Source: flake.nix env-var-passthrough check — same value assertion pattern
integer-env-var =
  let
    toml = builtins.toFile "int-env-test.toml" ''
      [env]
      PORT = 8080
    '';
    devShell = self.lib.fromMiseToml toml { inherit pkgs; };
  in pkgs.runCommand "integer-env-var" {} ''
    if [ "${devShell.PORT}" != "8080" ]; then
      echo "FAIL: PORT expected '8080', got '${devShell.PORT}'"
      exit 1
    fi
    echo "PASS: integer env var coerced to string" > $out
  '';
```

### example/mise.toml (polyglot — expands project mise.toml)
```toml
[tools]
node = "22"
python = "3.11"
ripgrep = "latest"
fd = "latest"

[env]
NODE_ENV = "development"
```

Note: This is nearly identical to the project's existing `mise.toml` fixture. The example may add one more tool (e.g. `go = "1.24"`) to better demonstrate polyglot usage — left to planner's discretion per D-05.

## Supported Tools Inventory

This is the authoritative data for the README tool table, extracted from `lib/runtimes.nix` and `lib/utilities.nix`.

### Runtimes (13 tools, 2 aliases)

| Tool Name | Alias | Supported Versions | Notes |
|-----------|-------|--------------------|-------|
| node | nodejs | 20, 22, 24, 25, latest | latest → pkgs.nodejs |
| python | — | 3.11, 3.12, 3.13, 3.14, 3.15, latest | latest → pkgs.python3 |
| go | golang | 1.24, 1.25, 1.26, latest | latest → pkgs.go |
| ruby | — | 3.3, 3.4, 3.5, 4.0, latest | latest → pkgs.ruby |
| java | — | 8, 11, 17, 21, 25, latest | latest → pkgs.jdk |
| erlang | — | 26, 27, 28, 29, latest | latest → pkgs.erlang |
| elixir | — | 1.15, 1.16, 1.17, 1.18, 1.19, latest | latest → pkgs.elixir |
| php | — | 8.2, 8.3, 8.4, 8.5, latest | latest → pkgs.php |
| rust | — | any (silently maps to pkgs.rustup) | nixpkgs doesn't ship versioned rust; use rustup |
| deno | — | any (silently maps to pkgs.deno) | single version in nixpkgs |
| bun | — | any (silently maps to pkgs.bun) | single version in nixpkgs |
| terraform | — | any (silently maps to pkgs.terraform) | single Terraform 1.x in nixpkgs |
| kubectl | — | any (silently maps to pkgs.kubectl) | single version in nixpkgs |

Total: 13 distinct tools + 2 aliases (nodejs, golang)

### Utilities (18 tools + 1 alias)

| Tool Name | nixpkgs Attr | Notes |
|-----------|-------------|-------|
| ripgrep | pkgs.ripgrep | |
| rg | pkgs.ripgrep | alias for ripgrep |
| fd | pkgs.fd | |
| bat | pkgs.bat | |
| jq | pkgs.jq | |
| fzf | pkgs.fzf | |
| git | pkgs.git | |
| curl | pkgs.curl | |
| wget | pkgs.wget | |
| make | pkgs.gnumake | NOTE: maps to gnumake, not pkgs.make |
| cmake | pkgs.cmake | |
| gh | pkgs.gh | |
| delta | pkgs.delta | |
| eza | pkgs.eza | |
| zoxide | pkgs.zoxide | |
| starship | pkgs.starship | |
| just | pkgs.just | |
| hyperfine | pkgs.hyperfine | |
| tokei | pkgs.tokei | |

Total: 18 distinct tools + 1 alias (rg)

### Limitations to document in README

1. **Version precision:** mise2nix maps to nixpkgs major/minor versions. Exact patch versions are not available (nixpkgs ships one patch per major/minor at any given pin).
2. **Single-version tools:** rust, deno, bun, terraform, kubectl — any version string is accepted and silently maps to the single version in nixpkgs at the current pin.
3. **No mise.local.toml support:** Local override files are not merged (v2 roadmap).
4. **No [tasks] support:** Task runner is not implemented (v2 roadmap).
5. **No npm:, pipx:, or GitHub release tools:** Only core runtimes and CLI utilities (v2 roadmap).
6. **System coverage:** x86_64-linux, aarch64-linux, x86_64-darwin, aarch64-darwin only.

## Git Tag and Publish Process

**Confidence:** HIGH (verified against standard Nix ecosystem practice)

Publishing a Nix flake requires no registry submission. The process is:

```bash
# 1. Verify all checks pass
nix flake check

# 2. Create and push the tag
git tag v0.1.0
git push origin v0.1.0
```

Users then reference the flake as:
- Default branch (latest): `inputs.mise2nix.url = "github:OWNER/REPO";`
- Pinned tag: `inputs.mise2nix.url = "github:OWNER/REPO/v0.1.0";`

The `github:OWNER/REPO/v0.1.0` form uses the third path segment, which correctly resolves both commit hashes and tag names (avoids the `refs/heads/` bug with `?ref=`).

**FlakeHub:** Deterministic Systems FlakeHub offers additional discoverability but is optional. Not required for v0.1.0. Document in README as optional.

**flake.lock in example/:** The `example/` directory needs its own `flake.lock` generated by `nix flake update` run inside the `example/` directory. This pins the example's nixpkgs and mise2nix inputs and makes the example reproducible.

## Environment Availability

Step 2.6: Dependencies for this phase are minimal — git tagging and writing files. No external build services or databases required.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| git | DX-04 (tag v0.1.0) | Expected yes | Standard tool |
| nix | Check verification | Expected yes | Already used throughout project |
| Write access to git remote | DX-04 (push tag) | Expected yes | Implementation agent must have push access configured |

No blocking external dependencies.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `nix flake check` (Nix built-in — no separate test framework) |
| Config file | `flake.nix` (`checks` output attribute) |
| Quick run command | `nix flake check --no-build` (eval only) |
| Full suite command | `nix flake check` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | Check Exists? |
|--------|----------|-----------|-------------------|---------------|
| DX-02 | README.md exists with required sections | manual | `ls README.md && grep -q "fromMiseToml" README.md` | No — Wave 0 |
| DX-03 | example/ contains standalone flake + mise.toml | manual | `ls example/flake.nix example/mise.toml` | No — Wave 0 |
| DX-03 | example/flake.nix evaluates without error | smoke | `nix flake check example/` | No — Wave 0 |
| DX-04 | git tag v0.1.0 exists | manual | `git tag --list v0.1.0` | No — Wave 0 |
| (all) | All 10 existing checks pass | integration | `nix flake check` | Yes (10 checks) |
| (new) | Unsupported runtime version throws | unit | `nix flake check .#checks.x86_64-linux.unsupported-version-error` | No — Wave 0 |

### Sampling Rate
- **Per task:** `nix flake check --no-build` (eval-only, fast)
- **Per wave merge:** `nix flake check` (full build, all systems)
- **Phase gate:** Full `nix flake check` green + `ls README.md example/flake.nix` before close

### Wave 0 Gaps
- [ ] `unsupported-version-error` check in `flake.nix` — covers version-mismatch throw path
- [ ] `integer-env-var` check in `flake.nix` (optional) — covers bare integer TOML env value
- [ ] `README.md` — covers DX-02 and DX-04
- [ ] `example/flake.nix` and `example/mise.toml` — covers DX-03
- [ ] `example/flake.lock` — generated by `nix flake update` in `example/`

## Open Questions

1. **Actual GitHub repo owner/name**
   - What we know: The README and example/flake.nix need a real `github:OWNER/REPO` URL
   - What's unclear: Repository URL is not yet in project files
   - Recommendation: Use `github:OWNER/REPO` as a placeholder throughout; implementation agent should replace with the real URL during the README/example tasks

2. **Should example/ include `go = "1.24"` or stay with node + python only?**
   - What we know: D-04 says "node + python + ripgrep + fd + at least one [env] var"; the existing mise.toml fixture already covers this
   - What's unclear: Whether adding go makes the polyglot story more compelling
   - Recommendation: Add `go = "1.24"` to example/mise.toml to show three runtimes — makes the "polyglot" claim concrete without complicating the example

3. **Should `integer-env-var` check be added?**
   - What we know: The existing `env-var-passthrough` test uses quoted strings; bare integers are untested
   - What's unclear: How often real mise.toml files use bare integer env vars vs. quoted strings
   - Recommendation: Add it — it's 10 lines and closes a known gap; but it is optional, not blocking

## Sources

### Primary (HIGH confidence)
- Verified directly from source files: `flake.nix`, `lib/runtimes.nix`, `lib/utilities.nix`, `lib/default.nix`, `lib/env.nix` — all tool names, versions, and API signatures extracted from these
- Nix Reference Manual (nix.dev/manual/nix/2.18): github: URL format verified — `github:<owner>/<repo>(/<rev-or-ref>)?`
- NixOS Discourse / NixOS/nix#8790: tag vs. branch `ref=` bug confirmed

### Secondary (MEDIUM confidence)
- flake-utils README (github.com/numtide/flake-utils): API documentation style reference — function-per-section with type signatures
- uv2nix README (github.com/pyproject-nix/uv2nix): Confirms minimal README approach is acceptable for Nix library flakes; substantive docs go in docs site or inline

### Tertiary (LOW confidence — not needed for planning)
- None

## Metadata

**Confidence breakdown:**
- Test coverage analysis: HIGH — derived from reading actual source files
- Tool inventory (runtimes + utilities): HIGH — extracted directly from runtimes.nix and utilities.nix
- API signature: HIGH — extracted directly from lib/default.nix
- Flake URL conventions: HIGH — verified against Nix reference manual
- README structure: MEDIUM — based on comparable projects (flake-utils); no single authoritative spec
- Pitfalls: HIGH (Pitfall 2 tag format) / HIGH (Pitfall 3 deepSeq) — verified from Nix docs and existing code
- example/ structure: HIGH — matches CONTEXT.md D-05 explicit decision

**Research date:** 2026-03-22
**Valid until:** 2026-06-22 (stable domain — nixpkgs tool versions may shift but conventions won't)
