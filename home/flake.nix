{
  description = "FliegendeWurst's NixOS Flake";

  inputs = {
    # TODO(25.05): switch to 25.05
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      nixpkgs-for-eval = import nixpkgs {
        system = "x86_64-linux";
      };
      nixpkgs-patched' =
        (import nixpkgs {
          system = "x86_64-linux";
        }).applyPatches
          {
            name = "nixos-unstable-patched";
            src = inputs.nixpkgs;
            patches =
              let
                prPatch =
                  num: hash:
                  nixpkgs-for-eval.fetchpatch {
                    url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/${num}.patch";
                    inherit hash;
                  };
              in
              [
                (builtins.fetchurl {
                  url = "https://github.com/FliegendeWurst/nixpkgs/commit/prusa-slicer-native-file-dialog.patch?full_index=1";
                  sha256 = "0sdjq1rk9ncmv3fg75sv94j6kbfpsn1cvx0ppj1hdcjkmqg7vry2";
                })
                (prPatch "381430" "sha256-w9UJ4mjqPhNTcnb2F/1hQfhHEk6cwIxaP0ZttA6qPSI=")
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

            ../common.nix
            ./configuration.nix
          ];
          specialArgs = {
            inherit nixpkgs' nixpkgs-pr-build-bot;
          };
        };
      };
    };
}
