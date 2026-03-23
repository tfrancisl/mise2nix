{pkgs, ...}:
pkgs.writeShellApplication {
  name = "nfmt";
  runtimeInputs = with pkgs; [
    alejandra
    deadnix
    statix
    fd
  ];
  text = ''
    fd "$@" -t f -e nix -x statix fix -- '{}'
    fd "$@" -t f -e nix -X deadnix -e -- '{}' \; -X alejandra -q '{}'
  '';
}
