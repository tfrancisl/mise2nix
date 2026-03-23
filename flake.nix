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

          resolve-utilities =
            let devShell = self.lib.fromMiseToml ./mise.toml { inherit pkgs; };
            in pkgs.runCommand "resolve-utilities" {} ''
              echo "devShell with utilities: ${devShell}"
              echo "PASS: utility resolution succeeded" > $out
            '';

          extra-packages =
            let
              toml = builtins.toFile "extra-test.toml" ''
                [tools]
                node = "22"
              '';
              devShell = self.lib.fromMiseToml toml {
                inherit pkgs;
                extraPackages = [ pkgs.hello ];
              };
            in pkgs.runCommand "extra-packages" {} ''
              echo "devShell with extraPackages: ${devShell}"
              echo "PASS: extraPackages accepted" > $out
            '';

          overrides-work =
            let
              toml = builtins.toFile "override-test.toml" ''
                [tools]
                node = "22"
              '';
              devShell = self.lib.fromMiseToml toml {
                inherit pkgs;
                overrides = { node = pkgs.nodejs_20; };
              };
            in pkgs.runCommand "overrides-work" {} ''
              echo "devShell with override: ${devShell}"
              echo "PASS: overrides accepted" > $out
            '';

          unknown-tool-error =
            let
              toml = builtins.toFile "unknown-test.toml" ''
                [tools]
                nonexistent_tool_xyz = "latest"
              '';
              # fromMiseToml returns a lazy mkShell; force nativeBuildInputs to trigger the throw
              devShell = self.lib.fromMiseToml toml { inherit pkgs; };
              result = builtins.tryEval (builtins.deepSeq devShell.nativeBuildInputs devShell);
            in pkgs.runCommand "unknown-tool-error" {} ''
              ${if result.success then
                ''echo "FAIL: should have thrown for unknown tool" && exit 1''
              else
                ''echo "PASS: unknown tool correctly throws error" > $out''
              }
            '';
        }
      );
    };
}
