{lib}: let
  mkShellInputsFromMise = {
    tomlPath,
    pkgs,
    overrides ? {},
  }: let
    config = fromTOML (builtins.readFile tomlPath);

    tools = config.tools or {};
    env = config.env or {};

    runtimes = import ./runtimes.nix {inherit lib pkgs;};
    utilities = import ./utilities.nix {inherit pkgs;};
    backends = {
      pipx = import ./backends/pipx.nix {inherit pkgs;};
      npm = import ./backends/npm.nix {inherit pkgs;};
      cargo = import ./backends/cargo.nix {inherit pkgs;};
    };

    inherit (import ./mise-installs.nix {inherit lib;}) mkMiseInstallsDir;
    inherit (import ./tasks.nix {inherit pkgs lib;}) mkTasksBins;
    inherit (import ./env.nix {}) mkEnvVars;
    inherit (import ./resolution.nix {inherit backends runtimes utilities overrides;}) resolveTool;

    # Known tool lists derived from backend attrsets at Nix eval time (D-02).
    pipxKnown = builtins.concatStringsSep " " (builtins.attrNames backends.pipx);
    npmKnown = builtins.concatStringsSep " " (builtins.attrNames backends.npm);
    cargoKnown = builtins.concatStringsSep " " (builtins.attrNames backends.cargo);

    miseWrapper = import ./mise-wrapper.nix {inherit pkgs pipxKnown npmKnown cargoKnown;};

    resolvedMap = builtins.mapAttrs resolveTool tools;
    resolvedPackages = builtins.attrValues resolvedMap;
    miseInstallsDir = mkMiseInstallsDir pkgs tools resolvedMap;
    envVars = mkEnvVars env;
    tasks = config.tasks or {};
    taskPackages = mkTasksBins tasks;
  in {
    envVars =
      envVars
      // {
        # Point mise at the Nix-managed installs derivation so `mise ls` shows all
        # declared tools as active without network access or installation.
        MISE_INSTALLS_DIR = miseInstallsDir;
        # Prevent mise from installing tools itself or hitting the network.
        # MISE_OFFLINE blocks all network access (installs would fail at the
        # network layer). The AUTO_INSTALL flags go one step further: they skip
        # even attempting to install, avoiding spurious "offline" error messages
        # when a user runs `mise install` or enters a directory. Both are needed
        # for a clean Nix-managed experience.
        MISE_OFFLINE = "1";
        MISE_AUTO_INSTALL = "false";
        MISE_EXEC_AUTO_INSTALL = "false";
        MISE_NOT_FOUND_AUTO_INSTALL = "false";
      };
    packages = [miseWrapper] ++ resolvedPackages ++ taskPackages;
    # Auto-activate mise for `nix develop` (bash) users so the prompt hook
    # updates PATH on cd and `mise ls` shows the active toolset.
    # direnv users get MISE_INSTALLS_DIR exported automatically; for fish/zsh/nu
    # they need `eval "$(mise activate <shell>)"` once in their shell rc.
    shellHook = ''
      eval "$(${pkgs.mise}/bin/mise activate bash)"
    '';
  };
  mkShellFromMise = {
    tomlPath,
    pkgs,
    prefixShellHook ? "",
    postfixShellHook ? "",
    extraPackages ? [],
    extraEnvVars ? {},
    overrides ? {},
  }: let
    shellInputs = mkShellInputsFromMise {inherit tomlPath pkgs overrides;};
  in
    pkgs.mkShell (
      {
        shellHook = prefixShellHook + shellInputs.shellHook + postfixShellHook;
        packages = shellInputs.packages ++ extraPackages;
      }
      // (shellInputs.envVars // extraEnvVars)
    );
in {
  inherit mkShellInputsFromMise;
  inherit mkShellFromMise;
}
