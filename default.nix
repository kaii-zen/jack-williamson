{ pkgs ? import <nixpkgs> {}
, sources ? import ./nix/sources.nix }:

let
  niv = (import sources.niv {}).niv;
  nur-packages = import sources.nur-packages {};
  mkBashCli = pkgs.callPackage (sources.nur-packages + "/pkgs/make-bash-cli") { inherit (nur-packages.lib) grid; };

  wrapped-terraform = pkgs.writeShellScriptBin "terraform" ''
    exec jw terraform "$@"
  '';

  cli = mkBashCli "jw" "generate terraform configs with nix" {} (mkCmd: [
    (mkCmd "eval" "eval *.tf.nix files and dump a nix.tf.json." {} ''
      PATH=${with pkgs; lib.makeBinPath [ nix ]}:$PATH
      nix-build ${./.}/eval.nix --show-trace --out-link nix.tf.json --attr terraform.result
    '')
    (mkCmd "terraform" "eval and handover control to terraform." {
      aliases = [ "tf" ];
    } ''
      $0 eval
      PATH=${with pkgs; lib.makeBinPath [ terraform ]}:$PATH
      exec terraform "$@"
    '')
    (mkCmd "init" "setup new project" {
      aliases = [ "i" ];
    } ''
      PATH=${with pkgs; lib.makeBinPath [ niv ]}:$PATH
      niv init
      niv drop jack-williamson || true
      niv add --branch simplify kreisys/jack-williamson
      install -m 644 ${./shell.nix} shell.nix
      echo use nix > .envrc
    '')
  ]);

in {
  inherit cli wrapped-terraform;
}
