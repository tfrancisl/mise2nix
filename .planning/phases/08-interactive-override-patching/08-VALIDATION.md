---
phase: 8
slug: interactive-override-patching
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | nix flake check / nix-instantiate --parse / bash unit tests |
| **Config file** | none — existing nix build infra |
| **Quick run command** | `nix-instantiate --parse flake.nix` |
| **Full suite command** | `nix build .#miseWrapper 2>&1` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `nix-instantiate --parse flake.nix`
- **After every plan wave:** Run `nix build .#miseWrapper 2>&1`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 8-01-01 | 01 | 1 | WRAP-03 | unit | `nix-instantiate --parse flake.nix` | ✅ | ⬜ pending |
| 8-01-02 | 01 | 1 | WRAP-03 | integration | `MISE2NIX_ATTR=ripgrep nix build .#miseWrapper && echo OK` | ✅ | ⬜ pending |
| 8-01-03 | 01 | 2 | WRAP-03 | integration | `nix build .#miseWrapper && mise use ubi:ripgrep` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `MISE2NIX_ATTR` env-var bypass pattern verified in test context
- [ ] `nix-instantiate --parse` available in dev shell

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Interactive TTY prompt | WRAP-03 | Requires `/dev/tty` — not available in Nix sandbox | Run `mise use ubi:some-tool` in a real terminal; verify prompt appears |
| Ctrl-C cancellation | WRAP-03 | Requires live TTY signal | Run `mise use ubi:some-tool`, press Ctrl-C; verify no file changes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
