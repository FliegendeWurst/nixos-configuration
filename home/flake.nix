{
  description = "FliegendeWurst's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nur,
      ...
    }@inputs:
    let
      nixpkgs-patched' =
        (import nixpkgs {
          system = "x86_64-linux";
        }).applyPatches
          {
            name = "nixos-24.11-patched";
            src = inputs.nixpkgs;
            patches = [
              # hydra-check 2.0
              (builtins.fetchurl {
                url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/359514.patch";
                sha256 = "0xasznqf7vpcykh2k0yj14s4h21gjaxynirrr93kqv3sdif0bm67";
              })
              # jujutsu 0.23 -> 0.24 -> 0.25
              (builtins.fetchurl {
                url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/361877.patch";
                sha256 = "1im5vsqz7r0m1fvifbn203ywx1b8cr8inw634iyaz8qb0gxq90lq";
              })
              (builtins.fetchurl {
                url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/368985.patch";
                sha256 = "091q88j04jn7nq1n9dd18l7g6y2l34dfm1k0fj4hik1xl5qcrm19";
              })
              (builtins.fetchurl {
                url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/370160.patch";
                sha256 = "1nbwwgql2pnbay3wivqay4mdz2jd3x8d3cdx2riawpibmwyhny0f";
              })
            ];
          };
      nixpkgs' = import nixpkgs-patched' {
        system = "x86_64-linux";
      };
    in
    {
      nixosConfigurations = {
        "nixos" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nur.modules.nixos.default

            ./configuration.nix
          ];
          specialArgs = {
            inherit nixpkgs';
          };
        };
      };
    };
}
