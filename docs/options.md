## homelab\.homepage\.integrations\.immich\.enable

integration of immich with homepage



*Type:*
boolean



*Default:*
` config.homelab.immich.enable && config.homelab.homepage.enable `

*Declared by:*
 - [nix/modules/immich/homepage\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/immich/homepage.nix)



## homelab\.imap-backup\.enable



Whether to enable imap-backup\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.imap-backup\.accounts



Attrset of named accounts to back up



*Type:*
attribute set of (submodule)

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.imap-backup\.accounts\.\<name>\.extraSettings



Additional settings not covered by the current options



*Type:*
attribute set of anything



*Default:*
` { } `

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.imap-backup\.accounts\.\<name>\.folders



List of folders that have been configured for the Account



*Type:*
list of string



*Default:*
` [ ] `

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.imap-backup\.accounts\.\<name>\.localPath



Relative path where backups will be saved



*Type:*
string



*Default:*
` "‹name›" `

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.imap-backup\.accounts\.\<name>\.mirrorMode



Whether to enable mirror mode\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.imap-backup\.accounts\.\<name>\.multiFetchSize



Number of emails to fetch from the IMAP server at a time



*Type:*
signed integer



*Default:*
` 1 `

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.imap-backup\.accounts\.\<name>\.server



Address of the IMAP server



*Type:*
string

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.imap-backup\.accounts\.\<name>\.status



Status of the account



*Type:*
one of “active”, “archived”, “offline”



*Default:*
` "active" `

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.imap-backup\.accounts\.\<name>\.username



The username of the account



*Type:*
string



*Default:*
` "‹name›" `

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.imap-backup\.schedule



Cronjob notation of when the imap-backup should run



*Type:*
null or string



*Default:*
` "10 3 * * *" `



*Example:*
` "10 3 * * *" `

*Declared by:*
 - [nix/modules/imap-backup/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/imap-backup/default.nix)



## homelab\.immich\.enable



Whether to enable Immich\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/immich/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/immich/default.nix)



## homelab\.syncthing\.enable



Whether to enable Syncthing\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `

*Declared by:*
 - [nix/modules/syncthing/default\.nix](https://github.com/nixos-homelab/personal/blob/main/nix/modules/syncthing/default.nix)


