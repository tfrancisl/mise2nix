{
  description = "mise2nix — converts mise.toml to a Nix devShell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;
    forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
  in {
    lib = import ./lib {inherit lib;};

    templates = {
      basic = {
        path = ./templates/basic;
        description = "A simple flake with a mise2nix devShell.";
      };
      default = self.templates.basic;
    };

    devShells = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        miseShell = self.lib.mkShellFromMise {
          inherit pkgs;
          tomlPath = ./mise.toml;
          extraPackages = [
            (pkgs.callPackage
              "${self}/packages/fmt.nix"
              {})
          ];
        };
      in {
        default = miseShell;
      }
    );

    checks = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        import ./checks.nix {inherit self pkgs;}
    );
  };
}
