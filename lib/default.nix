{lib}: {
  fromMiseToml = path: {
    pkgs,
    extraPackages ? [],
    overrides ? {},
  }: let
    runtimes = import ./runtimes.nix {inherit lib pkgs;};
    utilities = import ./utilities.nix {inherit pkgs;};
    backends = {
      pipx = import ./backends/pipx.nix {inherit pkgs;};
      npm = import ./backends/npm.nix {inherit pkgs;};
      cargo = import ./backends/cargo.nix {inherit pkgs;};
    };
    envMod = import ./env.nix {};
    config = builtins.fromTOML (builtins.readFile path);
    tools = config.tools or {};
    env = config.env or {};

    # Resolve a backend:tool key against the backend mapping tables.
    # Returns the package directly (backend tables contain plain packages, not functions).
    # Throws a descriptive error for unknown backends or unmapped tools.
    resolveBackend = backend: tool: _version:
      if !(backends ? ${backend})
      then
        builtins.throw
        "mise2nix: unknown backend '${backend}' for tool '${backend}:${tool}'. Supported backends: pipx, npm, cargo. Use 'overrides = { \"${backend}:${tool}\" = pkgs.something; }' or 'extraPackages = [ pkgs.something ]'."
      else let
        table = backends.${backend};
      in
        table.${
          tool
        }
        or (builtins.throw
          "mise2nix: '${tool}' is not in the ${backend} mapping table. Use 'overrides = { \"${backend}:${tool}\" = pkgs.something; }' or 'extraPackages = [ pkgs.something ]'.");

    # Resolution order for each tool:
    # 1. Check overrides (user-provided replacement) -- highest priority, wins for ALL key forms
    # 2. Detect backend:tool syntax via builtins.match; dispatch to resolveBackend
    # 3. Check runtimes (version-specific resolution)
    # 4. Check utilities (direct pkgs.X mapping)
    # 5. Throw descriptive error (unknown tool)
    resolve = name: version: let
      v = builtins.toString version;
      parsed = builtins.match "([^:]+):(.*)" name;
      isBackend = parsed != null;
      backend =
        if isBackend
        then builtins.elemAt parsed 0
        else null;
      tool =
        if isBackend
        then builtins.elemAt parsed 1
        else null;
    in
      overrides.${
        name
      } or (
        if isBackend
        then resolveBackend backend tool v
        else if runtimes ? ${name}
        then runtimes.${name} v
        else if utilities ? ${name}
        then utilities.${name} v
        else
          builtins.throw
          "mise2nix: unknown tool '${name}' — not found in runtimes or utilities. Use 'overrides = { ${name} = pkgs.something; }' or 'extraPackages = [ pkgs.something ]' to provide it."
      );

    resolvedPackages = builtins.attrValues (builtins.mapAttrs resolve tools);
    envVars = envMod.mkEnvVars env;

    # Wrapper that intercepts `mise use` and passes all other subcommands through
    # to the real mise binary unchanged (WRAP-01, DX-06).
    #
    # For `mise use`: writes the tool entry to mise.toml via GNU sed (cross-platform
    # safe — BSD sed on macOS uses different -i syntax) and prints a mise2nix-attributed
    # reload message (WRAP-02, DX-05). Does NOT call the real `mise use` to avoid
    # triggering tool installs (D-01).
    #
    # All external tools are referenced by Nix store path because writeShellScriptBin
    # does not add anything to PATH.
    miseWrapper = pkgs.writeShellScriptBin "mise" ''
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
    '';
  in
    pkgs.mkShell ({
        # Prevent mise from trying to download/install tools that Nix already provides.
        # Analogous to UV_NO_DOWNLOAD in uv2nix. User [env] entries can override this.
        MISE_NOT_FOUND_AUTO_INSTALL = "false";
      }
      // envVars
      // {
        packages = [miseWrapper] ++ resolvedPackages ++ extraPackages;
      });
}
