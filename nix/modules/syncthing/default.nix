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
    homelab.kubernetes.submodules.instances.syncthing = {
      submodule = "workload";
      args = {
        dataPath = "/var/syncthing";
        ingressPort = 8384;
        ports = {
          web = 8384;
          sync-tcp = 22000;
          sync-udp = {
            containerPort = 21027;
            protocol = "UDP";
          };
        };
        container = {
          image = images."syncthing/syncthing".ref;
          imagePullPolicy = "Never";
          readinessProbe.httpGet.port = "web";
        };
      };
    };
  };
}
