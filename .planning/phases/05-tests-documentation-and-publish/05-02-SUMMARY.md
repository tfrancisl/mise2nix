---
phase: "05"
plan: "02"
subsystem: documentation
tags: [readme, documentation, api-reference, tool-table]
dependency_graph:
  requires: [05-01]
  provides: [README.md]
  affects: []
tech_stack:
  added: []
  patterns: [markdown documentation, Nix flake quickstart snippet]
key_files:
  created: [README.md]
  modified: []
decisions:
  - README targets Nix flake users — skips Nix 101, assumes familiarity with nix develop and flake inputs
  - Tool table lists all 13 runtimes with supported versions and all 18 utilities as a flat list
  - Quickstart uses inline flake.nix snippet (not reference to example/) per D-02 and D-03
  - Flake URL uses github:OWNER/REPO placeholder (actual repo path not yet known)
  - Limitations section covers no-tasks, nixpkgs-pin reproducibility, no exact patch versions, unknowns need extraPackages/overrides
metrics:
  duration: "1min"
  completed: "2026-03-23"
  tasks: 1
  files: 1
---

# Phase 05 Plan 02: Write README.md Summary

**One-liner:** README.md written for Nix flake users with quickstart snippet, runtime/utility tool table (13 runtimes + 18 utilities), fromMiseToml API reference, overrides pattern, and limitations section.

## What Was Built

Created `README.md` at the project root with the following structure:

1. **Description** — one-liner + core value proposition, inspired-by link to uv2nix
2. **Quickstart** — 10-line `flake.nix` snippet showing the complete `forAllSystems` pattern, ready to copy-paste
3. **Supported Tools table** — all 13 runtimes with their supported version strings and nixpkgs resolution notes, plus all 18 utilities as a flat list
4. **API Reference** — `fromMiseToml` signature, argument table, resolution order explanation, overrides pattern examples, env var section
5. **Limitations** — no `[tasks]` section, no exact patch versions, no `mise.lock` support, nixpkgs-only, single-version-per-tool tools, unknown tool behavior

## Verification

README.md exists at project root with all required sections per 05-CONTEXT.md decisions D-01 through D-05.

## Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Write README.md with full documentation | 54871a6 | README.md |

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

- `github:OWNER/REPO` flake URL placeholder — the actual repository URL is not yet established. This is intentional; 05-03 (publish) will resolve when the git tag and remote are set.

## Self-Check: PASSED

- README.md exists at /home/freya/code/mise2nix/.claude/worktrees/agent-a1e833ba/README.md: confirmed
- Commit 54871a6 exists: confirmed (git log shows docs(05-02) commit)
- Tool table covers all 13 runtimes and 18 utilities: confirmed by review
