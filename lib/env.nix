_: {
  # Takes the [env] attrset from parsed TOML config.
  # Returns an attrset of env var name -> string value,
  # suitable for merging into pkgs.mkShell arguments.
  #
  # builtins.toString handles any non-string TOML values
  # (integers, floats) that may appear in [env].
  mkEnvVars = envAttrs:
    builtins.mapAttrs (_name: toString) envAttrs;
}
