# nixos-homelab-personal

Personal data services on top of [nixos-homelab](https://github.com/nixos-homelab/shared):
photo backup, file sync, and mail backup.

For the full list of module options, see [docs/options.md](docs/options.md).

## Setup

```nix
{
  inputs = {
    ...
    homelab-personal = {
      url = "github:nixos-homelab/personal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ...
  };
}
```

```nix
{ inputs, ... }:
{
  imports = [ inputs.homelab-personal.nixosModules.immich ];
  config.homelab.immich.enable = true;
}
```

## Modules

- **immich**: [Immich](https://immich.app), self-hosted photo and video
  backup.
- **syncthing**: continuous file synchronization between devices.
- **imap-backup**: backs up IMAP mail accounts on a schedule.
