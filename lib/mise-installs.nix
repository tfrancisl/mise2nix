{lib}: {
  # Build a Nix derivation mirroring the directory structure that mise expects in its
  # installs dir (MISE_INSTALLS_DIR). This lets `mise ls` show Nix-provided tools as
  # "active" without network access or any installation.
  #
  # mise has two backend layouts:
  #   core (node, python, go, ruby, …) — adds {tool}/{ver}/bin to PATH
  #   aqua (most CLI tools)            — adds {tool}/{ver} directly to PATH
  #
  # Binary symlinks are created with shell globs (ln -s "${pkg}/bin/"*)  so that all
  # binaries in a package are captured without eval-time readDir (which would be IFD).
  #
  # The version directory is named with the EXACT version string from mise.toml
  # ("22", "latest", "3.11"). mise prefix-scans so "22" matches a "22.22.1" dir;
  # "latest" exact-matches. No version resolution required.
  mkMiseInstallsDir = pkgs: tools: resolvedMap: let
    # Core tools use {tool}/{ver}/bin/ subdirectory layout.
    # Everything else (utilities, backends) uses {tool}/{ver}/ directly.
    coreToolNames = ["node" "nodejs" "python" "go" "golang" "ruby" "java" "erlang" "elixir" "deno" "bun"];
    isCore = name: builtins.elem name coreToolNames;

    mkEntry = name: version: let
      pkg = resolvedMap.${name};
      ver = toString version;
    in
      if isCore name
      then ''
        mkdir -p "$out/${name}/${ver}/bin"
        ln -s "${pkg}/bin/"* "$out/${name}/${ver}/bin/"
      ''
      else ''
        mkdir -p "$out/${name}/${ver}"
        ln -s "${pkg}/bin/"* "$out/${name}/${ver}/"
      '';

    entries = lib.mapAttrsToList mkEntry tools;
  in
    pkgs.runCommand "mise-installs" {}
    (lib.concatStringsSep "\n" (["mkdir -p \"$out\""] ++ entries));
}
