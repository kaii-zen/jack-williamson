{ lib, config, pkgs, ... }:

let
  cfg = config.terraform;

in {
  options.terraform = with lib; with types; let

  in {
    dir = mkOption {
      type = nullOr str;

      description = "Directory with tf.nix files";

      default = builtins.getEnv "PWD";
      defaultText = "$PWD";
    };

    tfNixFiles = mkOption {
      type     = listOf str;
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
            type    = nullOr (either (listOf (attrsOf attrs)) (attrsOf attrs));
            default = null;
          };

          module = mkOption {
            type    = nullOr (attrsOf attrs);
            default = null;
          };

          terraform = mkOption {
            type    = nullOr (attrsOf (either str (attrsOf (either str attrs))));
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
    tfNixFiles = with lib; let
      dir      = cfg.dir or "/var/empty";
      filter   = name: type: (type == "regular") && (hasSuffix ".tf.nix" name);
      filtered = filterAttrs filter (builtins.readDir cfg.dir);
      names    = builtins.attrNames filtered;
      absolute = map (name: "${cfg.dir}/${name}") names;
    in absolute;

    configTfJson = builtins.toJSON
    (lib.filterAttrs (name: value:
    (builtins.elem name [
      "resource"
      "data"
      "variable"
      "output"
      "provider"
      "module"
      "terraform"
      "locals" ]) && value != null)
    cfg.config);

    result = pkgs.writeText "nix.tf.json" cfg.configTfJson;
  };
}
