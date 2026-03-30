# Wrapper that intercepts `mise use` and passes all other subcommands through
# to the real mise binary unchanged (WRAP-01, DX-06).
#
# For `mise use` with a known/mapped backend:tool: writes the entry to mise.toml
# and prints a reload message (WRAP-02, DX-05).
#
# For `mise use` with an unknown backend or unmapped tool within a known backend:
# prompts interactively for a nixpkgs attribute and patches the nearest flake.nix
# overrides block (WRAP-03).
{
  pkgs,
  pipxKnown,
  npmKnown,
  cargoKnown,
  ...
}:
pkgs.writeShellScriptBin "mise" ''
  if [ "$1" = "install" ]; then
    # Run real mise install, capturing combined output to filter known read-only errors.
    # The Nix store is immutable so symlink rebuilds always fail — this is expected.
    INSTALL_OUT="$(${pkgs.mise}/bin/mise "$@" 2>&1)"
    FILTERED="$(printf '%s\n' "$INSTALL_OUT" \
      | ${pkgs.gnugrep}/bin/grep -v 'failed to rebuild runtime symlinks' \
      | ${pkgs.gnugrep}/bin/grep -v 'failed to ln -sf' \
      | ${pkgs.gnugrep}/bin/grep -v 'Read-only file system')"
    [ -n "$FILTERED" ] && printf '%s\n' "$FILTERED"

    if [ -n "''${DIRENV_DIR:-}" ]; then
      RELOAD_CMD="direnv reload"
    else
      RELOAD_CMD="nix develop"
    fi
    echo "[mise2nix] Tools are Nix-managed. Run \`''${RELOAD_CMD}\` to activate any new tools."
    exit 0
  fi

  if [ "$1" != "use" ]; then
    exec ${pkgs.mise}/bin/mise "$@"
  fi

  # Handle: mise use [flags] TOOL_SPEC
  shift  # remove "use" from args

  TOOL_SPEC=""
  for arg in "$@"; do
    case "$arg" in
      -*) ;;
      *) TOOL_SPEC="$arg"; break ;;
    esac
  done

  if [ -z "$TOOL_SPEC" ]; then
    exec ${pkgs.mise}/bin/mise use "$@"
  fi

  if [[ "$TOOL_SPEC" == *@* ]]; then
    VERSION="''${TOOL_SPEC##*@}"
    TOOL="''${TOOL_SPEC%@*}"
  else
    VERSION="latest"
    TOOL="$TOOL_SPEC"
  fi

  # Detect whether this is a backend:tool spec and whether it is known/mapped (D-03).
  # Known tool lists are derived from Nix attrsets at build time (D-02).
  PIPX_KNOWN="${pipxKnown}"
  NPM_KNOWN="${npmKnown}"
  CARGO_KNOWN="${cargoKnown}"

  NEEDS_PROMPT=0
  if [[ "$TOOL" == *:* ]]; then
    BACKEND="''${TOOL%%:*}"
    BARE_TOOL="''${TOOL#*:}"
    if [[ "$BACKEND" != "pipx" && "$BACKEND" != "npm" && "$BACKEND" != "cargo" ]]; then
      # Unknown backend (ubi:, gh:, etc.)
      NEEDS_PROMPT=1
    else
      # Known backend — check if the bare tool name is in the known list
      case "$BACKEND" in
        pipx) KNOWN_LIST="$PIPX_KNOWN" ;;
        npm)  KNOWN_LIST="$NPM_KNOWN"  ;;
        cargo) KNOWN_LIST="$CARGO_KNOWN" ;;
      esac
      FOUND=0
      for k in $KNOWN_LIST; do
        if [ "$k" = "$BARE_TOOL" ]; then
          FOUND=1
          break
        fi
      done
      if [ "$FOUND" -eq 0 ]; then
        # Unmapped tool within a known backend
        NEEDS_PROMPT=1
      fi
    fi
  fi

  if [ "$NEEDS_PROMPT" -eq 1 ]; then
    # Interactive prompt for unknown/unmapped tools (WRAP-03).
    # Trap SIGINT (Ctrl-C) to abort cleanly with no file modifications.
    _mise2nix_cancel() {
      echo ""
      echo "[mise2nix] Cancelled."
      exit 0
    }
    trap _mise2nix_cancel INT

    printf "[mise2nix] '%s' is not in the Nix backend tables.\n" "$TOOL"
    printf "Enter nixpkgs attribute for '%s' (e.g. ripgrep or pkgs.ripgrep, Enter to cancel): " "$TOOL"
    read -r NIX_ATTR </dev/tty

    trap - INT

    # Empty input → abort cleanly (D-06)
    if [ -z "$NIX_ATTR" ]; then
      echo "[mise2nix] Cancelled."
      exit 0
    fi

    # Strip leading pkgs. prefix if present (D-04)
    ATTR_NAME="''${NIX_ATTR#pkgs.}"

    # Write entry to mise.toml (same as known path)
    TOML_FILE="''${MISE_CONFIG_FILE:-mise.toml}"
    ENTRY="\"''${TOOL}\" = \"''${VERSION}\""

    if [ ! -f "$TOML_FILE" ]; then
      printf '[tools]\n%s\n' "$ENTRY" > "$TOML_FILE"
    elif ${pkgs.gnugrep}/bin/grep -q '^\[tools\]' "$TOML_FILE"; then
      ${pkgs.gnused}/bin/sed -i "/^\[tools\]/a ''${ENTRY}" "$TOML_FILE"
    else
      printf '\n[tools]\n%s\n' "$ENTRY" >> "$TOML_FILE"
    fi

    # Patch the nearest flake.nix overrides block (D-07, D-08, D-09).
    # Walk up from $PWD toward filesystem root to find the first flake.nix.
    FLAKE_DIR="$PWD"
    FLAKE_NIX=""
    while true; do
      if [ -f "$FLAKE_DIR/flake.nix" ]; then
        FLAKE_NIX="$FLAKE_DIR/flake.nix"
        break
      fi
      PARENT="$(${pkgs.coreutils}/bin/dirname "$FLAKE_DIR")"
      if [ "$PARENT" = "$FLAKE_DIR" ]; then
        # Reached filesystem root — no flake.nix found
        break
      fi
      FLAKE_DIR="$PARENT"
    done

    if [ -z "$FLAKE_NIX" ]; then
      echo "[mise2nix] Warning: no flake.nix found walking up from $PWD — skipping flake.nix patch."
      echo "[mise2nix] Add manually: overrides = { \"$TOOL\" = pkgs.$ATTR_NAME; };"
    elif ${pkgs.gnugrep}/bin/grep -q 'overrides = {' "$FLAKE_NIX"; then
      # Append new entry inside existing overrides = { ... } block.
      # Sed pattern: find the line with 'overrides = {' and append the new entry after it.
      OVERRIDE_ENTRY="      \"''${TOOL}\" = pkgs.''${ATTR_NAME};"
      ${pkgs.gnused}/bin/sed -i "/overrides = {/a\\''${OVERRIDE_ENTRY}" "$FLAKE_NIX"
      echo "[mise2nix] Patched $FLAKE_NIX: added \"$TOOL\" = pkgs.$ATTR_NAME;"
    else
      # No overrides block found — print a hint rather than attempting fragile injection
      echo "[mise2nix] Warning: no 'overrides = {' block found in $FLAKE_NIX."
      echo "[mise2nix] Add manually to your fromMiseToml call:"
      echo "[mise2nix]   overrides = { \"$TOOL\" = pkgs.$ATTR_NAME; };"
    fi

    if [ -n "''${DIRENV_DIR:-}" ]; then
      RELOAD_CMD="direnv reload"
    else
      RELOAD_CMD="nix develop"
    fi

    echo "[mise2nix] '$TOOL' written to $TOML_FILE."
    echo "[mise2nix] Tool resolution is Nix-managed. Run \`''${RELOAD_CMD}\` to enter the updated shell."
    exit 0
  fi

  # Known/mapped tool path (unchanged from phase 7, WRAP-02)
  TOML_FILE="''${MISE_CONFIG_FILE:-mise.toml}"
  ENTRY="\"''${TOOL}\" = \"''${VERSION}\""

  if [ ! -f "$TOML_FILE" ]; then
    printf '[tools]\n%s\n' "$ENTRY" > "$TOML_FILE"
  elif ${pkgs.gnugrep}/bin/grep -q '^\[tools\]' "$TOML_FILE"; then
    ${pkgs.gnused}/bin/sed -i "/^\[tools\]/a ''${ENTRY}" "$TOML_FILE"
  else
    printf '\n[tools]\n%s\n' "$ENTRY" >> "$TOML_FILE"
  fi

  if [ -n "''${DIRENV_DIR:-}" ]; then
    RELOAD_CMD="direnv reload"
  else
    RELOAD_CMD="nix develop"
  fi

  echo "[mise2nix] '$TOOL' written to $TOML_FILE."
  echo "[mise2nix] Tool resolution is Nix-managed. Run \`''${RELOAD_CMD}\` to enter the updated shell."
''
