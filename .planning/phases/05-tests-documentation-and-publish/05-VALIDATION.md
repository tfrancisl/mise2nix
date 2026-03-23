---
phase: 05
slug: tests-documentation-and-publish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `nix flake check` + manual README/example review |
| **Config file** | `flake.nix` (checks output) |
| **Quick run command** | `nix flake check` |
| **Full suite command** | `nix flake check && nix develop --command bash -c "exit 0"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `nix flake check` (catches regressions from any lib or flake.nix edits)
- **After every plan wave:** Run `nix flake check` + verify new artifacts exist on disk
- **Before `/gsd:verify-work`:** Full suite must be green; README and example must exist
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 05-01-01 | 01 | 1 | DX-02 | nix flake check | `nix build .#checks.x86_64-linux.unsupported-version-error --no-link` | ⬜ pending |
| 05-02-01 | 02 | 2 | DX-02 | file exists | `test -f README.md` | ⬜ pending |
| 05-03-01 | 03 | 3 | DX-03 | file exists | `test -f example/flake.nix && test -f example/mise.toml` | ⬜ pending |
| 05-03-02 | 03 | 3 | DX-04 | git tag | `git tag --list v0.1.0` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all automated checks. No new test framework needed.

*Wave 0 not required — adding checks inline in 05-01.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| README content quality | DX-02 | Prose quality can't be grep-verified | Read README.md and confirm it has: description, quickstart snippet, tool table (all runtimes+utilities), fromMiseToml API, limitations section |
| example/ works end-to-end | DX-03 | Requires running nix develop inside example/ | `cd example && nix develop --command bash -c "node --version && python3 --version && rg --version"` |
| Git tag pushed | DX-04 | Requires push access | `git log --oneline --decorate | head -3` to confirm v0.1.0 tag |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
