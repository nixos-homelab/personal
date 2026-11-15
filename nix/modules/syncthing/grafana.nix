# Syncthing's rows of the Workload dashboard, shown for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.syncthing;
  j = ''namespace="syncthing"'';
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.syncthing.grafana.enable = lib.mkOption {
    description = "Whether the Workload dashboard has Syncthing's rows.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.syncthing.enable && config.homelab.syncthing.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.drilldown.rows.syncthing = {
      workload = "syncthing";
      row = g.row { title = "Syncthing"; } (
        g.autoGrid { columns = 3; } [
          (g.stat {
            title = "Folder state";
            queries = [
              (g.prom "syncthing_model_folder_state{${j}}" {
                instant = true;
                legend = "{{folder}}";
              })
            ];
            # Syncthing's folderState (lib/model/folderstate.go, v2.1.7)
            mappings = [
              {
                type = "value";
                options = {
                  "0".text = "idle";
                  "1".text = "scanning";
                  "2".text = "waiting to scan";
                  "3".text = "waiting to sync";
                  "4".text = "preparing to sync";
                  "5".text = "syncing";
                  "6".text = "cleaning";
                  "7".text = "waiting to clean";
                  "8".text = "error";
                  "9".text = "starting";
                };
              }
            ];
          })
          (g.stat {
            title = "Devices connected";
            queries = [
              (g.prom "syncthing_connections_active{${j}}" {
                instant = true;
                legend = "{{device}}";
              })
            ];
          })
          (g.timeseries {
            title = "Synced";
            unit = "Bps";
            description = "Bytes Syncthing processed per folder";
            queries = [
              (g.prom
                "sum by (folder) (rate(syncthing_model_folder_processed_bytes_total{${j}}[$__rate_interval]))"
                {
                  legend = "{{folder}}";
                }
              )
            ];
          })
          (g.timeseries {
            title = "Scans and pulls";
            queries = [
              (g.prom "sum by (folder) (increase(syncthing_model_folder_scans_total{${j}}[$__rate_interval]))" {
                legend = "{{folder}} scans";
              })
              (g.prom "sum by (folder) (increase(syncthing_model_folder_pulls_total{${j}}[$__rate_interval]))" {
                legend = "{{folder}} pulls";
              })
            ];
          })
          (g.stat {
            title = "Conflicts";
            decimals = 0;
            queries = [
              (g.prom "sum by (folder) (syncthing_model_folder_conflicts_total{${j}})" {
                instant = true;
                legend = "{{folder}}";
              })
            ];
          })
        ]
      );
    };
  };
}
