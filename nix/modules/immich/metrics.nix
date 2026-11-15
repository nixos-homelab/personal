# Immich's Prometheus metrics, scraped by Alloy: the API worker serves them on 8081, the microservices worker on 8082
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.immich.enable {
    homelab.kubernetes.submodules.instances.immich.args = {
      ports = {
        metrics-api = 8081;
        metrics-ms = 8082;
      };
      container.env.IMMICH_TELEMETRY_INCLUDE.value = "all";
    };
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
  };
}
