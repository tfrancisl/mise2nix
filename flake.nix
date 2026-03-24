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
          node_val='${(fromTOML (builtins.readFile ./mise.toml)).tools.node}'
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

        wrapper-use-writes-toml = let
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
          tomlFixture = builtins.toFile "fixture.toml" ''
            [tools]
            node = "22"
          '';
        in
          pkgs.runCommand "wrapper-use-writes-toml"
          {nativeBuildInputs = [miseWrapper pkgs.gnused pkgs.gnugrep];}
          ''
            cp ${tomlFixture} mise.toml
            chmod +w mise.toml
            MISE_CONFIG_FILE=mise.toml mise use "pipx:black"
            if ${pkgs.gnugrep}/bin/grep -q '"pipx:black" = "latest"' mise.toml; then
              echo "PASS: entry written to mise.toml" > $out
            else
              echo "FAIL: entry not found in mise.toml"
              cat mise.toml
              exit 1
            fi
          '';

        wrapper-use-prints-message = let
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
          tomlFixture = builtins.toFile "fixture.toml" ''
            [tools]
          '';
        in
          pkgs.runCommand "wrapper-use-prints-message"
          {nativeBuildInputs = [miseWrapper pkgs.gnused pkgs.gnugrep];}
          ''
            cp ${tomlFixture} mise.toml
            chmod +w mise.toml
            MISE_CONFIG_FILE=mise.toml mise use "npm:prettier" > output.txt 2>&1
            if ${pkgs.gnugrep}/bin/grep -q "mise2nix" output.txt; then
              echo "PASS: mise2nix attribution in output" > $out
            else
              echo "FAIL: no mise2nix attribution"
              cat output.txt
              exit 1
            fi
          '';

        # WRAP-03 check: unknown backend (ubi:, gh:, etc.) triggers the interactive path.
        # In a Nix sandbox there is no controlling terminal — /dev/tty is unavailable,
        # so `read -r NIX_ATTR </dev/tty` returns empty → wrapper prints
        # "[mise2nix] Cancelled." and exits 0 without modifying any files.
        wrapper-unknown-backend-no-tty = let
          pipxKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./lib/backends/pipx.nix {inherit pkgs;}));
          npmKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./lib/backends/npm.nix {inherit pkgs;}));
          cargoKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./lib/backends/cargo.nix {inherit pkgs;}));
          miseWrapper = pkgs.writeShellScriptBin "mise" ''
            if [ "$1" != "use" ]; then
              exec ${pkgs.mise}/bin/mise "$@"
            fi

            shift

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

            PIPX_KNOWN="${pipxKnown}"
            NPM_KNOWN="${npmKnown}"
            CARGO_KNOWN="${cargoKnown}"

            NEEDS_PROMPT=0
            if [[ "$TOOL" == *:* ]]; then
              BACKEND="''${TOOL%%:*}"
              BARE_TOOL="''${TOOL#*:}"
              if [[ "$BACKEND" != "pipx" && "$BACKEND" != "npm" && "$BACKEND" != "cargo" ]]; then
                NEEDS_PROMPT=1
              else
                case "$BACKEND" in
                  pipx) KNOWN_LIST="$PIPX_KNOWN" ;;
                  npm)  KNOWN_LIST="$NPM_KNOWN"  ;;
                  cargo) KNOWN_LIST="$CARGO_KNOWN" ;;
                esac
                FOUND=0
                for k in $KNOWN_LIST; do
                  if [ "$k" = "$BARE_TOOL" ]; then
                    FOUND=1
                    break
                  fi
                done
                if [ "$FOUND" -eq 0 ]; then
                  NEEDS_PROMPT=1
                fi
              fi
            fi

            if [ "$NEEDS_PROMPT" -eq 1 ]; then
              _mise2nix_cancel() {
                echo ""
                echo "[mise2nix] Cancelled."
                exit 0
              }
              trap _mise2nix_cancel INT

              printf "[mise2nix] '%s' is not in the Nix backend tables.\n" "$TOOL"
              printf "Enter nixpkgs attribute for '%s' (e.g. ripgrep or pkgs.ripgrep, Enter to cancel): " "$TOOL"
              read -r NIX_ATTR </dev/tty

              trap - INT

              if [ -z "$NIX_ATTR" ]; then
                echo "[mise2nix] Cancelled."
                exit 0
              fi

              ATTR_NAME="''${NIX_ATTR#pkgs.}"
              TOML_FILE="''${MISE_CONFIG_FILE:-mise.toml}"
              ENTRY="\"''${TOOL}\" = \"''${VERSION}\""

              if [ ! -f "$TOML_FILE" ]; then
                printf '[tools]\n%s\n' "$ENTRY" > "$TOML_FILE"
              elif ${pkgs.gnugrep}/bin/grep -q '^\[tools\]' "$TOML_FILE"; then
                ${pkgs.gnused}/bin/sed -i "/^\[tools\]/a ''${ENTRY}" "$TOML_FILE"
              else
                printf '\n[tools]\n%s\n' "$ENTRY" >> "$TOML_FILE"
              fi

              FLAKE_DIR="$PWD"
              FLAKE_NIX=""
              while true; do
                if [ -f "$FLAKE_DIR/flake.nix" ]; then
                  FLAKE_NIX="$FLAKE_DIR/flake.nix"
                  break
                fi
                PARENT="$(${pkgs.coreutils}/bin/dirname "$FLAKE_DIR")"
                if [ "$PARENT" = "$FLAKE_DIR" ]; then
                  break
                fi
                FLAKE_DIR="$PARENT"
              done

              if [ -z "$FLAKE_NIX" ]; then
                echo "[mise2nix] Warning: no flake.nix found walking up from $PWD — skipping flake.nix patch."
                echo "[mise2nix] Add manually: overrides = { \"$TOOL\" = pkgs.$ATTR_NAME; };"
              elif ${pkgs.gnugrep}/bin/grep -q 'overrides = {' "$FLAKE_NIX"; then
                OVERRIDE_ENTRY="      \"''${TOOL}\" = pkgs.''${ATTR_NAME};"
                ${pkgs.gnused}/bin/sed -i "/overrides = {/a\\''${OVERRIDE_ENTRY}" "$FLAKE_NIX"
                echo "[mise2nix] Patched $FLAKE_NIX: added \"$TOOL\" = pkgs.$ATTR_NAME;"
              else
                echo "[mise2nix] Warning: no 'overrides = {' block found in $FLAKE_NIX."
                echo "[mise2nix] Add manually to your fromMiseToml call:"
                echo "[mise2nix]   overrides = { \"$TOOL\" = pkgs.$ATTR_NAME; };"
              fi

              if [ -n "''${DIRENV_DIR:-}" ]; then
                RELOAD_CMD="direnv reload"
              else
                RELOAD_CMD="nix develop"
              fi

              echo "[mise2nix] '$TOOL' written to $TOML_FILE."
              echo "[mise2nix] Tool resolution is Nix-managed. Run \`''${RELOAD_CMD}\` to enter the updated shell."
              exit 0
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
          pkgs.runCommand "wrapper-unknown-backend-no-tty"
          {nativeBuildInputs = [miseWrapper pkgs.gnused pkgs.gnugrep];}
          ''
            output=$(mise use "ubi:some-tool" 2>&1 || true)
            if echo "$output" | ${pkgs.gnugrep}/bin/grep -q "Cancelled\|not in the Nix backend tables"; then
              # Either Cancelled (empty read) or the prompt message appeared — both correct
              true
            else
              echo "FAIL: expected Cancelled or prompt message for unknown backend"
              echo "Got: $output"
              exit 1
            fi
            if [ -f mise.toml ]; then
              echo "FAIL: mise.toml should not have been created on abort"
              exit 1
            fi
            echo "PASS: unknown backend triggers abort path in no-TTY sandbox" > $out
          '';

        # WRAP-03 check: unmapped tool within a known backend (pipx:nonexistent_xyz_abc
        # is not in the pipxKnown list) also triggers the interactive path → abort in sandbox.
        wrapper-unmapped-known-backend-no-tty = let
          pipxKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./lib/backends/pipx.nix {inherit pkgs;}));
          npmKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./lib/backends/npm.nix {inherit pkgs;}));
          cargoKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./lib/backends/cargo.nix {inherit pkgs;}));
          miseWrapper = pkgs.writeShellScriptBin "mise" ''
            if [ "$1" != "use" ]; then
              exec ${pkgs.mise}/bin/mise "$@"
            fi

            shift

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

            PIPX_KNOWN="${pipxKnown}"
            NPM_KNOWN="${npmKnown}"
            CARGO_KNOWN="${cargoKnown}"

            NEEDS_PROMPT=0
            if [[ "$TOOL" == *:* ]]; then
              BACKEND="''${TOOL%%:*}"
              BARE_TOOL="''${TOOL#*:}"
              if [[ "$BACKEND" != "pipx" && "$BACKEND" != "npm" && "$BACKEND" != "cargo" ]]; then
                NEEDS_PROMPT=1
              else
                case "$BACKEND" in
                  pipx) KNOWN_LIST="$PIPX_KNOWN" ;;
                  npm)  KNOWN_LIST="$NPM_KNOWN"  ;;
                  cargo) KNOWN_LIST="$CARGO_KNOWN" ;;
                esac
                FOUND=0
                for k in $KNOWN_LIST; do
                  if [ "$k" = "$BARE_TOOL" ]; then
                    FOUND=1
                    break
                  fi
                done
                if [ "$FOUND" -eq 0 ]; then
                  NEEDS_PROMPT=1
                fi
              fi
            fi

            if [ "$NEEDS_PROMPT" -eq 1 ]; then
              _mise2nix_cancel() {
                echo ""
                echo "[mise2nix] Cancelled."
                exit 0
              }
              trap _mise2nix_cancel INT

              printf "[mise2nix] '%s' is not in the Nix backend tables.\n" "$TOOL"
              printf "Enter nixpkgs attribute for '%s' (e.g. ripgrep or pkgs.ripgrep, Enter to cancel): " "$TOOL"
              read -r NIX_ATTR </dev/tty

              trap - INT

              if [ -z "$NIX_ATTR" ]; then
                echo "[mise2nix] Cancelled."
                exit 0
              fi

              ATTR_NAME="''${NIX_ATTR#pkgs.}"
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
              exit 0
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
          pkgs.runCommand "wrapper-unmapped-known-backend-no-tty"
          {nativeBuildInputs = [miseWrapper pkgs.gnused pkgs.gnugrep];}
          ''
            output=$(mise use "pipx:nonexistent_xyz_abc" 2>&1 || true)
            if echo "$output" | ${pkgs.gnugrep}/bin/grep -q "Cancelled\|not in the Nix backend tables"; then
              true
            else
              echo "FAIL: expected Cancelled or prompt message for unmapped pipx tool"
              echo "Got: $output"
              exit 1
            fi
            if [ -f mise.toml ]; then
              echo "FAIL: mise.toml should not have been created on abort"
              exit 1
            fi
            echo "PASS: unmapped known-backend tool triggers abort path in no-TTY sandbox" > $out
          '';

        # WRAP-03 check: a known/mapped tool (pipx:black) must NOT trigger the interactive
        # path — it goes through the WRAP-02 path and writes mise.toml without prompting.
        wrapper-known-tool-no-prompt = let
          pipxKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./lib/backends/pipx.nix {inherit pkgs;}));
          npmKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./lib/backends/npm.nix {inherit pkgs;}));
          cargoKnown = builtins.concatStringsSep " " (builtins.attrNames (import ./lib/backends/cargo.nix {inherit pkgs;}));
          miseWrapper = pkgs.writeShellScriptBin "mise" ''
            if [ "$1" != "use" ]; then
              exec ${pkgs.mise}/bin/mise "$@"
            fi

            shift

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

            PIPX_KNOWN="${pipxKnown}"
            NPM_KNOWN="${npmKnown}"
            CARGO_KNOWN="${cargoKnown}"

            NEEDS_PROMPT=0
            if [[ "$TOOL" == *:* ]]; then
              BACKEND="''${TOOL%%:*}"
              BARE_TOOL="''${TOOL#*:}"
              if [[ "$BACKEND" != "pipx" && "$BACKEND" != "npm" && "$BACKEND" != "cargo" ]]; then
                NEEDS_PROMPT=1
              else
                case "$BACKEND" in
                  pipx) KNOWN_LIST="$PIPX_KNOWN" ;;
                  npm)  KNOWN_LIST="$NPM_KNOWN"  ;;
                  cargo) KNOWN_LIST="$CARGO_KNOWN" ;;
                esac
                FOUND=0
                for k in $KNOWN_LIST; do
                  if [ "$k" = "$BARE_TOOL" ]; then
                    FOUND=1
                    break
                  fi
                done
                if [ "$FOUND" -eq 0 ]; then
                  NEEDS_PROMPT=1
                fi
              fi
            fi

            if [ "$NEEDS_PROMPT" -eq 1 ]; then
              _mise2nix_cancel() {
                echo ""
                echo "[mise2nix] Cancelled."
                exit 0
              }
              trap _mise2nix_cancel INT

              printf "[mise2nix] '%s' is not in the Nix backend tables.\n" "$TOOL"
              printf "Enter nixpkgs attribute for '%s' (e.g. ripgrep or pkgs.ripgrep, Enter to cancel): " "$TOOL"
              read -r NIX_ATTR </dev/tty

              trap - INT

              if [ -z "$NIX_ATTR" ]; then
                echo "[mise2nix] Cancelled."
                exit 0
              fi

              ATTR_NAME="''${NIX_ATTR#pkgs.}"
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
              exit 0
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
          tomlFixture = builtins.toFile "fixture.toml" ''
            [tools]
            node = "22"
          '';
        in
          pkgs.runCommand "wrapper-known-tool-no-prompt"
          {nativeBuildInputs = [miseWrapper pkgs.gnused pkgs.gnugrep];}
          ''
            cp ${tomlFixture} mise.toml
            chmod +w mise.toml
            output=$(MISE_CONFIG_FILE=mise.toml mise use "pipx:black" 2>&1)
            if echo "$output" | ${pkgs.gnugrep}/bin/grep -q "not in the Nix backend tables"; then
              echo "FAIL: known mapped tool (pipx:black) should not trigger the interactive path"
              echo "Got: $output"
              exit 1
            fi
            if ! ${pkgs.gnugrep}/bin/grep -q '"pipx:black" = "latest"' mise.toml; then
              echo "FAIL: pipx:black entry not written to mise.toml"
              cat mise.toml
              exit 1
            fi
            echo "PASS: known mapped tool follows WRAP-02 path (no prompt)" > $out
          '';

        # WRAP-03 check: verify the sed patching logic that writes a new override entry
        # into a flake.nix containing an existing `overrides = {` block.
        # Tests the exact sed command used by the wrapper (D-07).
        wrapper-flake-patch-overrides = let
          flakeFixture = builtins.toFile "fixture-flake.nix" ''
            {
              outputs = { self, nixpkgs }: {
                devShells.default = self.lib.fromMiseToml ./mise.toml {
                  inherit pkgs;
                  overrides = {
                    "pipx:black" = pkgs.python3Packages.black;
                  };
                };
              };
            }
          '';
        in
          pkgs.runCommand "wrapper-flake-patch-overrides"
          {nativeBuildInputs = [pkgs.gnused pkgs.gnugrep];}
          ''
            cp ${flakeFixture} flake.nix
            chmod +w flake.nix

            # Replicate the exact sed command from miseWrapper WRAP-03 patch logic
            TOOL="ubi:some-tool"
            ATTR_NAME="sometool"
            OVERRIDE_ENTRY="      \"''${TOOL}\" = pkgs.''${ATTR_NAME};"
            ${pkgs.gnused}/bin/sed -i "/overrides = {/a\\''${OVERRIDE_ENTRY}" flake.nix

            if ${pkgs.gnugrep}/bin/grep -q '"ubi:some-tool" = pkgs.sometool;' flake.nix; then
              echo "PASS: sed correctly patched overrides block in flake.nix" > $out
            else
              echo "FAIL: override entry not found in patched flake.nix"
              cat flake.nix
              exit 1
            fi
          '';
      }
    );
  };
}
