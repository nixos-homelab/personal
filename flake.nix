{
  description = "NixOS Homelab Personal Data Workloads";
  inputs = {
    systems.url = "github:nix-systems/default-linux";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    kube-generators.url = "github:farcaller/nix-kube-generators";
    setup-secrets = {
      url = "github:andsens/nixos-setup-secrets";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    homelab-shared = {
      url = "github:nixos-homelab/shared";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.setup-secrets.follows = "setup-secrets";
      inputs.kube-generators.follows = "kube-generators";
      inputs.homelab-monitoring.follows = "homelab-monitoring";
    };
    homelab-storage = {
      url = "github:nixos-homelab/storage";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.setup-secrets.follows = "setup-secrets";
      inputs.kube-generators.follows = "kube-generators";
      inputs.homelab-shared.follows = "homelab-shared";
      inputs.homelab-monitoring.follows = "homelab-monitoring";
      inputs.docs.follows = "docs";
    };
    homelab-monitoring = {
      url = "github:nixos-homelab/monitoring";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.setup-secrets.follows = "setup-secrets";
      inputs.kube-generators.follows = "kube-generators";
      inputs.homelab-shared.follows = "homelab-shared";
      inputs.homelab-storage.follows = "homelab-storage";
      inputs.docs.follows = "docs";
    };
    docs = {
      url = "github:andsens/nix-docs";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };
  outputs =
    {
      systems,
      flake-parts,
      nixpkgs,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        flake-parts-lib,
        self,
        inputs,
        lib,
        ...
      }:
      let
        inherit (flake-parts-lib) importApply;
      in
      {
        systems = import systems;
        flake = {
          lib = {
            importsApply = map (path: importApply path { inherit self inputs; });
          };
          nixosModules = {
            syncthing = importApply ./nix/modules/syncthing { inherit self inputs; };
            homepage = importApply ./nix/modules/homepage { inherit self inputs; };
            imap-backup = importApply ./nix/modules/imap-backup { inherit self inputs; };
            immich = importApply ./nix/modules/immich { inherit self inputs; };
          };
        };
        perSystem =
          { pkgs, lib, ... }:
          let
            # Every module of this flake on
            testModules = lib.attrValues self.nixosModules ++ [
              {
                homelab = {
                  # Evaluates the metrics parts of the modules, off with Alloy
                  alloy.enable = true;
                  syncthing.enable = true;
                  immich.enable = true;
                  imap-backup.enable = true;
                  imap-backup.accounts.example = {
                    username = "user@example.org";
                    server = "imap.example.org";
                  };
                  homepage.enable = true;
                };
              }
            ];
          in
          {
            # One lock node per homelab repo
            checks.flake-lock = inputs.homelab-shared.lib.checks.flakeLock {
              inherit pkgs;
              lockFile = ./flake.lock;
            };
            # Dead Nix code. Pattern names stay: modules take { config, lib, pkgs, ... } whether they use them or not
            checks.deadnix = pkgs.runCommand "deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
              deadnix --fail --no-lambda-pattern-names ${self}
              touch $out
            '';
            # The PromQL of this flake's alert rules through promtool, with Grafana on to have them
            checks.promql = inputs.homelab-monitoring.lib.alerts.check {
              inherit pkgs;
              config =
                (inputs.nixpkgs.lib.nixosSystem {
                  modules =
                    lib.attrValues inputs.homelab-shared.nixosModules
                    ++ testModules
                    ++ [
                      inputs.homelab-shared.lib.checks.fixture
                      { nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system; }
                      {
                        homelab.alloy.enable = true;
                        homelab.grafana.enable = true;
                      }
                    ];
                }).config;
            };
            checks.manifests = inputs.homelab-shared.lib.checks.manifests {
              inherit pkgs;
              modules = testModules;
            };
            # The parsers of this flake's workloads on their examples, through the pinned Alloy and Loki
            checks.logs = inputs.homelab-monitoring.lib.logs.check {
              inherit pkgs;
              modules = testModules;
            };
            packages = {
              options-docs = inputs.docs.lib.docs.options {
                inherit pkgs;
                modules = lib.attrValues self.nixosModules;
                repoPath = toString self;
                repoLinkPrefix = "https://github.com/nixos-homelab/personal/blob/main";
                prefixGroups = {
                  syncthing = [
                    "homelab.syncthing"
                    "homelab.homepage.integrations.syncthing"
                  ];
                  imap-backup = [ "homelab.imap-backup" ];
                  immich = [
                    "homelab.immich"
                    "homelab.homepage.integrations.immich"
                  ];
                  homepage = [ "homelab.homepage.sections" ];
                };
              };
              manual-docs = inputs.docs.lib.mkdocs.manual {
                inherit pkgs;
                rootDoc = ./README.md;
              };
            };
          };
      }
    );
}
