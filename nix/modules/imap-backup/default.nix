{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.homelab.services.imap-backup;
  hllib = inputs.homelab-shared.lib;
  container-utils = inputs.homelab-shared.packages.${pkgs.stdenv.hostPlatform.system}.container-utils;
  envVarName =
    name:
    "IMAP_BACKUP_${
      hllib.k8s.replaceInvalidCharacters "(^[A-Z]|[A-Z0-9])" "_" (lib.strings.toUpper name)
    }";
in
{
  options.homelab.services.imap-backup = {
    enable = lib.mkEnableOption "imap-backup";
    schedule = lib.mkOption {
      description = "Cronjob notation of when the imap-backup should run";
      type = lib.types.nullOr lib.types.str;
      default = "10 3 * * *";
      example = "10 3 * * *";
    };
    accounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }: {
            options = {
              username = lib.mkOption {
                description = "The username of the account";
                type = lib.types.str;
                default = name;
              };
              localPath = lib.mkOption {
                description = "Relative path where backups will be saved";
                type = lib.types.str;
                default = name;
              };
              folders = lib.mkOption {
                description = "List of folders that have been configured for the Account";
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
              mirrorMode = lib.mkEnableOption "mirror mode";
              server = lib.mkOption {
                description = "Address of the IMAP server";
                type = lib.types.str;
              };
              multiFetchSize = lib.mkOption {
                description = "Number of emails to fetch from the IMAP server at a time";
                type = lib.types.int;
                default = 1;
              };
              status = lib.mkOption {
                description = "Status of the account";
                type = lib.types.enum [
                  "active"
                  "archived"
                  "offline"
                ];
                default = "active";
              };
              extraSettings = lib.mkOption {
                description = "Additional settings not covered by the current options";
                type = lib.types.attrsOf lib.types.anything;
                default = { };
              };
            };
          }
        )
      );
    };
  };
  imports = [ ];
  config = lib.mkIf cfg.enable {
    homelab.cluster.backup.volumes.imap-backup.imap-backup = [ "/data" ];
    setup-secrets = {
      sources = lib.mapAttrs' (
        name: spec:
        lib.nameValuePair (envVarName name) {
          description = "IMAP Password for ${name}";
          cmd = hllib.setup-secrets.mkScript pkgs "getKubeSecret imap-backup passwords ${envVarName name}";
        }
      ) cfg.accounts;
      destinations = lib.mapAttrsToList (name: spec: {
        logPrefix = "imap-backup (${envVarName name})";
        requires = [ (envVarName name) ];
        cmd = hllib.setup-secrets.mkScript pkgs ''setKubeSecret imap-backup passwords ${envVarName name} "''${${envVarName name}:?}"'';
      }) cfg.accounts;
    };
    kubetree.resources.imap-backup = {
      namespace = (hllib.k8s.createNamespace { namespace = "imap-backup"; });
      data = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata.namespace = "imap-backup";
        metadata.name = "imap-backup";
        spec = {
          accessModes = [ "ReadWriteOnce" ];
          resources.requests.storage = "1Gi";
          volumeMode = "Filesystem";
        };
      };
      config = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          namespace = "imap-backup";
          name = "imap-backup";
          labels."app.kubernetes.io/name" = "imap-backup";
        };
        data."config.json" = builtins.toJSON {
          version = "2.2";
          accounts = lib.mapAttrsToList (
            name: spec:
            {
              username = spec.username;
              password = "${envVarName name}";
              status = spec.status;
              local_path = "/data/${spec.localPath}";
              folders = spec.folders;
              mirror_mode = spec.mirrorMode;
              server = spec.server;
              multi_fetch_size = spec.multiFetchSize;
            }
            // spec.extraSettings
          ) cfg.accounts;
          download_strategy = "delay_metadata";
        };
      };
      cronJob = {
        apiVersion = "batch/v1";
        kind = "CronJob";
        metadata.namespace = "imap-backup";
        metadata.name = "imap-backup";
        metadata.labels."app.kubernetes.io/name" = "imap-backup";
        spec.schedule = cfg.schedule;
        spec.jobTemplate.spec.template = {
          metadata.labels = {
            "app.kubernetes.io/name" = "imap-backup";
            "cluster.local/internet-egress" = "allow";
          };
          servicePodSpec = {
            name = "imap-backup";
            restartPolicy = "OnFailure";
            securityContext = config.kubetree.service-macros.securityContext // {
              fsGroup = config.kubetree.service-macros.securityContext.runAsGroup;
            };
            initContainersByName.render-config = {
              image = "${container-utils.buildArgs.name}:${container-utils.imageTag}";
              imagePullPolicy = "Never";
              args = [
                ''
                  touch /config-tmp/config.json
                  chmod 600 /config-tmp/config.json
                  conf=$(cat /config/config.json)
                  jq -r '.accounts[] | .password' <<<"$conf" | {
                    i=0
                    while read -r var; do
                      conf=$(jq --argjson idx "$i" --arg pw "''${!var}" '.accounts[$idx].password=$pw' <<<"$conf")
                      : $((i++))
                    done
                    printf "%s\n" "$conf"
                  } >/config-tmp/config.json
                ''
              ];
              envFrom = [ { secretRef.name = "passwords"; } ];
              securityContext = {
                allowPrivilegeEscalation = false;
                readOnlyRootFilesystem = true;
                capabilities.drop = [ "ALL" ];
              };
              volumeMountsByPath = {
                "/config" = "config";
                "/config-tmp" = "config-tmp";
              };
            };
            mainContainer = {
              image = "ghcr.io/joeyates/imap-backup:v16.6.0";
              command = [ "imap-backup" ];
              args = [ "backup" ];
              volumeMountsByPath = {
                "/.imap-backup" = "config-tmp";
                "/data" = "data";
              };
            };
            volumesByName = {
              config.configMap.name = "imap-backup";
              config-tmp.emptyDir.medium = "Memory";
              data.persistentVolumeClaim.claimName = "imap-backup";
            };
          };
        };
      };
    };
  };
}
