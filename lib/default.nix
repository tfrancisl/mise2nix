{ lib }:
{
  fromMiseToml = path: { pkgs }:
    let
      config = builtins.fromTOML (builtins.readFile path);
      tools  = config.tools or {};
      env    = config.env   or {};
    in
      pkgs.mkShell {
        packages = [];
      };
}
