# Immich's row of the Workload dashboard, shown for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.immich;
  j = ''namespace="immich"'';
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.immich.grafana.enable = lib.mkOption {
    description = "Whether the Workload dashboard has Immich's rows.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.immich.enable && config.homelab.immich.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.drilldown.rows.immich = {
      workload = "immich";
      row = g.row { title = "Immich"; } (
        g.pack [
          {
            w = 4;
            h = 4;
            panel = g.stat {
              title = "Users";
              description = "Immich's user accounts";
              decimals = 0;
              queries = [ (g.prom "max(immich_users_total{${j}})" { }) ];
            };
          }
          {
            w = 4;
            h = 4;
            panel = g.stat {
              title = "Failed jobs";
              description = "Jobs that failed in the hour before (thumbnails, face detection, smart search, OCR); orange from 1, red from 10. The bars say which";
              decimals = 0;
              levels = g.levels {
                warn = 1;
                crit = 10;
              };
              queries = [
                (g.prom
                  ''sum(increase(label_replace({__name__=~"immich_jobs_.+_failed_total", ${j}}, "job", "$1", "__name__", "immich_jobs_(.+)_failed_total")[1h:1m])) or vector(0)''
                  { }
                )
              ];
            };
          }
          {
            w = 16;
            h = 8;
            panel = g.timeseries {
              title = "Queues";
              noValue = "All idle";
              description = "Jobs running in each of Immich's queues, stacked: after an upload, metadata, thumbnails, faces and smart search run one after the other";
              decimals = 0;
              legend = "right";
              custom = {
                stacking.mode = "normal";
                fillOpacity = 50;
              };
              queries = [
                (g.prom
                  ''label_replace(sum by (__name__) ({__name__=~"immich_queues_.+_active", ${j}}), "queue", "$1", "__name__", "immich_queues_(.+)_active") > 0''
                  {
                    legend = "{{queue}}";
                  }
                )
              ];
            };
          }
          {
            w = 8;
            h = 4;
            panel = g.timeseries {
              title = "Failed jobs";
              description = "Failed jobs by kind, as bars";
              decimals = 0;
              noValue = "No failures";
              custom = {
                drawStyle = "bars";
                stacking.mode = "normal";
                fillOpacity = 70;
                lineWidth = 0;
              };
              queryOptions.maxDataPoints = 60;
              queries = [
                (g.prom
                  ''sum by (job) (increase(label_replace({__name__=~"immich_jobs_.+_failed_total", ${j}}, "job", "$1", "__name__", "immich_jobs_(.+)_failed_total")[$__interval:1m])) > 0''
                  {
                    legend = "{{job}}";
                  }
                )
              ];
            };
          }
        ]
      );
    };
  };
}
