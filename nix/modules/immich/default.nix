{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  images = inputs.homelab-shared.lib.images.pinned pkgs ./Dockerfile;
  cfg = config.homelab.immich;
in
{
  options.homelab.immich = {
    enable = lib.mkEnableOption "Immich";
  };
  imports = [
    inputs.homelab-storage.nixosModules.postgresql
    inputs.homelab-storage.nixosModules.redis
    inputs.homelab-monitoring.nixosModules.alloy
  ]
  ++ self.lib.importsApply [ ./homepage.nix ];
  config = lib.mkIf cfg.enable {
    homelab.cluster.images = builtins.attrValues images;
    assertions = [
      {
        assertion = config.homelab.postgresql.enable;
        message = "Immich depends on the PostgreSQL service. Enable with `homelab.postgresql.enable=true`";
      }
      {
        assertion = config.homelab.redis.enable;
        message = "Immich depends on the Redis service. Enable with `homelab.redis.enable=true`";
      }
    ];
    homelab.postgresql = {
      databases.immich = {
        backup.enable = lib.mkDefault true;
        setupCommands = [
          "CREATE EXTENSION IF NOT EXISTS vchord CASCADE"
          "CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE"
        ];
      };
      extraSettings = "shared_preload_libraries = 'vchord'";
      image.extensions = [
        "pgvector"
        "vectorchord"
      ];
    };
    homelab.cluster.backup.volumes.immich.immich = [ "/library" ];
    homelab.redis.databases.immich = lib.mkDefault "1";
    # One monitor per port: a monitor scrapes one Service port, and `endpoint` merges into that one endpoint
    homelab.alloy.monitors =
      lib.mapAttrs
        (_: port: {
          inherit port;
          namespace = "immich";
          selector."app.kubernetes.io/name" = "immich";
          egress = "immich";
        })
        {
          immich-api = "metrics-api";
          immich-ms = "metrics-ms";
        };
    homelab.kubernetes.submodules.instances.immich = {
      submodule = "workload";
      args = {
        allowEgress = [
          "postgresql"
          "redis"
        ];
        dataPath = "/data";
        ingressPort = 2283;
        ports = {
          web = 2283;
          metrics-api = 8081;
          metrics-ms = 8082;
        };
        container = {
          image = images."ghcr.io/immich-app/immich-server".ref;
          imagePullPolicy = "Never";
          env = {
            IMMICH_CONFIG_FILE.value = "/etc/immich/immich-config.json";
            IMMICH_VERSION.value = "v3";
            IMMICH_PORT.value = "2283";
            # Defined before DB_URL, which $(…) needs
            DATABASE_PASSWORD.valueFrom.secretKeyRef = {
              name = "postgresql-password";
              key = "password";
            };
            DB_URL.value = "postgresql://immich:$(DATABASE_PASSWORD)@postgresql.postgresql:5432/immich";
            REDIS_HOSTNAME.value = "redis.redis";
            REDIS_DBINDEX.value = config.homelab.redis.databases.immich;
            # Serves Prometheus metrics on metrics-api and metrics-ms, which serve nothing without it
            IMMICH_TELEMETRY_INCLUDE.value = "all";
          };
          # A first start migrates the database, which can outlast the liveness probe on a busy node
          startupProbe = {
            httpGet = {
              path = "/api/server/ping";
              port = "web";
            };
            failureThreshold = 30;
          };
          livenessProbe.httpGet = {
            path = "/api/server/ping";
            port = "web";
          };
          readinessProbe.httpGet = {
            path = "/api/server/ping";
            port = "web";
          };
          volumeMounts."/etc/immich".name = "config";
        };
      };
      config.kubernetes.resources = {
        configMaps.immich = {
          metadata.labels."app.kubernetes.io/name" = "immich";
          data."immich-config.json" = builtins.toJSON {
            backup.database.enabled = false;
            newVersionCheck.enabled = false;
          };
        };
        deployments.immich.spec.template.spec.volumes.config.configMap.name = "immich";
      };
    };
  };
}
