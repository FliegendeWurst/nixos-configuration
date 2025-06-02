{
  description = "FliegendeWurst's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05-small";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-pr-build-bot = {
      url = "github:FliegendeWurst/nixpkgs-pr-build-bot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sysinfo = {
      url = "git+https://codeberg.org/FliegendeWurst/sysinfo.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.93.0.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-tree = {
      url = "github:utdemir/nix-tree";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nur,
      nixpkgs-pr-build-bot,
      sysinfo,
      lix-module,
      nix-tree,
      ...
    }@inputs:
    let
      nixpkgs-patched' =
        (import nixpkgs {
          system = "x86_64-linux";
        }).applyPatches
          {
            name = "nixos-patched";
            src = inputs.nixpkgs;
            patches =
              let
                prPatch =
                  num: hash:
                  builtins.fetchurl {
                    url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/${num}.patch?full_index=1";
                    inherit hash;
                  };
              in
              [
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
            lix-module.nixosModules.default

            ../common.nix
            ./configuration.nix
          ];
          specialArgs = {
            inherit
              nixpkgs'
              nixpkgs-pr-build-bot
              sysinfo
              nix-tree
              ;
          };
        };
      };
    };
}
