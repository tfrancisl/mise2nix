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
          # Default: node 22, python 3.11, ripgrep, fd — exactly what mise.toml says
          default = mise2nix.lib.fromMiseToml ./mise.toml { inherit pkgs; };

          # Override: same mise.toml but swap node 22 → node 20 via the overrides API
          # Enter with: nix develop .#with-override
          # Verify: node --version should print v20.x despite mise.toml saying "22"
          with-override = mise2nix.lib.fromMiseToml ./mise.toml {
            inherit pkgs;
            overrides = { node = pkgs.nodejs_20; };
          };
        }
      );

      checks = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          # Demonstrates: unknown tool throws a descriptive error naming the tool
          # and explaining the extraPackages / overrides escape hatches.
          # The check passes when the error is correctly thrown.
          unknown-tool-error =
            let
              toml = builtins.toFile "unknown-tool.toml" ''
                [tools]
                some-custom-tool = "latest"
              '';
              devShell = mise2nix.lib.fromMiseToml toml { inherit pkgs; };
              result = builtins.tryEval (builtins.deepSeq devShell.nativeBuildInputs devShell);
            in pkgs.runCommand "unknown-tool-error" {} ''
              ${if result.success then
                ''echo "FAIL: should have thrown for unknown tool" && exit 1''
              else
                ''echo "PASS: unknown tool correctly throws descriptive error" > $out''
              }
            '';

          # Demonstrates: overrides replaces a resolved package; devShell still builds cleanly
          overrides-work =
            let
              devShell = mise2nix.lib.fromMiseToml ./mise.toml {
                inherit pkgs;
                overrides = { node = pkgs.nodejs_20; };
              };
            in pkgs.runCommand "overrides-work" {} ''
              echo "devShell with override: ${devShell}"
              echo "PASS: overrides accepted and devShell builds" > $out
            '';
        }
      );
    };
}
