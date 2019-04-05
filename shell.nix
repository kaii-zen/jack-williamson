let
  pkgs = import <nixpkgs> {};
  jw   = import ./. { inherit pkgs; };
in

pkgs.mkShell {
  buildInputs = [ jw pkgs.terraform ];
}
