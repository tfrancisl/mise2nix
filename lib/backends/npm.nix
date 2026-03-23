{pkgs}: {
  # Traditional nodePackages namespace
  inherit (pkgs.nodePackages) prettier;
  inherit (pkgs.nodePackages) typescript;
  inherit (pkgs.nodePackages) eslint;
  # Top-level pkgs.* (newer packaging style in nixpkgs)
  inherit (pkgs) esbuild;
  inherit (pkgs) vite;
  inherit (pkgs) turbo;
  inherit (pkgs) vue;
  inherit (pkgs) biome;
  inherit (pkgs) pnpm;
  inherit (pkgs) yarn;
  inherit (pkgs) wrangler;
  inherit (pkgs) tsx;
}
