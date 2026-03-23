{ lib, pkgs }:

{
  # CLI utilities -- mise tool name -> nixpkgs attr
  # All resolvers take _version (unused) since nixpkgs provides a single version per pin.
  ripgrep   = _version: pkgs.ripgrep;
  rg        = _version: pkgs.ripgrep;      # alias: mise users may write either
  fd        = _version: pkgs.fd;
  bat       = _version: pkgs.bat;
  jq        = _version: pkgs.jq;
  fzf       = _version: pkgs.fzf;
  git       = _version: pkgs.git;
  curl      = _version: pkgs.curl;
  wget      = _version: pkgs.wget;
  make      = _version: pkgs.gnumake;       # NOTE: pkgs.gnumake, not pkgs.make
  cmake     = _version: pkgs.cmake;
  gh        = _version: pkgs.gh;
  delta     = _version: pkgs.delta;
  eza       = _version: pkgs.eza;
  zoxide    = _version: pkgs.zoxide;
  starship  = _version: pkgs.starship;
  just      = _version: pkgs.just;
  hyperfine = _version: pkgs.hyperfine;
  tokei     = _version: pkgs.tokei;
}
