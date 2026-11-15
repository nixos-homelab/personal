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
  options.homelab.syncthing.metrics.enable = lib.mkEnableOption ''
    scraping Syncthing's metrics (device IDs, folder IDs and paths, traffic). Needs `metricsWithoutAuth` turned on in
    Syncthing's GUI settings
  '';
  config = lib.mkIf (cfg.enable && cfg.metrics.enable) {
    homelab.alloy.monitors.syncthing = {
      port = "web";
      # The pod's other ports sync; Alloy reaches the GUI port alone. The instance is a workload, which can't hold
      # the policy: a manifest of its own
      podPort = 8384;
      manifest = null;
    };
  };
}
