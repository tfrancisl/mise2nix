{
  description = "mise2nix — converts mise.toml to a Nix devShell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in {
      lib = import ./lib { inherit lib; };

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = self.lib.fromMiseToml ./mise.toml { inherit pkgs; };
        }
      );

      checks = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          parse-toml = pkgs.runCommand "parse-toml" {} ''
            node_val='${(builtins.fromTOML (builtins.readFile ./mise.toml)).tools.node}'
            if [ "$node_val" != "22" ]; then
              echo "FAIL: expected tools.node = 22, got $node_val"
              exit 1
            fi
            echo "PASS: TOML parse verified (tools.node = $node_val)" > $out
          '';

          devshell-builds =
            let devShell = self.lib.fromMiseToml ./mise.toml { inherit pkgs; };
            in pkgs.runCommand "devshell-builds" {} ''
              echo "devShell derivation: ${devShell}"
              echo "PASS: devShell evaluated successfully" > $out
            '';

          runtime-resolution =
            let devShell = self.lib.fromMiseToml ./mise.toml { inherit pkgs; };
            in pkgs.runCommand "runtime-resolution" {} ''
              echo "devShell with runtimes: ${devShell}"
              echo "PASS: runtime resolution succeeded" > $out
            '';

          resolve-latest =
            let
              latestToml = builtins.toFile "mise-latest.toml" ''
                [tools]
                node = "latest"
                python = "latest"
                go = "latest"
              '';
              devShell = self.lib.fromMiseToml latestToml { inherit pkgs; };
            in pkgs.runCommand "resolve-latest" {} ''
              echo "devShell with latest: ${devShell}"
              echo "PASS: latest resolution succeeded" > $out
            '';
        }
      );
    };
}
