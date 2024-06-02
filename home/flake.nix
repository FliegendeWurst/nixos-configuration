{
  description = "FliegendeWurst's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:FliegendeWurst/nixpkgs/nixos-24.05-patched";
    nur.url = "github:nix-community/NUR";
  };

  outputs = { self, nixpkgs, nur, ... }@inputs: {
    nixosConfigurations = {
      "nixos" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        #specialArgs = inputs;
        modules = [
          nur.nixosModules.nur

          ./configuration.nix
        ];
      };
    };
  };
}
