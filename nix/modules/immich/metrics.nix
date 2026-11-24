# Immich's Prometheus metrics, scraped by Alloy: the API worker serves them on 8081, the microservices worker on 8082
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.immich;
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  options.homelab.immich.metrics.enable = lib.mkOption {
    description = "Whether Alloy scrapes Immich's metrics.";
    type = lib.types.bool;
    default = config.homelab.alloy.enable;
    defaultText = lib.literalExpression "config.homelab.alloy.enable";
  };
  config = lib.mkIf (cfg.enable && cfg.metrics.enable) (
    lib.mkMerge [
      # Changes Immich's pod: only while Alloy is there to scrape it
      (lib.mkIf config.homelab.alloy.enable {
        homelab.kubernetes.submodules.instances.immich.args = {
          ports = {
            metrics-api = 8081;
            metrics-ms = 8082;
          };
          container.env.IMMICH_TELEMETRY_INCLUDE.value = "all";
          # v3.4.2 binds the exporters to IMMICH_HOST, `::` when unset, and then answers every request with 400
          # (immich-app/immich#33466). Fixed after v3.4.2: drop this with the next release. The API listens on it
          # too, which the Service and the probes reach over IPv4
          container.env.IMMICH_HOST.value = "0.0.0.0";
        };
      })
      {
        # One monitor per port: a monitor renders one ServiceMonitor endpoint
        homelab.alloy.monitors =
          lib.mapAttrs
            (_: m: {
              inherit (m) port podPort;
              namespace = "immich";
              selector."app.kubernetes.io/name" = "immich";
            })
            {
              immich-api = {
                port = "metrics-api";
                podPort = 8081;
              };
              immich-ms = {
                port = "metrics-ms";
                podPort = 8082;
              };
            };
      }
    ]
  );
}
