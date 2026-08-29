{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.immich;
in
{
  options.homelab.immich = {
    enable = lib.mkEnableOption "Immich";
  };
  imports = [
    inputs.homelab-shared.nixosModules.postgresql
    inputs.homelab-shared.nixosModules.redis
  ]
  ++ self.lib.importsApply [ ./homepage.nix ];
  config = lib.mkIf cfg.enable {
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
    kubetree.resources.immich = {
      config = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          namespace = "immich";
          name = "immich";
          labels."app.kubernetes.io/name" = "immich";
        };
        data."immich-config.json" = builtins.toJSON {
          backup.database.enabled = false;
          newVersionCheck.enabled = false;
        };
      };
      workload = {
        apiVersion = "cluster.local";
        kind = "WorkloadMacro";
        metadata.name = "immich";
        spec = {
          allowEgress = [
            "postgresql"
            "redis"
          ];
          dataPath = "/data";
          ingressPort = 2283;
          podSpecMacro = {
            mainContainer = {
              image = "ghcr.io/immich-app/immich-server:v3";
              envByName = {
                IMMICH_CONFIG_FILE = "/etc/immich/immich-config.json";
                IMMICH_VERSION = "v3";
                IMMICH_PORT = "2283";
                DB_URL = "postgresql://immich:immich@postgresql.postgresql:5432/immich";
                REDIS_HOSTNAME = "redis.redis";
                REDIS_DBINDEX = config.homelab.redis.databases.immich;
              };
              portsByName = {
                web = 2283;
                metrics-api = 8081;
                metrics-ms = 8082;
              };
              livenessProbe.httpGet = {
                path = "/api/server/ping";
                port = "web";
              };
              readinessProbe.httpGet = {
                path = "/api/server/ping";
                port = "web";
              };
              volumeMountsByPath."/etc/immich" = "config";
            };
            volumesByName.config.configMap.name = "immich";
          };
        };
      };
    };
  };
}
