{
  pkgs,
  lib,
}: tasks:
# Convert each [tasks] entry to a shell script available in the devShell.
# Supports:
#   shorthand:  build = "cargo build"          (task value is the script string)
#   full form:  [tasks.build] run = "..."       (attrset with run field)
#   array form: [tasks.build] run = ["a", "b"] (joined with newlines)
#
# task.depends, task.dir, task.env are out of scope for this iteration;
# use `mise run <task>` (passes through the wrapper) for those cases.
lib.mapAttrsToList (
  name: task: let
    runCmd =
      if builtins.isString task
      then task
      else if builtins.isList (task.run or null)
      then lib.concatStringsSep "\n" task.run
      else
        task.run
        or (throw "mise2nix: task '${name}' has no 'run' field — use overrides or define run = \"...\"");
  in
    pkgs.writeShellScriptBin name runCmd
)
tasks
