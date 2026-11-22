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
  ccfg = config.homelab.cluster;
  labels."app.kubernetes.io/name" = "syncthing";
  # Devices reach Syncthing through the client VPN only, which masquerades them as its pod: no discovery, relays or NAT
  # traversal, which need the internet, and no local discovery, whose broadcasts stay in the pod network. Devices
  # connect to the address of the Service syncthing-sync. Applied at every start, a first start generates the config
  setupConfig = ''
    set -eu
    cfg="$STHOMEDIR/config.xml"
    [ -f "$cfg" ] || syncthing generate --no-port-probing
    for opt in globalAnnounceEnabled localAnnounceEnabled relaysEnabled natEnabled crashReportingEnabled; do
      sed -i "s|<$opt>true</$opt>|<$opt>false</$opt>|" "$cfg"
    done
    sed -i -e '/<listenAddress>/d' \
      -e '/<options>/a\        <listenAddress>quic://0.0.0.0:22000</listenAddress>' \
      -e '/<options>/a\        <listenAddress>tcp://0.0.0.0:22000</listenAddress>' "$cfg"
  '';
in
{
  options.homelab.syncthing = {
    enable = lib.mkEnableOption "Syncthing";
  };
  imports = self.lib.importsApply [
    ./grafana.nix
    ./homepage.nix
    ./logs.nix
    ./metrics.nix
  ];
  config = lib.mkIf cfg.enable {
    homelab.cluster.images = builtins.attrValues images;
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
          sync-quic = {
            containerPort = 22000;
            protocol = "UDP";
          };
        };
        container = {
          image = images."syncthing/syncthing".ref;
          imagePullPolicy = "Never";
          readinessProbe.httpGet.port = "web";
        };
      };
      config.kubernetes.resources = {
        deployments.syncthing.spec.template.spec.initContainers.setup-config = {
          image = images."syncthing/syncthing".ref;
          imagePullPolicy = "Never";
          command = [
            "/bin/sh"
            "-c"
            setupConfig
          ];
          securityContext.readOnlyRootFilesystem = true;
          volumeMounts."/var/syncthing".name = "data";
        };
        # The sync port at an address of the LoadBalancer pool, which the client VPN routes. No world ports: the LAN
        # and the internet don't get in, only pods, the VPN's among them
        services.syncthing-sync = {
          metadata = {
            inherit labels;
            annotations."external-dns.alpha.kubernetes.io/hostname" = "syncthing-sync.${config.homelab.workloads.domain}";
          };
          spec = {
            type = "LoadBalancer";
            ipFamilies = (lib.optional ccfg.enableIPv4 "IPv4") ++ (lib.optional ccfg.enableIPv6 "IPv6");
            selector = labels;
            ports = {
              sync-tcp = {
                port = 22000;
                targetPort = 22000;
                protocol = "TCP";
              };
              sync-quic = {
                port = 22000;
                targetPort = 22000;
                protocol = "UDP";
              };
            };
          }
          // lib.optionalAttrs (ccfg.enableIPv4 && ccfg.enableIPv6) { ipFamilyPolicy = "RequireDualStack"; };
        };
      };
    };
  };
}
