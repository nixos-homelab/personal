# How Immich's logs are parsed: NestJS, from its API and its microservices workers in one container. The worker is the
# context's prefix (Api:RouterExplorer), and the program
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
let
  nest = config.homelab.alloy.logs.formats.nest;
  esc = builtins.fromJSON ''"\u001b"'';
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.immich.enable {
    homelab.alloy.logs = {
      formats.immich = {
        inherit (nest) firstline decolorize;
        stages = nest.stages + ''
          stage.regex {
            source     = "component"
            expression = "^(?P<worker>[A-Za-z]+):"
          }
          stage.template {
            source   = "program"
            template = "{{ with index . \"worker\" }}immich-{{ ToLower . }}{{ end }}"
          }
        '';
      };
      pods.immich = {
        format = "immich";
        examples = [
          {
            lines = [
              "${esc}[32m[Nest] 33  - ${esc}[39m11/18/2026, 7:22:16 AM ${esc}[32m    LOG${esc}[39m ${esc}[33m[Api:RouterExplorer]${esc}[39m ${esc}[32mMapped {/api/partners, POST} route${esc}[39m"
              "[Nest] 41  - 11/18/2026, 7:22:20 AM     LOG [Microservices:InstanceLoader] JobModule dependencies initialized"
            ];
            expect = [
              {
                message = "Mapped {/api/partners, POST} route";
                level = "info";
                program = "immich-api";
                service_name = "immich";
                fields = {
                  component = "Api:RouterExplorer";
                  pid = "33";
                };
              }
              {
                message = "JobModule dependencies initialized";
                level = "info";
                program = "immich-microservices";
              }
            ];
          }
        ];
      };
    };
  };
}
