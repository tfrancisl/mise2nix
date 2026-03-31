# Ideas

## Deferred to v0.3.0+

- [tasks] section: convert `[tasks]` entries to shell scripts available in the devShell (TASK-01, TASK-02) — task runner integration is a separate concern from tool resolution
- Automated nixpkgs attribute lookup (EXT-01) — avoid manual table maintenance; tables currently curated by hand
- GitHub release tools via fetchurl + checksums from mise.lock (EXT-02) — too complex for v0.1.0/v0.2.0; currently handled via overrides escape hatch
- direnv reload triggered automatically after `mise use` (EXT-03) — deferred; interactive reload message is the current UX
- mise.local.toml merged with mise.toml, local takes precedence (LOCAL-01) — common mise workflow not yet supported

## Out of Scope

- flake-utils dependency — adds a transitive dep for trivial forAllSystems; inline it instead
- devenv / home-manager output — not the intended workflow
- Exact patch-version fetching — nixpkgs pin provides reproducibility; fetchurl approach is too complex
- mise.lock as primary version source — tracks mise's own downloads, not nixpkgs versions
- CLI code generator — library model is more composable and Nix-idiomatic
- ubi:/gh: automated resolution — handled via interactive override prompt for now
