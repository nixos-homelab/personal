# imap-backup's alert rule: the last successful run older than 26 hours (from kube-state-metrics, which knows when
# the CronJob last succeeded)
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.imap-backup;
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.imap-backup.alerts.enable = lib.mkOption {
    description = "Whether Grafana alerts when imap-backup hasn't succeeded for a day.";
    type = lib.types.bool;
    default = cfg.enable && config.homelab.alloy.enable && config.homelab.grafana.alerting.enable;
    defaultText = lib.literalExpression ''
      config.homelab.imap-backup.enable && config.homelab.alloy.enable && config.homelab.grafana.alerting.enable
    '';
  };
  config = lib.mkIf cfg.alerts.enable {
    # It runs daily by default; before its first success there's no series
    homelab.grafana.alerting.groups.imap-backup.rules.old = g.alert {
      title = "Mail backup old";
      query = ''max(time() - kube_cronjob_status_last_successful_time{namespace="imap-backup", cronjob="imap-backup"})'';
      above = 26 * 3600;
      for = "15m";
      severity = "warning";
      summary = "imap-backup last succeeded {{ humanizeDuration $values.B.Value }} ago";
      dashboardUid = "workload";
    };
  };
}
