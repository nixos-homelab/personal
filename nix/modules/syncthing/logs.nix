# How Syncthing's logs are parsed: 2026-11-18 07:20:11 WRN message (key="value" ...)
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.syncthing.enable {
    homelab.alloy.logs = {
      formats.syncthing = {
        firstline = "^\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d [A-Z]{3} ";
        stages = ''
          stage.regex {
            expression = "^\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d (?P<level>[A-Z]{3}) (?s)(?P<message>.*?)(?: \\((?P<kv>[A-Za-z_.]+=.*)\\))?$"
          }
          stage.logfmt {
            source  = "kv"
            mapping = { "f.error" = "error", "f.log.pkg" = "log.pkg" }
          }
        '';
      };
      pods.syncthing = {
        format = "syncthing";
        examples = [
          {
            lines = [
              ''2026-11-18 07:36:11 WRN Service failed (error="dial tcp 94.130.221.203:443: connect: connection timed out" log.pkg=connections)''
              "2026-11-18 08:57:17 INF Relay listener starting (id=dynamic+https://relays.syncthing.net/endpoint log.pkg=connections)"
            ];
            expect = [
              {
                message = "Service failed";
                level = "warning";
                fields = {
                  error = "dial tcp 94.130.221.203:443: connect: connection timed out";
                  component = "connections";
                };
              }
              {
                message = "Relay listener starting";
                level = "info";
                fields.component = "connections";
              }
            ];
          }
        ];
      };
    };
  };
}
