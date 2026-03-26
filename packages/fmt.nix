{pkgs, ...}:
pkgs.writeShellApplication {
  name = "nfmt";
  runtimeInputs = with pkgs; [
    alejandra
    deadnix
    statix
    fd
    nixf-diagnose
  ];
  text = ''
    fd "$@" -t f -e nix -x statix fix -- '{}'
    fd "$@" -t f -e nix -X deadnix -e -- '{}' \; -X alejandra -q '{}'
    fd "$@" -t f -e nix -x nixf-diagnose --auto-fix -- '{}'
  '';
}
