# Syncthing's Prometheus metrics, scraped by Alloy from /metrics on the GUI port. They name peers by device ID, folders
# by folder ID and their local paths, with traffic and file counts, so they're off unless asked for. Syncthing serves
# them without auth only with `metricsWithoutAuth` in its GUI settings (its config.xml, which Syncthing keeps itself),
# and then also through the GUI's route
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.syncthing;
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  options.homelab.syncthing.metrics.enable = lib.mkOption {
    description = ''
      Whether Alloy scrapes Syncthing's metrics. Off by default for privacy: they name peers by device ID and folders
      by folder ID and local path, with their traffic, and land in Mimir for every Grafana user to query. Needs
      `metricsWithoutAuth` turned on in Syncthing's GUI settings.
    '';
    type = lib.types.bool;
    default = false;
  };
  config = lib.mkIf (cfg.enable && cfg.metrics.enable) {
    homelab.alloy.monitors.syncthing = {
      port = "web";
      # The pod's other ports sync; Alloy reaches the GUI port alone
      podPort = 8384;
    };
  };
}
