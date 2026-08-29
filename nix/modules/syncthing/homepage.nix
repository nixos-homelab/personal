{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.homepage.integrations.syncthing;
in
{
  options.homelab.homepage.integrations.syncthing = {
    enable = lib.mkOption {
      description = "integration of syncthing with homepage";
      type = lib.types.bool;
      default = config.homelab.syncthing.enable && config.homelab.homepage.enable;
      defaultText = lib.literalExpression "config.homelab.syncthing.enable && config.homelab.homepage.enable";
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-shared.nixosModules.homepage
    self.nixosModules.homepage
  ];
  config = lib.mkIf cfg.enable {
    homelab.homepage = {
      sections.Personal.enable = lib.mkDefault true;
      services.Personal.syncthing = {
        enable = lib.mkDefault true;
        icon = "syncthing.png";
        href = "https://syncthing.${ccfg.domain}";
        description = "Continuous file synchronization";
      };
    };
  };
}
