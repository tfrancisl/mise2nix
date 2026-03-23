{
  description = "mise2nix example — polyglot dev environment from mise.toml";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    mise2nix = {
      url = "path:..";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, mise2nix }:
    let
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    in {
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; };
        }
      );
    };
}
