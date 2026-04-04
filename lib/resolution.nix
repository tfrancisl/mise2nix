{
  backends,
  runtimes,
  utilities,
  overrides,
}: let
  # Resolve a backend:tool key against the backend mapping tables.
  # Returns the package directly (backend tables contain plain packages, not functions).
  # Throws a descriptive error for unknown backends or unmapped tools.
  resolveBackend = backend: tool: _version:
    if !(backends ? ${backend})
    then throw "mise2nix: unknown backend '${backend}' for tool '${backend}:${tool}'. Supported backends: pipx, npm, cargo. Use 'overrides = { \"${backend}:${tool}\" = pkgs.something; }'."
    else backends.${backend}.${tool} or (throw "mise2nix: '${tool}' is not in the ${backend} mapping table. Use 'overrides = { \"${backend}:${tool}\" = pkgs.something; }'.");
in {
  # Resolution order for each tool:
  # 1. Check overrides (user-provided replacement) -- highest priority, wins for ALL key forms
  # 2. Detect backend:tool syntax via builtins.match; dispatch to resolveBackend
  # 3. Check runtimes (version-specific resolution)
  # 4. Check utilities (direct pkgs.X mapping)
  # 5. Throw descriptive error (unknown tool)
  resolveTool = name: version: let
    v = toString version;
    parsed = builtins.match "([^:]+):(.*)" name;
    isBackend = parsed != null;
    backend =
      if isBackend
      then builtins.elemAt parsed 0
      else null;
    tool =
      if isBackend
      then builtins.elemAt parsed 1
      else null;
  in
    overrides.${
      name
    } or (
      if isBackend
      then resolveBackend backend tool v
      else if runtimes ? ${name}
      then runtimes.${name} v
      else if utilities ? ${name}
      then utilities.${name} v
      else throw "mise2nix: unknown tool '${name}' — not found in runtimes or utilities. Use 'overrides = { ${name} = pkgs.something; }' to provide it."
    );
}
