# Immich's rows of the Workload dashboard, shown for its namespace
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
        g.autoGrid { columns = 2; } [
          (g.stat {
            title = "Users";
            decimals = 0;
            queries = [ (g.prom "immich_users_total{${j}}" { instant = true; }) ];
          })
          (g.timeseries {
            title = "Background tasks running";
            decimals = 0;
            queries = [ (g.prom "sum(immich_queues_background_task_active{${j}})" { legend = "running"; }) ];
          })
        ]
      );
    };
  };
}
