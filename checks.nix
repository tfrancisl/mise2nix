{
  self,
  pkgs,
}: let
  mise2nix2shell = toml: overrides: let
    env = self.lib.fromMiseToml toml {
      inherit pkgs;
      inherit overrides;
    };
  in
    pkgs.mkShell (
      {
        inherit (env) shellHook;
        inherit (env) packages;
      }
      // env.envVars
    );
in {
  resolve-simple = let
    toml = builtins.toFile "mise-default.toml" ''
      [tools]
      node = "22"
      python = "3.11"
      jq = "latest"
      ripgrep = "latest"
      fd = "latest"

      [env]
      NODE_ENV = "development"
    '';
    devShell = mise2nix2shell toml {};
  in
    pkgs.runCommand "runtime-resolution" {} ''
      echo "devShell with runtimes: ${devShell}"
      echo "PASS: runtime resolution succeeded" > $out
    '';

  resolve-latest = let
    toml = builtins.toFile "mise-latest.toml" ''
      [tools]
      node = "latest"
      python = "latest"
      go = "latest"
    '';
    devShell = mise2nix2shell toml {};
  in
    pkgs.runCommand "resolve-latest" {} ''
      echo "devShell with latest: ${devShell}"
      echo "PASS: latest resolution succeeded" > $out
    '';

  overrides-work = let
    toml = builtins.toFile "override-test.toml" ''
      [tools]
      node = "22"
    '';
    devShell = mise2nix2shell toml {
      node = pkgs.nodejs_20;
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
    devShell = mise2nix2shell toml {};
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
    devShell = mise2nix2shell toml {};
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
    devShell = mise2nix2shell toml {};
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
    devShell = mise2nix2shell toml {};
  in
    pkgs.runCommand "integer-env-var" {} ''
      if [ "${devShell.PORT}" != "8080" ]; then
        echo "FAIL: PORT expected '8080', got '${devShell.PORT}'"
        exit 1
      fi
      echo "PASS: integer env var coerced to string" > $out
    '';

  resolve-pipx-black = let
    toml = builtins.toFile "pipx-test.toml" ''
      [tools]
      "pipx:black" = "latest"
    '';
    devShell = mise2nix2shell toml {};
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
    devShell = mise2nix2shell toml {};
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
    devShell = mise2nix2shell toml {};
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
    devShell = mise2nix2shell toml {};
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
    devShell = mise2nix2shell toml {};
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
    devShell = mise2nix2shell toml {"pipx:black" = pkgs.hello;};
  in
    pkgs.runCommand "backend-overrides-win" {} ''
      echo "devShell with override: ${devShell}"
      echo "PASS: backend override accepted" > $out
    '';
}
