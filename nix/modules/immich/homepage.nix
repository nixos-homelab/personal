{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
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
      sources.IMMICH_API_KEY = hllib.setup-secrets.kubeSecretSource pkgs {
        description = "Immich API Key";
        namespace = "homepage";
        name = "immich-api-key";
        field = "HOMEPAGE_VAR_IMMICH_API_KEY";
      };
      destinations = [
        (hllib.setup-secrets.kubeSecretDestination pkgs {
          logPrefix = "Homepage (IMMICH_API_KEY)";
          namespace = "homepage";
          name = "immich-api-key";
          data.HOMEPAGE_VAR_IMMICH_API_KEY = "IMMICH_API_KEY";
        })
      ];
    };
    homelab.homepage = {
      sections.Personal.enable = lib.mkDefault true;
      services.Personal.Immich = {
        enable = lib.mkDefault true;
        icon = "immich.png";
        description = "Photos and Videos";
        href = "https://immich.${config.homelab.workloads.domain}";
        widgets = [
          {
            type = "immich";
            url = "http://immich.immich:2283";
            key = "{{HOMEPAGE_VAR_IMMICH_API_KEY}}";
            version = 2;
          }
        ];
      };
      envFrom = [ { secretRef.name = "immich-api-key"; } ];
      allowEgress = [ "immich" ];
    };
  };
}
