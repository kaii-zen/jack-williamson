with import <nixpkgs/lib>;

(evalModules {
  modules = [ ./modules ];
}).config
