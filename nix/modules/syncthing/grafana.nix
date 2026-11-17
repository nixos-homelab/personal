# Syncthing's row of the Workload dashboard, shown for its namespace
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
        g.pack [
          {
            w = 6;
            h = 4;
            panel = g.ratio {
              title = "Devices connected";
              description = "Syncthing's devices it has a connection to, of all it knows";
              good = "count(syncthing_connections_active{${j}} > 0)";
              all = "count(syncthing_connections_active{${j}})";
              crit = 0.5;
            };
          }
          {
            w = 6;
            h = 4;
            panel = g.stat {
              title = "Conflicts";
              description = "Conflict copies Syncthing made (two devices changed a file at once) in the hour before; orange from 1, red from 10";
              decimals = 0;
              levels = g.levels {
                warn = 1;
                crit = 10;
              };
              queries = [
                (g.prom "sum(increase(syncthing_model_folder_conflicts_total{${j}}[1h])) or vector(0)" { })
              ];
            };
          }
          {
            w = 12;
            h = 4;
            panel = g.stat {
              title = "Synced";
              description = "What Syncthing transferred and wrote, every folder together";
              unit = "Bps";
              queries = [
                (g.prom "sum(rate(syncthing_model_folder_processed_bytes_total{${j}}[$__rate_interval]))" { })
              ];
            };
          }
          {
            w = 24;
            h = 6;
            panel = g.stateTimeline {
              title = "Folder states";
              description = "What each folder was doing, over time: idle (grey), scanning or syncing (blue), and errors (red)";
              queryOptions.maxDataPoints = 200;
              queries = [
                (g.prom "max by (folder) (syncthing_model_folder_state{${j}})" { legend = "{{folder}}"; })
              ];
              # Syncthing's folderState (lib/model/folderstate.go, v2.1.7)
              mappings = [
                {
                  type = "value";
                  options = lib.mapAttrs (_: v: { inherit (v) text color; }) {
                    "0" = {
                      text = "idle";
                      color = "#6e7079";
                    };
                    "1" = {
                      text = "scanning";
                      color = "blue";
                    };
                    "2" = {
                      text = "waiting to scan";
                      color = "light-blue";
                    };
                    "3" = {
                      text = "waiting to sync";
                      color = "light-blue";
                    };
                    "4" = {
                      text = "preparing to sync";
                      color = "light-blue";
                    };
                    "5" = {
                      text = "syncing";
                      color = "blue";
                    };
                    "6" = {
                      text = "cleaning";
                      color = "purple";
                    };
                    "7" = {
                      text = "waiting to clean";
                      color = "purple";
                    };
                    "8" = {
                      text = "error";
                      color = "red";
                    };
                    "9" = {
                      text = "starting";
                      color = "light-blue";
                    };
                  };
                }
              ];
            };
          }
          {
            w = 12;
            h = 8;
            panel = g.timeseries {
              title = "Synced by folder";
              noValue = "Nothing synced";
              description = "Bytes Syncthing processed per folder";
              unit = "Bps";
              legend = "right";
              queries = [
                (g.prom
                  "sum by (folder) (rate(syncthing_model_folder_processed_bytes_total{${j}}[$__rate_interval])) > 0"
                  {
                    legend = "{{folder}}";
                  }
                )
              ];
            };
          }
          {
            w = 12;
            h = 8;
            panel = g.timeseries {
              title = "Scans and pulls";
              noValue = "No scans or pulls";
              description = "Folder scans (looking for local changes) and pulls (fetching others' changes), as bars";
              decimals = 0;
              legend = "right";
              custom = {
                drawStyle = "bars";
                stacking.mode = "normal";
                fillOpacity = 70;
                lineWidth = 0;
              };
              queryOptions.maxDataPoints = 60;
              queries = [
                (g.prom "sum by (folder) (increase(syncthing_model_folder_scans_total{${j}}[$__interval])) > 0" {
                  legend = "{{folder}} scans";
                })
                (g.prom "sum by (folder) (increase(syncthing_model_folder_pulls_total{${j}}[$__interval])) > 0" {
                  legend = "{{folder}} pulls";
                })
              ];
            };
          }
        ]
      );
    };
  };
}
