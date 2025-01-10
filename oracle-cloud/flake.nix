{
  description = "FliegendeWurst's NixOS Flake for the Cloud ™";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-pinned.url = "github:NixOS/nixpkgs/bffc22eb12172e6db3c5dde9e3e5628f8e3e7912";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pr-dashboard = {
      url = "github:FliegendeWurst/pr-dashboard";
      inputs.nixpkgs.follows = "nixpkgs-pinned";
    };
    wastebin = {
      url = "github:FliegendeWurst/wastebin/wip";
      inputs.nixpkgs.follows = "nixpkgs-pinned";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nur,
      pr-dashboard,
      wastebin,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        "nixos" = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            nur.modules.nixos.default

            ./configuration.nix
          ];
          specialArgs = {
            inherit pr-dashboard wastebin;
          };
        };
      };
    };
}
