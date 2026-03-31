# Decisions

- 2026-03-30: API renamed `fromMiseToml` → `mkShellFromMise`; `mkShellInputsFromMise` added as public escape hatch returning `{envVars, packages, shellHook}` for callers who need to compose their own shell
- 2026-03-30: `mkShellFromMise` args extended with `prefixShellHook`, `postfixShellHook`, `extraPackages`, `extraEnvVars` — lets callers augment the shell without losing mise2nix-managed env vars
- 2026-03-30: `forAllSystems` uses `nixpkgs.lib.systems.flakeExposed` (not an explicit 4-system list) — distributing as a flake means we should expose all systems nixpkgs supports
- 2026-03-30: `MISE_AUTO_INSTALL = "false"` and `MISE_EXEC_AUTO_INSTALL = "false"` kept alongside `MISE_OFFLINE = "1"` — may be redundant; exact overlap with MISE_OFFLINE not confirmed

- 2026-03-24: Walk up from PWD to filesystem root to find flake.nix; skip patching with warning if not found — avoids surprises in monorepos or unexpected working directories
- 2026-03-24: flake.nix patching uses pure shell/sed; missing overrides block prints hint rather than fragile injection — AST manipulation is too complex for pure Nix
- 2026-03-24: Interactive prompt reads from /dev/tty (not stdin); empty input or Ctrl-C aborts with no file modifications — prevents accidental writes when stdin is piped
- 2026-03-24: Known-tool lists derived from builtins.attrNames on backend attrsets at Nix eval time, interpolated into bash — zero drift between tables and shell detection logic
- 2026-03-24: Duplicate miseWrapper inline in flake.nix check let blocks — miseWrapper is local to fromMiseToml closure and cannot be accessed from flake.nix checks
- 2026-03-24: cp toFile fixture + chmod +w before sed-based in-place mutation in runCommand checks — builtins.toFile produces read-only Nix store files
- 2026-03-24: Use builtins.seq devShell.drvPath null (not deepSeq nativeBuildInputs) to force mkShell eval in tryEval error checks — avoids stack overflow
- 2026-03-24: resolveBackend throws two distinct errors: unknown backend (naming supported list) and unmapped tool within known backend — clearer UX than a single generic error
- 2026-03-24: overrides.${name} check precedes isBackend branch — ensures overrides win for pipx:black and plain keys alike
- 2026-03-24: backend tables store plain packages not functions; version is ignored for backend resolution — nixpkgs pin is the version
- 2026-03-24: Use $VAR (no braces) for simple bash variable names in Nix ''...'' echo strings — avoids Nix interpolation parser conflicts with ${...}
- 2026-03-24: Use pkgs.gnugrep not pkgs.grep — correct nixpkgs attribute name for GNU grep
- 2026-03-24: pkgs.mise replaced by miseWrapper (writeShellScriptBin) in every devShell — wrapper intercepts mise use for Nix-managed tool resolution
- 2026-03-24: MISE_NOT_FOUND_AUTO_INSTALL=false injected into every devShell — prevents mise from silently downloading tools outside Nix
- 2026-03-24: builtins.toFile used for inline TOML fixtures in checks — avoids IFD and keeps checks self-contained
- 2026-03-24: Resolution cascade order: overrides → runtimes → utilities → throw
- 2026-03-24: Single-version runtimes (rust, deno, bun, terraform, kubectl) silently map all version strings — no version-specific nixpkgs attrs exist for these
- 2026-03-24: No flake-utils dependency — inline a simple forAllSystems directly (see 2026-03-30 entry for current forAllSystems implementation)
- 2026-03-24: lib output is NOT wrapped in forAllSystems — fromMiseToml takes pkgs as argument so callers control the system
