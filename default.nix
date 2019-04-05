{ pkgs ? import <nixpkgs> {} }:

let
  # We are trying to wrap terraform as transparently as possible. To the user the only difference
  # should be that it now takes `tf.nix` files as well.
  # To achieve this: 
  # - we convert `.tf.nix` files to `.tf.json` files,
  # - we copy the resulting `.tf.json` files, along with any existing `.tf` and `.tf.json` files to a new derivation.
  # 
  # At this point all we have to do is manipulate Terraform to read the configs from the derivation we created
  # While still writing the `.terraform` dir (which contains fetched plugins and modules) and the `terraform.tfstate` file to our working directory.
  #
  # Unfortunately, this is much more tricky than it should be. Terraform's interface isn't super consistent:
  # - The Terraform configs directory can only be given as an optional cli argument to the subcommands that need it; defaults to current directory if not given.
  #   We avoid having to intercept an optional argument simply by cd'ing into the derivation before passing control to Terraform.
  #   This comes with the following caveats:
  #   - If a directory is given as an argument, we basically fall back to "regular" Terraform. I can live with that.
  #   - Since the nix store is read-only, we have must tell Terraform to write its state file and data directory back in our actual $PWD:
  #     - The `.terraform` data dir: easy, it's controlled by an environment variable.
  #     - The `terraform.tfstate` file, however, is controlled by a `-tfstate` cli option, which is again only taken by some subcommands
  #       (and some sub-subcommands) that interact with the state, but not by others who do not: some of which would ignore it silently
  #       while others would complain and error out:
  #       - Terraform offers the `TF_CLI_ARGS`: it doesn't help us because of the above and because https://github.com/hashicorp/terraform/issues/14847
  #         has been open since 2017. Next.
  #       - Terraform also offers individual `TF_CLI_ARGS_command`: for example `TF_CLI_ARGS_plan="-tfstate=$PWD/terraform.tfstate"` would only add that flag
  #         to `terraform plan`. This is where this whole background story is leading down to.
  #         WE HAVE TO GO DOWN THE HARD, UGLY, SCREEN-SCRAPY WAY. Oh joy 🙃

  # This crawls `terraform -help` and outputs something like this:
  # ```
  # terraform commandA subcommand -optionA -optionB -optionC
  # terraform commandB -optionA -optionD -optionE
  # ... and so on
  # ```
  terraform-help-scraper = pkgs.writeShellScriptBin "terrascrape" ''
    set -eo pipefail

    PATH=${with pkgs; lib.makeBinPath [ coreutils findutils gnugrep gawk terraform ]}

    if [[ -z $1 ]]; then
      exec $0 index
    fi

    cmd=$1
    shift

    case $cmd in
      get-cmds | gc)
        exec "$@" -help | (egrep '^ {4}[[:alnum:]][[:alnum:]-]' || true) | awk '{ print $1 }' | xargs --no-run-if-empty --max-args=1 echo "$@" | tee >(cat 1>&2)
        ;;
      get-cmds-recursive | gcr)
        exec $0 get-cmds "$@" | xargs --no-run-if-empty --max-args=$(( $# + 1 )) $0 get-cmds-recursive
        ;;
      get-opts | go)
        (echo $@ ; $@ -help | (egrep -- '^ {2,4}-' || true) | awk '{ print $1 }' | cut -d= -f1) | xargs
        ;;
      index | idx | i)
        exec $0 get-cmds-recursive terraform 2>&1 | xargs --no-run-if-empty --max-args=1 -d '\n' $0 get-opts
        ;;
      *)
        exit 1
        ;;
    esac
  '';

  # Here 👇 we save the output from there ☝️   because it's kinda expensive to generate.
  terraform-option-index = pkgs.runCommand "terraform-option-index" {
    buildInputs = [ terraform-help-scraper ];
  } ''
    terrascrape | cut -d' ' -f2- > $out
  '';
  
  wrapped-terraform = pkgs.writeShellScriptBin "terraform" ''
    set -eo pipefail

    PATH=${with pkgs; lib.makeBinPath [ coreutils findutils gnugrep gnused nix terraform ]}

    result=$(nix-build ${./.}/eval.nix --show-trace --no-out-link --attr terraform.result)

    export TF_DATA_DIR=$PWD/.terraform
    # 👇 here we use it to set `-state` only for the commands and sub-commands that care for it.
    eval $(cat ${terraform-option-index} | egrep -- '-state([[:space:]]|$)' | sed -E 's/ -.*$//' | tr ' ' _ | xargs -I'%' echo "export TF_CLI_ARGS_%='-state=$PWD/terraform.tfstate'")

    cd $result
    exec terraform "$@"
  '';

  attribute-tester = pkgs.writeShellScriptBin "terrattr" ''
    PATH=${with pkgs; lib.makeBinPath [ coreutils findutils gnugrep gnused nix terraform ]}
    attr=''${1?Must specify attribute}
    shift
    nix-instantiate --show-trace --eval --strict "$@" ${./.}/eval.nix --attr terraform.$attr
  '';

in pkgs.buildEnv {
  name  = "jack-williamson";
  paths = [
    attribute-tester
    terraform-help-scraper
    wrapped-terraform
  ];
}
