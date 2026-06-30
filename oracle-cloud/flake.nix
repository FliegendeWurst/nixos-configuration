{
  description = "FliegendeWurst's NixOS Flake for the Cloud ™";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-pinned.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pr-dashboard = {
      url = "github:FliegendeWurst/pr-dashboard";
      inputs.nixpkgs.follows = "nixpkgs-pinned";
    };
    reddit-image-grid = {
      url = "git+https://codeberg.org/FliegendeWurst/reddit-image-grid.git";
      inputs.nixpkgs.follows = "nixpkgs-pinned";
    };
    wastebin = {
      url = "github:FliegendeWurst/wastebin/wip";
      inputs.nixpkgs.follows = "nixpkgs-pinned";
    };
    nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nur,
      pr-dashboard,
      reddit-image-grid,
      wastebin,
      nixos-mailserver,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        "nixos" = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            nur.modules.nixos.default
            nixos-mailserver.nixosModules.default

            ./configuration.nix
          ];
          specialArgs = {
            inherit pr-dashboard reddit-image-grid wastebin nixos-mailserver;
          };
        };
      };
    };
}
