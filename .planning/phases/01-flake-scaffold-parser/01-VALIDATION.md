---
phase: 1
slug: flake-scaffold-parser
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `nix flake check` + `pkgs.runCommand` checks derivations |
| **Config file** | `flake.nix` (checks output) |
| **Quick run command** | `nix build .#checks.x86_64-linux.parse-toml --no-link` |
| **Full suite command** | `nix flake check` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `nix build .#checks.$(nix eval --impure --expr builtins.currentSystem).parse-toml --no-link`
- **After every plan wave:** Run `nix flake check`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01-01 | 1 | SHELL-01 | integration | `nix flake show 2>&1 \| grep devShells` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01-02 | 1 | CORE-01 | unit | `nix build .#checks.x86_64-linux.parse-toml --no-link` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01-02 | 1 | SHELL-03 | integration | `nix develop --command true` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `mise.toml` — minimal fixture file for TOML parsing tests (e.g., `[tools]\nnode = "22"`)
- [ ] `flake.nix` checks output with `parse-toml` and `devshell-builds` derivations

*Both created in plan wave 1 as part of the deliverables — no separate Wave 0 setup needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `nix develop` opens interactive shell | SHELL-01 | Requires interactive TTY | Run `nix develop` in repo root; verify shell opens |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
