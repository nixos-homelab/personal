{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  images = inputs.homelab-shared.lib.images.pinned pkgs ./Dockerfile;
  cfg = config.homelab.syncthing;
in
{
  options.homelab.syncthing = {
    enable = lib.mkEnableOption "Syncthing";
  };
  imports = self.lib.importsApply [ ./homepage.nix ];
  config = lib.mkIf cfg.enable {
    services.k3s.images = builtins.attrValues images;
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
            image = images."syncthing/syncthing".ref;
            imagePullPolicy = "Never";
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
