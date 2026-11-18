# How imap-backup's logs are parsed: Ruby's Logger, I, [2026-11-16T02:10:02.567403 #1]  INFO -- : message
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.imap-backup.enable {
    homelab.alloy.logs = {
      formats.ruby-logger = {
        firstline = "^[DIWEFA], \\[";
        stages = ''
          stage.regex {
            expression = "^[DIWEFA], \\[\\S+ #(?P<pid>\\d+)\\]\\s+(?P<level>[A-Z]+) -- (?P<component>[^:]*): (?s)(?P<message>.*)$"
          }
        '';
        levels.info = [ "any" ];
      };
      # One Job per account and run, all with this container
      pods.imap-backup = {
        format = "ruby-logger";
        examples = [
          {
            lines = [ "I, [2026-11-16T02:10:06.290845 #1]  INFO -- : [INBOX] 14 new messages" ];
            expect = [
              {
                message = "[INBOX] 14 new messages";
                level = "info";
                fields.pid = "1";
              }
            ];
          }
        ];
      };
    };
  };
}
