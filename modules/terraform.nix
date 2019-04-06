{ lib, config, pkgs, ... }:

let
  cfg = config.terraform;

  pathType = path: with builtins; (readDir (dirOf path)).${baseNameOf path};
  is       = type: path: (pathType path) == type;
  isDir    = is "directory"; # ?
  isFile   = is   "regular"; # file ?

  isTfFile     = lib.hasSuffix ".tf";
  isTfNixFile  = lib.hasSuffix ".tf.nix";
  isTfJsonFile = lib.hasSuffix ".tf.json";

in {
  options.terraform = with lib; with types; let
    dir        = addCheck path isDir        // { name =        "dir"; description = "directory"; };
    file       = addCheck path isFile       // { name =       "file"; description = "regular file"; };
    tfFile     = addCheck file isTfFile     // { name =     "tfFile"; description = "terraform file"; };
    tfNixFile  = addCheck file isTfNixFile  // { name =  "tfNixfile"; description = "terraform nix file"; };
    tfJsonFile = addCheck file isTfJsonFile // { name = "tfJsonfile"; description = "terraform json file"; };

  in {
    paths = mkOption {
      type        = listOf (either dir (either tfFile tfNixFile));
      default     = singleton (builtins.getEnv "PWD");
    };

    files = mkOption {
      type     = listOf (either dir file);
      internal = true;
    };

    tfFiles = mkOption {
      type     = listOf tfFile;
      internal = true;
    };

    tfNixFiles = mkOption {
      type     = listOf tfNixFile;
      internal = true;
    };

    tfJsonFiles = mkOption {
      type     = listOf tfJsonFile;
      internal = true;
    };

    config = mkOption {
      type = submodule {
        options = {
          resource = mkOption {
            type    = nullOr (attrsOf (attrsOf attrs));
            default = null;
          };

          data = mkOption {
            type    = nullOr (attrsOf (attrsOf attrs));
            default = null;
          };

          variable = mkOption {
            type    = nullOr (attrsOf attrs);
            default = null;
          };

          output = mkOption {
            type    = nullOr (attrsOf attrs);
            default = null;
          };

          provider = mkOption {
            type    = nullOr (attrsOf attrs);
            default = null;
          };

          module = mkOption {
            type    = nullOr (attrsOf attrs);
            default = null;
          };

          terraform = mkOption {
            type    = nullOr attrs;
            default = null;
          };

          locals = mkOption {
            type    = nullOr attrs;
            default = null;
          };
        };
      };

      #         ↓ this must be a function in order for imports to work
      default = _: {
        imports = cfg.tfNixFiles;
      };
    };

    configTfJson = mkOption {
      type     = str;
      internal = true;
    };

    result = mkOption {
      type     = package;
      internal = true;
    };
  };

  config.terraform = {
    files = with lib; let
      dirs        = filterDirs cfg.paths;
      expand      = dir: with builtins; map (f: "${dir}/${f}") (attrNames (readDir dir));
      filterDirs  = builtins.filter isDir;
    in builtins.foldl' (files: dir: files ++ (expand dir)) [] dirs;

    tfFiles      = builtins.filter isTfFile     cfg.files;
    tfNixFiles   = builtins.filter isTfNixFile  cfg.files;
    tfJsonFiles  = builtins.filter isTfJsonFile cfg.files;
    configTfJson = builtins.toJSON (lib.filterAttrs (name: value: name != "_module" && value != null) cfg.config);
    
    result = with lib; pkgs.runCommand "terraform-${baseNameOf (builtins.getEnv "PWD")}" {
      inherit (cfg) configTfJson tfFiles tfJsonFiles;
      passAsFile   = [ "configTfJson" ];
    } (''
      mkdir -p $out
    '' + (optionalString (cfg.configTfJson != "{}") ''
        install --mode 444 $configTfJsonPath $out/terraform.tf.json
    '') + (optionalString (cfg.tfFiles ++ cfg.tfJsonFiles != []) ''
        install --mode 444 $tfFiles $tfJsonFiles $out
    ''));
  };
}
