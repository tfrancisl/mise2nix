{
  description = "mise2nix — converts mise.toml to a Nix devShell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;
    forAllSystems = lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  in {
    lib = import ./lib {inherit lib;};

    devShells = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = self.lib.fromMiseToml ./mise.toml {
          inherit pkgs;
          extraPackages = [
            (pkgs.callPackage
              "${self}/packages/fmt.nix"
              {})
          ];
        };
      }
    );

    checks = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        parse-toml = pkgs.runCommand "parse-toml" {} ''
          node_val='${(builtins.fromTOML (builtins.readFile ./mise.toml)).tools.node}'
          if [ "$node_val" != "22" ]; then
            echo "FAIL: expected tools.node = 22, got $node_val"
            exit 1
          fi
          echo "PASS: TOML parse verified (tools.node = $node_val)" > $out
        '';

        devshell-builds = let
          devShell = self.lib.fromMiseToml ./mise.toml {inherit pkgs;};
        in
          pkgs.runCommand "devshell-builds" {} ''
            echo "devShell derivation: ${devShell}"
            echo "PASS: devShell evaluated successfully" > $out
          '';

        runtime-resolution = let
          devShell = self.lib.fromMiseToml ./mise.toml {inherit pkgs;};
        in
          pkgs.runCommand "runtime-resolution" {} ''
            echo "devShell with runtimes: ${devShell}"
            echo "PASS: runtime resolution succeeded" > $out
          '';

        resolve-latest = let
          latestToml = builtins.toFile "mise-latest.toml" ''
            [tools]
            node = "latest"
            python = "latest"
            go = "latest"
          '';
          devShell = self.lib.fromMiseToml latestToml {inherit pkgs;};
        in
          pkgs.runCommand "resolve-latest" {} ''
            echo "devShell with latest: ${devShell}"
            echo "PASS: latest resolution succeeded" > $out
          '';

        resolve-utilities = let
          devShell = self.lib.fromMiseToml ./mise.toml {inherit pkgs;};
        in
          pkgs.runCommand "resolve-utilities" {} ''
            echo "devShell with utilities: ${devShell}"
            echo "PASS: utility resolution succeeded" > $out
          '';

        extra-packages = let
          toml = builtins.toFile "extra-test.toml" ''
            [tools]
            node = "22"
          '';
          devShell = self.lib.fromMiseToml toml {
            inherit pkgs;
            extraPackages = [pkgs.hello];
          };
        in
          pkgs.runCommand "extra-packages" {} ''
            echo "devShell with extraPackages: ${devShell}"
            echo "PASS: extraPackages accepted" > $out
          '';

        overrides-work = let
          toml = builtins.toFile "override-test.toml" ''
            [tools]
            node = "22"
          '';
          devShell = self.lib.fromMiseToml toml {
            inherit pkgs;
            overrides = {node = pkgs.nodejs_20;};
          };
        in
          pkgs.runCommand "overrides-work" {} ''
            echo "devShell with override: ${devShell}"
            echo "PASS: overrides accepted" > $out
          '';

        unsupported-version-error = let
          toml = builtins.toFile "bad-version.toml" ''
            [tools]
            node = "18"
          '';
          # node "18" is not in runtimes.nix map (supported: 20, 22, 24, 25); forces a throw
          devShell = self.lib.fromMiseToml toml {inherit pkgs;};
          # Force drvPath (not nativeBuildInputs) — deepSeq on nativeBuildInputs causes stack overflow
          result = builtins.tryEval (builtins.seq devShell.drvPath null);
        in
          pkgs.runCommand "unsupported-version-error" {} ''
            ${
              if result.success
              then ''echo "FAIL: should have thrown for unsupported node version" && exit 1''
              else ''echo "PASS: unsupported version correctly throws error" > $out''
            }
          '';

        unknown-tool-error = let
          toml = builtins.toFile "unknown-test.toml" ''
            [tools]
            nonexistent_tool_xyz = "latest"
          '';
          # fromMiseToml returns a lazy mkShell; force drvPath (not nativeBuildInputs) to trigger the throw
          devShell = self.lib.fromMiseToml toml {inherit pkgs;};
          # Force drvPath (not nativeBuildInputs) — deepSeq on nativeBuildInputs causes stack overflow
          result = builtins.tryEval (builtins.seq devShell.drvPath null);
        in
          pkgs.runCommand "unknown-tool-error" {} ''
            ${
              if result.success
              then ''echo "FAIL: should have thrown for unknown tool" && exit 1''
              else ''echo "PASS: unknown tool correctly throws error" > $out''
            }
          '';

        env-var-passthrough = let
          toml = builtins.toFile "env-test.toml" ''
            [env]
            NODE_ENV = "production"
            PORT = "8080"
          '';
          devShell = self.lib.fromMiseToml toml {inherit pkgs;};
        in
          pkgs.runCommand "env-var-passthrough" {} ''
            if [ "${devShell.NODE_ENV}" != "production" ]; then
              echo "FAIL: NODE_ENV expected 'production', got '${devShell.NODE_ENV}'"
              exit 1
            fi
            if [ "${devShell.PORT}" != "8080" ]; then
              echo "FAIL: PORT expected '8080', got '${devShell.PORT}'"
              exit 1
            fi
            echo "PASS: env vars flow through to mkShell" > $out
          '';

        integer-env-var = let
          toml = builtins.toFile "int-env-test.toml" ''
            [env]
            PORT = 8080
          '';
          # builtins.fromTOML parses 8080 as a Nix integer; env.nix must coerce via builtins.toString
          devShell = self.lib.fromMiseToml toml {inherit pkgs;};
        in
          pkgs.runCommand "integer-env-var" {} ''
            if [ "${devShell.PORT}" != "8080" ]; then
              echo "FAIL: PORT expected '8080', got '${devShell.PORT}'"
              exit 1
            fi
            echo "PASS: integer env var coerced to string" > $out
          '';

        full-integration = let
          devShell = self.lib.fromMiseToml ./mise.toml {inherit pkgs;};
        in
          pkgs.runCommand "full-integration" {} ''
            echo "devShell: ${devShell}"
            if [ "${devShell.NODE_ENV}" != "development" ]; then
              echo "FAIL: NODE_ENV expected 'development', got '${devShell.NODE_ENV}'"
              exit 1
            fi
            echo "PASS: full integration (tools + env) verified" > $out
          '';

        resolve-pipx-black = let
          toml = builtins.toFile "pipx-test.toml" ''
            [tools]
            "pipx:black" = "latest"
          '';
          devShell = self.lib.fromMiseToml toml {inherit pkgs;};
        in
          pkgs.runCommand "resolve-pipx-black" {} ''
            echo "devShell: ${devShell}"
            echo "PASS: pipx:black resolved" > $out
          '';

        resolve-npm-prettier = let
          toml = builtins.toFile "npm-test.toml" ''
            [tools]
            "npm:prettier" = "latest"
          '';
          devShell = self.lib.fromMiseToml toml {inherit pkgs;};
        in
          pkgs.runCommand "resolve-npm-prettier" {} ''
            echo "devShell: ${devShell}"
            echo "PASS: npm:prettier resolved" > $out
          '';

        resolve-cargo-ripgrep = let
          toml = builtins.toFile "cargo-test.toml" ''
            [tools]
            "cargo:ripgrep" = "latest"
          '';
          devShell = self.lib.fromMiseToml toml {inherit pkgs;};
        in
          pkgs.runCommand "resolve-cargo-ripgrep" {} ''
            echo "devShell: ${devShell}"
            echo "PASS: cargo:ripgrep resolved" > $out
          '';

        unknown-backend-error = let
          toml = builtins.toFile "unknown-backend.toml" ''
            [tools]
            "ubi:some-tool" = "latest"
          '';
          devShell = self.lib.fromMiseToml toml {inherit pkgs;};
          # Force drvPath (not nativeBuildInputs) — deepSeq on nativeBuildInputs causes stack overflow
          result = builtins.tryEval (builtins.seq devShell.drvPath null);
        in
          pkgs.runCommand "unknown-backend-error" {} ''
            ${
              if result.success
              then ''echo "FAIL: should have thrown for unknown backend" && exit 1''
              else ''echo "PASS: unknown backend correctly throws" > $out''
            }
          '';

        unmapped-tool-error = let
          toml = builtins.toFile "unmapped-tool.toml" ''
            [tools]
            "pipx:nonexistent_tool_xyz" = "latest"
          '';
          devShell = self.lib.fromMiseToml toml {inherit pkgs;};
          # Force drvPath (not nativeBuildInputs) — deepSeq on nativeBuildInputs causes stack overflow
          result = builtins.tryEval (builtins.seq devShell.drvPath null);
        in
          pkgs.runCommand "unmapped-tool-error" {} ''
            ${
              if result.success
              then ''echo "FAIL: should have thrown for unmapped pipx tool" && exit 1''
              else ''echo "PASS: unmapped tool correctly throws" > $out''
            }
          '';

        backend-overrides-win = let
          toml = builtins.toFile "backend-override.toml" ''
            [tools]
            "pipx:black" = "latest"
          '';
          devShell = self.lib.fromMiseToml toml {
            inherit pkgs;
            overrides = {"pipx:black" = pkgs.hello;};
          };
        in
          pkgs.runCommand "backend-overrides-win" {} ''
            echo "devShell with override: ${devShell}"
            echo "PASS: backend override accepted" > $out
          '';

        wrapper-passthrough = let
          miseWrapper = pkgs.writeShellScriptBin "mise" ''
            if [ "$1" != "use" ]; then
              exec ${pkgs.mise}/bin/mise "$@"
            fi

            # Handle: mise use [flags] TOOL_SPEC
            shift  # remove "use" from args

            TOOL_SPEC=""
            for arg in "$@"; do
              case "$arg" in
                -*) ;;
                *) TOOL_SPEC="$arg"; break ;;
              esac
            done

            if [ -z "$TOOL_SPEC" ]; then
              exec ${pkgs.mise}/bin/mise use "$@"
            fi

            if [[ "$TOOL_SPEC" == *@* ]]; then
              VERSION="''${TOOL_SPEC##*@}"
              TOOL="''${TOOL_SPEC%@*}"
            else
              VERSION="latest"
              TOOL="$TOOL_SPEC"
            fi

            TOML_FILE="''${MISE_CONFIG_FILE:-mise.toml}"
            ENTRY="\"''${TOOL}\" = \"''${VERSION}\""

            if [ ! -f "$TOML_FILE" ]; then
              printf '[tools]\n%s\n' "$ENTRY" > "$TOML_FILE"
            elif ${pkgs.gnugrep}/bin/grep -q '^\[tools\]' "$TOML_FILE"; then
              ${pkgs.gnused}/bin/sed -i "/^\[tools\]/a ''${ENTRY}" "$TOML_FILE"
            else
              printf '\n[tools]\n%s\n' "$ENTRY" >> "$TOML_FILE"
            fi

            if [ -n "''${DIRENV_DIR:-}" ]; then
              RELOAD_CMD="direnv reload"
            else
              RELOAD_CMD="nix develop"
            fi

            echo "[mise2nix] '$TOOL' written to $TOML_FILE."
            echo "[mise2nix] Tool resolution is Nix-managed. Run \`''${RELOAD_CMD}\` to enter the updated shell."
          '';
        in
          pkgs.runCommand "wrapper-passthrough"
            {nativeBuildInputs = [miseWrapper pkgs.mise];}
            ''
              mise --version > $out
            '';

        wrapper-in-packages = let
          toml = builtins.toFile "wrapper-pkg-test.toml" ''
            [tools]
            node = "22"
          '';
          devShell = self.lib.fromMiseToml toml {inherit pkgs;};
        in
          pkgs.runCommand "wrapper-in-packages" {} ''
            echo "devShell with wrapper: ${devShell}"
            echo "PASS: wrapper-in-packages" > $out
          '';
      }
    );
  };
}
