# The imap-backup module's namespace in the `personal` area of the Home dashboard, whose CPU, memory and traffic graphs
# sum the containers by area
{ inputs, ... }:
{ config, lib, ... }:
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  config.homelab.grafana.home.areas.personal = {
    color = "#5794f2";
    namespaces = lib.mkIf config.homelab.imap-backup.enable [ "imap-backup" ];
  };
}
