{ lib, config, pkgs, ... }:

let
  cfg = config.terraform;

  is       = type: path: (lib.pathType path) == type;
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
    dir = mkOption {
      type = nullOr path;

      description = ''
        A directory containing a Terraform config from which we will generate a derivation where:
        - <filename>*.tf.nix</filename> files will be:
          - evaluated alongside whatever might be set in <option>config</option> (empty set by default)
          - converted into a single <filename>terraform.tf.json</filename> file.
        - Everything else will be copied <literal>as-is</literal>.
        
        That means that any filtering (<filename>terraform.tfstate*</filename> and <filename>.terraform/</filename> come to mind) is the
        responsibility of the consumer and not a the concern of this module. The rationale here, if we take <filename>terraform.tfstate</filename> as an
        example, is that we cannot predict with certainty where it's going to be at this point; as it may be overridden by a CLI arg
        given to the `terraform` executable. Therefore the supplied <filename>terraform</filename> wrapper, is a better candidate for this
        particular concern.

        The default, which takes the current working directory and filters out <filename>.terraform/</filename> and <filename>.terraform.tfstate*</filename>
        is meant as an example.

        This may also be set to <literal>null</literal>, in which case, only configuration in <option>config</option> will be used.
      '';

      default = cleanSourceWith {
        src    = cleanSource (builtins.getEnv "PWD");
        filter = name: type: let
          baseName = baseNameOf (toString name);
        in !(
          ((baseName == ".terraform")                 && (type == "directory")) || 
          ((hasPrefix   "terraform.tfstate" baseName) && (type == "regular"))
        );
      };

      defaultText = "CWD";
    };

    tfNixFiles = mkOption {
      type     = listOf path;
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
    tfNixFiles = with lib; let
      dir      = cfg.dir or "/var/empty";
      filter   = name: type: (type == "regular") && (hasSuffix ".tf.nix" name);
      filtered = filterAttrs filter (builtins.readDir cfg.dir);
      names    = builtins.attrNames filtered;
      absolute = map (name: "${cfg.dir}/${name}") names;
    in absolute;

    configTfJson = builtins.toJSON (lib.filterAttrs (name: value: name != "_module" && value != null) cfg.config);

    result = with lib; pkgs.runCommand "terraform-${baseNameOf (builtins.getEnv "PWD")}" {
      inherit (cfg) configTfJson;
      src         = cfg.dir;
      passAsFile  = [ "configTfJson" ];
      buildInputs = [ pkgs.terraform ];
    } ''
      cp -r ''${src:-/var/empty} $out
      chmod +w $out
      install --mode 444 $configTfJsonPath $_/terraform.tf.json
    '';
  };
}
