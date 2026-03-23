---
phase: 02
slug: runtime-tool-resolution
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `nix flake check` + `nix build .#checks.x86_64-linux.*` |
| **Config file** | `flake.nix` (checks output) |
| **Quick run command** | `nix build .#checks.x86_64-linux.parse-toml .#checks.x86_64-linux.devshell-builds --no-link` |
| **Full suite command** | `nix flake check` |
| **Estimated runtime** | ~10 seconds (cached) |

---

## Sampling Rate

- **After every task commit:** Run `nix flake check`
- **After every plan wave:** Run `nix flake check` + `nix develop --command bash -c "exit 0"`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 02-01-01 | 01 | 1 | CORE-02 | nix eval | `nix eval .#lib.fromMiseToml --apply "f: builtins.typeOf f"` | ⬜ pending |
| 02-01-02 | 01 | 1 | CORE-02 | nix build | `nix build .#checks.x86_64-linux.runtime-resolution --no-link` | ⬜ pending |
| 02-02-01 | 02 | 2 | CORE-02, CORE-03 | nix develop | `nix develop --command bash -c "which node"` | ⬜ pending |
| 02-02-02 | 02 | 2 | CORE-03 | nix flake check | `nix flake check` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `flake.nix` checks output — add `runtime-resolution` check derivation that verifies a sample tool (e.g. `node = "22"`) resolves to the correct package

*Existing infrastructure (`nix flake check`, Phase 1 checks) covers base validation. Wave 0 adds a new check for runtime resolution.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `builtins.throw` error message content | CORE-02 (D-01, D-02) | Nix eval errors go to stderr; automated checks can't easily assert message text | Run `nix eval --expr '(import ./lib {lib=import <nixpkgs/lib>;}).fromMiseToml ./mise.toml {pkgs=(import <nixpkgs>{});}' 2>&1` with a mise.toml containing an unsupported version; confirm error names the tool, requested version, and supported versions |
| `"latest"` falls through without error | CORE-03 | Requires Phase 3 utility resolver stub to be in place | After Phase 2 complete, verify `node = "latest"` in mise.toml does not throw during eval |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
