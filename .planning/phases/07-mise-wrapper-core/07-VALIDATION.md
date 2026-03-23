---
phase: 7
slug: mise-wrapper-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `nix flake check` (existing pattern) |
| **Config file** | `flake.nix` checks attribute |
| **Quick run command** | `nix build .#checks.x86_64-linux.<specific-check>` |
| **Full suite command** | `nix flake check` |
| **Estimated runtime** | ~30 seconds (full suite) |

---

## Sampling Rate

- **After every task commit:** Run targeted `nix build .#checks.x86_64-linux.<check>`
- **After every plan wave:** Run `nix flake check`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 7-01-01 | 01 | 0 | WRAP-01 | unit (eval) | `nix build .#checks.x86_64-linux.wrapper-in-packages` | ❌ W0 | ⬜ pending |
| 7-01-02 | 01 | 0 | WRAP-02 | integration | `nix build .#checks.x86_64-linux.wrapper-use-writes-toml` | ❌ W0 | ⬜ pending |
| 7-01-03 | 01 | 0 | DX-05 | integration | `nix build .#checks.x86_64-linux.wrapper-use-prints-message` | ❌ W0 | ⬜ pending |
| 7-01-04 | 01 | 0 | DX-06 | integration | `nix build .#checks.x86_64-linux.wrapper-passthrough` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `flake.nix` — add `wrapper-in-packages` check (WRAP-01)
- [ ] `flake.nix` — add `wrapper-use-writes-toml` check (WRAP-02)
- [ ] `flake.nix` — add `wrapper-use-prints-message` check (DX-05)
- [ ] `flake.nix` — add `wrapper-passthrough` check (DX-06)

All four checks are new entries in the `flake.nix` checks attrset. No separate test framework install needed — uses existing `pkgs.runCommand` / `nativeBuildInputs` pattern.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `direnv reload` suggestion when `DIRENV_DIR` is set | DX-05 | Nix sandbox cannot set `DIRENV_DIR` at eval time | Run `nix develop` in a direnv-enabled shell; verify message suggests `direnv reload` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
