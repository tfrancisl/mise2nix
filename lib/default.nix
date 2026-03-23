{ lib }:
{
  fromMiseToml = path: { pkgs, extraPackages ? [], overrides ? {} }:
    let
      runtimes  = import ./runtimes.nix  { inherit lib pkgs; };
      utilities = import ./utilities.nix { inherit lib pkgs; };
      envMod    = import ./env.nix       { inherit lib pkgs; };
      config    = builtins.fromTOML (builtins.readFile path);
      tools     = config.tools or {};
      env       = config.env   or {};

      # Resolution order for each tool:
      # 1. Check overrides (user-provided replacement) -- highest priority
      # 2. Check runtimes (version-specific resolution)
      # 3. Check utilities (direct pkgs.X mapping)
      # 4. Throw descriptive error (unknown tool)
      resolve = name: version:
        let v = builtins.toString version;
        in
          if overrides ? ${name} then overrides.${name}
          else if runtimes ? ${name} then runtimes.${name} v
          else if utilities ? ${name} then utilities.${name} v
          else builtins.throw
            "mise2nix: unknown tool '${name}' — not found in runtimes or utilities. Use 'overrides = { ${name} = pkgs.something; }' or 'extraPackages = [ pkgs.something ]' to provide it.";

      resolvedPackages = builtins.attrValues (builtins.mapAttrs resolve tools);
      envVars = envMod.mkEnvVars env;
    in
      pkgs.mkShell (envVars // {
        packages = [ pkgs.mise ] ++ resolvedPackages ++ extraPackages;
      });
}
