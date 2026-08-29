{ self, ... }:
{
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.syncthing;
in
{
  options.homelab.syncthing = {
    enable = lib.mkEnableOption "Syncthing";
  };
  imports = self.lib.importsApply [ ./homepage.nix ];
  config = lib.mkIf cfg.enable {
    homelab.cluster.backup.volumes.syncthing.syncthing = [
      "/config"
      "/data"
    ];
    kubetree.resources.syncthing = {
      workload = {
        apiVersion = "cluster.local";
        kind = "WorkloadMacro";
        metadata.name = "syncthing";
        spec = {
          dataPath = "/var/syncthing";
          ingressPort = 8384;
          podSpecMacro.mainContainer = {
            image = "syncthing/syncthing:latest";
            portsByName = {
              web = 8384;
              sync-tcp = 22000;
              sync-udp = {
                containerPort = 21027;
                protocol = "UDP";
              };
            };
            readinessProbe.httpGet.port = "web";
          };
        };
      };
    };
  };
}
