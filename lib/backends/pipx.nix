{pkgs}: {
  inherit (pkgs.python3Packages) black;
  inherit (pkgs.python3Packages) mypy;
  inherit (pkgs.python3Packages) ruff;
  inherit (pkgs.python3Packages) isort;
  inherit (pkgs.python3Packages) pylint;
  inherit (pkgs.python3Packages) flake8;
  inherit (pkgs.python3Packages) pyupgrade;
  inherit (pkgs.python3Packages) bandit;
  "pip-tools" = pkgs.python3Packages."pip-tools";
  inherit (pkgs.python3Packages) twine;
  inherit (pkgs.python3Packages) mdformat;
  # NOTE: poetry is at top-level pkgs.poetry, NOT python3Packages.poetry (does not exist)
  inherit (pkgs) poetry;
}
