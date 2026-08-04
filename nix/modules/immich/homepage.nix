{ inputs, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.services.homepage.integrations.immich;
  hllib = inputs.homelab.lib;
in
{
  options.homelab.services.homepage.integrations.immich = {
    enable = lib.mkOption {
      description = "integration of immich with homepage";
      type = lib.types.bool;
      default = config.homelab.services.immich.enable && config.homelab.services.homepage.enable;
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab.nixosModules.homepage
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets = {
      sources.IMMICH_API_KEY = {
        description = "Immich API Key";
      };
      destinations = [
        {
          logPrefix = "Homepage (IMMICH_API_KEY)";
          requires = [ "IMMICH_API_KEY" ];
          cmd = hllib.setup-secrets.mkScript pkgs ''setKubeSecret homepage immich-api-key IMMICH_API_KEY "$IMMICH_API_KEY"'';
        }
      ];
    };
    homelab.services.homepage = {
      services.Media.Immich = {
        icon = "immich.png";
        description = "Photos and Videos";
        href = "https://immich.${ccfg.domain}";
        widget = {
          type = "immich";
          url = "http://immich.immich:2283";
        };
        key = "{{HOMEPAGE_VAR_IMMICH_API_KEY}}";
      };
      envByName.HOMEPAGE_VAR_IMMICH_API_KEY.valueFrom.secretKeyRef = {
        name = "immich-api-key";
        key = "IMMICH_API_KEY";
      };
      allowEgress = [ "immich" ];
    };
  };
}
