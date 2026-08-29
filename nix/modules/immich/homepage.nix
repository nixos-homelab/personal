{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.homepage.integrations.immich;
  hllib = inputs.homelab-shared.lib;
in
{
  options.homelab.homepage.integrations.immich = {
    enable = lib.mkOption {
      description = "integration of immich with homepage";
      type = lib.types.bool;
      default = config.homelab.immich.enable && config.homelab.homepage.enable;
      defaultText = lib.literalExpression "config.homelab.immich.enable && config.homelab.homepage.enable";
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-shared.nixosModules.homepage
    self.nixosModules.homepage
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets = {
      sources.IMMICH_API_KEY = {
        description = "Immich API Key";
        cmd = hllib.setup-secrets.mkScript pkgs "getKubeSecret homepage immich-api-key HOMEPAGE_VAR_IMMICH_API_KEY";
      };
      destinations = [
        {
          logPrefix = "Homepage (IMMICH_API_KEY)";
          requires = [ "IMMICH_API_KEY" ];
          cmd = hllib.setup-secrets.mkScript pkgs ''setKubeSecret homepage immich-api-key HOMEPAGE_VAR_IMMICH_API_KEY "''${IMMICH_API_KEY:?}"'';
        }
      ];
    };
    homelab.homepage = {
      sections.Personal.enable = lib.mkDefault true;
      services.Personal.Immich = {
        enable = lib.mkDefault true;
        icon = "immich.png";
        description = "Photos and Videos";
        href = "https://immich.${ccfg.domain}";
        widgets = [
          {
            type = "immich";
            url = "http://immich.immich:2283";
            key = "{{HOMEPAGE_VAR_IMMICH_API_KEY}}";
          }
        ];
      };
      envFrom = [ { secretRef.name = "immich-api-key"; } ];
      allowEgress = [ "immich" ];
    };
  };
}
