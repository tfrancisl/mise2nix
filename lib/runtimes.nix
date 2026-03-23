{ lib, pkgs }:

let
  # Version string normalization helpers.
  # Always apply builtins.toString first to handle TOML bare integers (Pitfall 4).
  splitVer  = v: lib.splitString "." (builtins.toString v);
  major     = v: builtins.head (splitVer v);
  majMin    = v: let p = splitVer v; in "${builtins.elemAt p 0}${builtins.elemAt p 1}";
  majMinUs  = v: let p = splitVer v; in "${builtins.elemAt p 0}_${builtins.elemAt p 1}";

  # node / nodejs resolver (defined once, referenced by both attrset keys)
  resolveNode = version:
    let
      ver = major (builtins.toString version);
      map = {
        "20" = pkgs.nodejs_20;
        "22" = pkgs.nodejs_22;
        "24" = pkgs.nodejs_24;
        "25" = pkgs.nodejs_25;
      };
    in
      if version == "latest" then pkgs.nodejs
      else if map ? ${ver} then map.${ver}
      else builtins.throw "mise2nix: node version ${ver} not available in nixpkgs — supported: 20, 22, 24, 25";

  # go / golang resolver
  resolveGo = version:
    let
      ver = majMinUs (builtins.toString version);
      map = {
        "1_24" = pkgs.go_1_24;
        "1_25" = pkgs.go_1_25;
        "1_26" = pkgs.go_1_26;
      };
    in
      if version == "latest" then pkgs.go
      else if map ? ${ver} then map.${ver}
      else builtins.throw "mise2nix: go version ${ver} not available in nixpkgs — supported: 1.24, 1.25, 1.26";

in {

  # node / nodejs
  node   = version: resolveNode version;
  nodejs = version: resolveNode version;

  # python
  python = version:
    let
      ver = majMin (builtins.toString version);
      map = {
        "311" = pkgs.python311;
        "312" = pkgs.python312;
        "313" = pkgs.python313;
        "314" = pkgs.python314;
        "315" = pkgs.python315;
      };
    in
      if version == "latest" then pkgs.python3
      else if map ? ${ver} then map.${ver}
      else builtins.throw "mise2nix: python version ${version} not available in nixpkgs — supported: 3.11, 3.12, 3.13, 3.14, 3.15";

  # go / golang
  go     = version: resolveGo version;
  golang = version: resolveGo version;

  # ruby
  ruby = version:
    let
      ver = majMinUs (builtins.toString version);
      map = {
        "3_3" = pkgs.ruby_3_3;
        "3_4" = pkgs.ruby_3_4;
        "3_5" = pkgs.ruby_3_5;
        "4_0" = pkgs.ruby_4_0;
      };
    in
      if version == "latest" then pkgs.ruby
      else if map ? ${ver} then map.${ver}
      else builtins.throw "mise2nix: ruby version ${ver} not available in nixpkgs — supported: 3.3, 3.4, 3.5, 4.0";

  # java (jdk)
  java = version:
    let
      ver = major (builtins.toString version);
      map = {
        "8"  = pkgs.jdk8;
        "11" = pkgs.jdk11;
        "17" = pkgs.jdk17;
        "21" = pkgs.jdk21;
        "25" = pkgs.jdk25;
      };
    in
      if version == "latest" then pkgs.jdk
      else if map ? ${ver} then map.${ver}
      else builtins.throw "mise2nix: java version ${ver} not available in nixpkgs — supported: 8, 11, 17, 21, 25";

  # erlang
  erlang = version:
    let
      ver = major (builtins.toString version);
      map = {
        "26" = pkgs.erlang_26;
        "27" = pkgs.erlang_27;
        "28" = pkgs.erlang_28;
        "29" = pkgs.erlang_29;
      };
    in
      if version == "latest" then pkgs.erlang
      else if map ? ${ver} then map.${ver}
      else builtins.throw "mise2nix: erlang version ${ver} not available in nixpkgs — supported: 26, 27, 28, 29";

  # elixir
  elixir = version:
    let
      ver = majMinUs (builtins.toString version);
      map = {
        "1_15" = pkgs.elixir_1_15;
        "1_16" = pkgs.elixir_1_16;
        "1_17" = pkgs.elixir_1_17;
        "1_18" = pkgs.elixir_1_18;
        "1_19" = pkgs.elixir_1_19;
      };
    in
      if version == "latest" then pkgs.elixir
      else if map ? ${ver} then map.${ver}
      else builtins.throw "mise2nix: elixir version ${ver} not available in nixpkgs — supported: 1.15, 1.16, 1.17, 1.18, 1.19";

  # php
  php = version:
    let
      ver = majMin (builtins.toString version);
      map = {
        "82" = pkgs.php82;
        "83" = pkgs.php83;
        "84" = pkgs.php84;
        "85" = pkgs.php85;
      };
    in
      if version == "latest" then pkgs.php
      else if map ? ${ver} then map.${ver}
      else builtins.throw "mise2nix: php version ${version} not available in nixpkgs — supported: 8.2, 8.3, 8.4, 8.5";

  # rust — nixpkgs does not ship versioned Rust toolchain attrs;
  # pkgs.rustup is the standard. All version strings map silently to pkgs.rustup.
  rust = _version: pkgs.rustup;

  # deno — single version in nixpkgs; silently map all version strings.
  deno = _version: pkgs.deno;

  # bun — single version in nixpkgs; silently map all version strings.
  bun = _version: pkgs.bun;

  # terraform — nixpkgs ships one Terraform 1.x version; silently map all.
  terraform = _version: pkgs.terraform;

  # kubectl — single version in nixpkgs; silently map all version strings.
  kubectl = _version: pkgs.kubectl;

}
