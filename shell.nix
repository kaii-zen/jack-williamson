let
  sources = import ./nix/sources.nix;
  pkgs    = import <nixpkgs> {};

  jw = import (sources.jack-williamson or ./.) { inherit pkgs; };
in

pkgs.mkShell {
  buildInputs = with jw; [ cli wrapped-terraform ];
}
