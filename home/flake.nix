{
  description = "FliegendeWurst's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-pr-build-bot = {
      url = "github:FliegendeWurst/nixpkgs-pr-build-bot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nur,
      nixpkgs-pr-build-bot,
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
            patches =
              let
                prPatch =
                  num: hash:
                  builtins.fetchurl {
                    url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/${num}.patch";
                    sha256 = hash;
                  };
              in
              [
                # hydra-check 2.0
                (prPatch "359514" "0xasznqf7vpcykh2k0yj14s4h21gjaxynirrr93kqv3sdif0bm67")
                # jujutsu 0.23 -> 0.24 -> 0.25
                (prPatch "361877" "1im5vsqz7r0m1fvifbn203ywx1b8cr8inw634iyaz8qb0gxq90lq")
                (prPatch "368985" "091q88j04jn7nq1n9dd18l7g6y2l34dfm1k0fj4hik1xl5qcrm19")
                (prPatch "370160" "1nbwwgql2pnbay3wivqay4mdz2jd3x8d3cdx2riawpibmwyhny0f")
                # prusa-slicer: 2.8.0 -> 2.9.0
                (prPatch "367376" "07n0frirw2hi66x3wps7q995ahd7sc2mdmj0bh060z5f97y2xj5n")
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
            inherit nixpkgs' nixpkgs-pr-build-bot;
          };
        };
      };
    };
}
