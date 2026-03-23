{ lib }:
{
  fromMiseToml = path: { pkgs }:
    let
      runtimes = import ./runtimes.nix { inherit lib pkgs; };
      config   = builtins.fromTOML (builtins.readFile path);
      tools    = config.tools or {};
      env      = config.env   or {};

      resolvedOrNull = builtins.mapAttrs (name: version:
        if runtimes ? ${name}
        then runtimes.${name} (builtins.toString version)
        else null
      ) tools;

      resolvedPackages = builtins.filter (v: v != null)
                           (builtins.attrValues resolvedOrNull);
    in
      pkgs.mkShell {
        packages = resolvedPackages;
      };
}
