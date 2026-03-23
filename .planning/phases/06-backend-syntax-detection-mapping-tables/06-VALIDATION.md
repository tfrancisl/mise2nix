---
phase: 6
slug: backend-syntax-detection-mapping-tables
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `nix flake check` (derivation-based checks) |
| **Config file** | `flake.nix` — `checks` output |
| **Quick run command** | `nix flake check --no-build` |
| **Full suite command** | `nix flake check` |
| **Estimated runtime** | ~5s (eval-only), ~60s (full build) |

---

## Sampling Rate

- **After every task commit:** Run `nix flake check --no-build` (eval-only, ~5s — catches missing attrs and type errors immediately)
- **After every plan wave:** Run `nix flake check` (full build, verifies derivations succeed)
- **Before `/gsd:verify-work`:** Full suite must be green

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| create backends/ | 01 | 1 | BACKEND-02,03,04 | smoke | `nix flake check --no-build` | ❌ Wave 0 | ⬜ pending |
| extend resolve | 01 | 1 | BACKEND-01 | smoke | `nix flake check --no-build` | ❌ Wave 0 | ⬜ pending |
| unknown backend error | 01 | 1 | BACKEND-05 | smoke | `nix flake check --no-build` | ❌ Wave 0 | ⬜ pending |
| add checks | 01 | 2 | BACKEND-01–05 | integration | `nix flake check` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `flake.nix` — add `resolve-pipx-black`, `resolve-npm-prettier`, `resolve-cargo-ripgrep` check derivations (one per backend to confirm routing)
- [ ] `flake.nix` — add `unknown-backend-error` check: `builtins.tryEval` on a devShell with `"ubi:some-tool"` must return `success = false`
- [ ] `flake.nix` — add `unmapped-tool-error` check: `builtins.tryEval` on a devShell with `"pipx:nonexistent"` must return `success = false`
- [ ] `flake.nix` — add `backend-overrides-win` check: `overrides."pipx:black" = pkgs.hello` should produce devShell with hello, not python3Packages.black

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| TOML quoting of `backend:tool` keys | BACKEND-01 | Requires a real mise.toml written by mise, not inline fixture | Write `pipx:black = "latest"` in mise.toml; run `nix flake check` to confirm builtins.fromTOML parses it |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s (eval-only path)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
