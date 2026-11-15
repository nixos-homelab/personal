# Immich's Prometheus metrics, scraped by Alloy while it runs. The API worker serves them on 8081, the microservices
# worker on 8082, but only on localhost: Immich passes the OpenTelemetry Prometheus exporter a port alone, and the
# exporter (0.300) defaults its host to 'localhost' and reads no variable for it. So an nginx sidecar forwards 9081
# and 9082 to them, to both loopbacks in turn (on a refused connection nginx tries the next), as localhost may have
# resolved to either
{ inputs, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ports = {
    metrics-api = {
      immich = 8081;
      proxy = 9081;
    };
    metrics-ms = {
      immich = 8082;
      proxy = 9082;
    };
  };
  proxyConfig = pkgs.writeTextDir "etc/nginx/metrics-proxy.conf" ''
    daemon off;
    worker_processes 1;
    pid /tmp/nginx.pid;
    error_log stderr warn;
    events {}
    stream {
      ${lib.concatStrings (
        lib.mapAttrsToList (name: p: ''
          upstream ${name} {
            server 127.0.0.1:${toString p.immich};
            server [::1]:${toString p.immich};
          }
          server {
            listen ${toString p.proxy};
            listen [::]:${toString p.proxy};
            proxy_pass ${name};
          }
        '') ports
      )}
    }
  '';
  image = pkgs.dockerTools.buildImage {
    name = "cluster.local/immich-metrics-proxy";
    copyToRoot = [ proxyConfig ];
    # The image config references nginx, which puts it in the image
    config.Entrypoint = [
      (lib.getExe pkgs.nginx)
      "-e"
      "stderr"
      "-c"
      "/etc/nginx/metrics-proxy.conf"
    ];
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.immich.enable (
    lib.mkMerge [
      {
        # One monitor per port: a monitor renders one ServiceMonitor endpoint
        homelab.alloy.monitors = lib.mapAttrs' (
          port: p:
          lib.nameValuePair "immich-${lib.removePrefix "metrics-" port}" {
            inherit port;
            podPort = p.proxy;
            namespace = "immich";
            # Immich's instance is a workload, which can't hold the policies (kubenix nesting): manifests of their own
            manifest = null;
            selector."app.kubernetes.io/name" = "immich";
          }
        ) ports;
      }
      (lib.mkIf config.homelab.alloy.enable {
        homelab.cluster.images = [ image ];
        homelab.kubernetes.submodules.instances.immich = {
          args.container.env.IMMICH_TELEMETRY_INCLUDE.value = "all";
          config.kubernetes.resources = {
            deployments.immich.spec.template = {
              # The sidecar sorts first, where kubectl logs and exec would go without -c
              metadata.annotations."kubectl.kubernetes.io/default-container" = "immich";
              spec = {
                containers.metrics-proxy = {
                  image = "${image.buildArgs.name}:${image.imageTag}";
                  imagePullPolicy = "Never";
                  ports = lib.mapAttrs (_: p: { containerPort = p.proxy; }) ports;
                  # Not root: nginx would then switch its workers to nobody, which needs capabilities it hasn't
                  securityContext = {
                    runAsUser = 65534;
                    runAsGroup = 65534;
                    runAsNonRoot = true;
                    allowPrivilegeEscalation = false;
                    readOnlyRootFilesystem = true;
                    capabilities.drop = [ "ALL" ];
                  };
                  volumeMounts."/tmp".name = "metrics-proxy-tmp";
                };
                volumes.metrics-proxy-tmp.emptyDir = { };
              };
            };
            services.immich.spec.ports = lib.mapAttrs (_: p: { port = p.proxy; }) ports;
          };
        };
      })
    ]
  );
}
