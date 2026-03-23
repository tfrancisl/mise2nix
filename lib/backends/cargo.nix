{pkgs}: {
  # Rust-ecosystem tools available in nixpkgs at top-level pkgs.*
  # NOTE: Several of these (ripgrep, bat, fd, eza, delta, zoxide, tokei, hyperfine, just)
  # are also in lib/utilities.nix. This is intentional — plain `ripgrep` routes through
  # utilities, while `cargo:ripgrep` routes here. Both resolve to the same package.
  inherit (pkgs) ripgrep;
  inherit (pkgs) bat;
  inherit (pkgs) fd;
  inherit (pkgs) eza;
  inherit (pkgs) delta;
  inherit (pkgs) zoxide;
  inherit (pkgs) tokei;
  inherit (pkgs) hyperfine;
  inherit (pkgs) just;
  # NOTE: Hyphenated keys must be quoted in Nix attrset literals (hyphens are arithmetic operators)
  "cargo-watch" = pkgs.cargo-watch;
  "cargo-nextest" = pkgs.cargo-nextest;
  inherit (pkgs) watchexec;
}
