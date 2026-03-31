# mise2nix

Converts `mise.toml` into a Nix devShell — no manual Nix required for common toolsets.

```nix
mise2nix.lib.mkShellFromMise { tomlPath = ./mise.toml; inherit pkgs; }
```

Inspired by [uv2nix](https://github.com/pyproject-nix/uv2nix): consume a configuration file, get Nix.

---

## Quickstart

This flake provides a simple template which can be initialized with `nix flake init -t git+https://codeberg.org/tttffflll/mise2nix`.

Alternatively, add mise2nix as a flake input and wire `mkShellFromMise` into your `devShells`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    mise2nix = {
      url = "git+https://codeberg.org/tttffflll/mise2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    mise2nix,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
  in {
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = mise2nix.lib.mkShellFromMise {
            tomlPath = ./mise.toml;
            inherit pkgs;
          };
      }
    );
  };
}

```

Then run `nix develop` — mise2nix reads your `mise.toml` and builds the shell.

---

## Supported Tools

### Runtimes

Version-specific nixpkgs attributes. Specify major (or major.minor) version in `mise.toml`.

| Tool (mise name) | Supported versions | Notes |
|------------------|--------------------|-------|
| `node` / `nodejs` | 20, 22, 24, 25 | `"latest"` → `pkgs.nodejs` |
| `python` | 3.11, 3.12, 3.13, 3.14, 3.15 | `"latest"` → `pkgs.python3` |
| `go` / `golang` | 1.24, 1.25, 1.26 | `"latest"` → `pkgs.go` |
| `ruby` | 3.3, 3.4, 3.5, 4.0 | `"latest"` → `pkgs.ruby` |
| `java` | 8, 11, 17, 21, 25 | `"latest"` → `pkgs.jdk` |
| `erlang` | 26, 27, 28, 29 | `"latest"` → `pkgs.erlang` |
| `elixir` | 1.15, 1.16, 1.17, 1.18, 1.19 | `"latest"` → `pkgs.elixir` |
| `php` | 8.2, 8.3, 8.4, 8.5 | `"latest"` → `pkgs.php` |
| `rust` | any | Always resolves to `pkgs.rustup` |
| `deno` | any | Single version in nixpkgs |
| `bun` | any | Single version in nixpkgs |
| `terraform` | any | Single version in nixpkgs |
| `kubectl` | any | Single version in nixpkgs |

### Utilities

All utility versions resolve to the nixpkgs-pinned version (version string is ignored).

`bat`, `cmake`, `curl`, `delta`, `eza`, `fd`, `fzf`, `gh`, `git`, `hyperfine`, `jq`, `just`, `make`, `ripgrep` / `rg`, `starship`, `tokei`, `wget`, `zoxide`

---

## API Reference

### `mkShellFromMise`

```
mkShellFromMise : { tomlPath, pkgs, overrides ? {}, extraPackages ? [], extraEnvVars ? {}, prefixShellHook ? "", postfixShellHook ? "" } -> derivation
```

| Argument | Type | Description |
|----------|------|-------------|
| `tomlPath` | path | Path to your `mise.toml` file |
| `pkgs` | attrset | nixpkgs package set for the target system |
| `overrides` | attrset | Replace a tool's resolved package by mise tool name |
| `extraPackages` | list | Additional packages appended to the devShell |
| `extraEnvVars` | attrset | Additional environment variables merged into the shell |
| `prefixShellHook` | string | Shell script prepended to the generated `shellHook` |
| `postfixShellHook` | string | Shell script appended to the generated `shellHook` |

**Resolution order:** `overrides` → runtimes → utilities → `builtins.throw`

Unknown tools without an override throw a descriptive error at eval time naming the tool and explaining how to fix it.

### `mkShellInputsFromMise`

For advanced use cases where you need to compose the shell yourself:

```
mkShellInputsFromMise : { tomlPath, pkgs, overrides ? {} } -> { packages, shellHook, envVars }
```

Returns the raw inputs (`packages`, `shellHook`, `envVars`) rather than a fully built `mkShell` derivation.

### Overrides pattern

Override a single tool (e.g. pin node to a different version than mise.toml requests):

```nix
mise2nix.lib.mkShellFromMise {
  tomlPath = ./mise.toml;
  inherit pkgs;
  overrides = { node = pkgs.nodejs_20; };
}
```

Add packages not present in mise.toml (e.g. a GitHub release tool):

```nix
mise2nix.lib.mkShellFromMise {
  tomlPath = ./mise.toml;
  inherit pkgs;
  extraPackages = [ pkgs.some-other-tool ];
}
```

### Environment variables

The `[env]` section in `mise.toml` is mapped directly to `mkShell` environment variables:

```toml
[env]
NODE_ENV = "development"
PORT = 8080
```

Both string and integer values are supported (integers are coerced to strings).

---

## Limitations

- **No `[tasks]` section** — task runner support comes later. Tasks are ignored. YMMV using tasks with the mise binary out of the box.
- **No exact patch versions (without overrides)** — nixpkgs pin determines the exact version installed. Reproducibility comes from pinning `nixpkgs` in your `flake.lock`, not from mise version strings.
- **No `mise.lock` support** — mise.lock tracks mise's own downloads; it is not used for nixpkgs resolution.
- **Limited compat with other dev shell tools** — `mkShellFromMise` produces a fully built `pkgs.mkShell`. Use `mkShellInputsFromMise` if you need to compose inputs into your own `mkShell`.
- **nixpkgs only (without overrides)** — npm-backend, GitHub release, and pipx tools are not resolved automatically. Use `extraPackages` or `overrides` in `mkShellFromMise` for these.
- **Single version per tool (without overrides)** — tools like `rust`, `deno`, `bun`, `terraform`, and `kubectl` have one version in nixpkgs; the version string in `mise.toml` is ignored.
- **Unknown tool** — requesting a tool not in the runtimes or utilities table (and not covered by `overrides`) causes a `builtins.throw` at eval time.


# License

This software is dual-licensed under the **European Union Public License 1.2 (EUPL-1.2)** and the **GNU Affero General Public License v3.0 (AGPL-3.0)**. You may use, modify, and distribute this software under the terms of either license, at your option.

`SPDX-License-Identifier: EUPL-1.2 OR AGPL-3.0-only`
