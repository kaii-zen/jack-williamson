{
  config._module.args = {
    pkgs = import <nixpkgs> {};
    amis = import <nixpkgs/nixos/modules/virtualisation/ec2-amis.nix>;
  };
}
