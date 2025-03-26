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
      nixpkgs-for-eval = import nixpkgs {
        system = "x86_64-linux";
      };
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
                  nixpkgs-for-eval.fetchpatch {
                    url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/${num}.patch";
                    sha256 = hash;
                  };
              in
              [
                # hydra-check: 2.0 -> 2.0.3
                (prPatch "359514" "sha256-LGsHfd5APiJ2tslsKIktFA2x/E7CNncYfa8/md/Q5FY=")
                (prPatch "378570" "sha256-JEYaXxxw+k5/g3/sfgDd8/UNgfMQCEA0PO7qDVSklew=")
                # jujutsu: 0.23 -> 0.24 -> 0.25 -> 0.26 -> 0.27
                (prPatch "361877" "sha256-VhgtAlDA8hMXRvHd5SDlZHR0qJRpkYTjEI6NsnOVu6Q=")
                (prPatch "368985" "sha256-8t91uLT3oUOI7QiGRFMbo4tsZaxtPU222Fb63YbS45g=")
                (prPatch "370160" "sha256-cJf+C6UpoTaZ+2a1W15pXcST9HjfZ8HkZZ4aFYb5S0I=")
                ../laptop/jujutsu-fetch-cargo-vendor.patch
                #(builtins.fetchurl {
                #  url = "https://github.com/NixOS/nixpkgs/commit/a6ef617de7a7b1514095bbf19e53e8ed80495c7a.patch?full_index=1";
                #  sha256 = "0w92m7xi5p42jfzs0ia4ypznkfcp6394y7260iymv3qc8kgca61k";
                #})
                (prPatch "379801" "1nhd1cpd0mqwc31iyj7w264xbqb6cc16b4qpad6j5a49a1cdknc8")
                (prPatch "387469" "sha256-8u0RfSySbbJmRl462Lms6Q4MlVbwoKqVP2jOKH2Qy7E=")
                ../laptop/jujutsu-fix-cargo-hash.patch
                # prusa-slicer: 2.8.0 -> 2.9.0
                ../laptop/prusa-revert-1.patch
                (prPatch "367376" "07n0frirw2hi66x3wps7q995ahd7sc2mdmj0bh060z5f97y2xj5n")
                (builtins.fetchurl {
                  url = "https://github.com/FliegendeWurst/nixpkgs/commit/prusa-slicer-native-file-dialog.patch?full_index=1";
                  sha256 = "0sdjq1rk9ncmv3fg75sv94j6kbfpsn1cvx0ppj1hdcjkmqg7vry2";
                })
                ../laptop/prusa-bgcode.patch
                # cura-appimage: init at 5.9.0 -> 5.9.1
                (prPatch "372614" "0z1ci7vwyib7pab3329676a2dn630qsh18yy24yf9qbpvavsjra3")
                (prPatch "386520" "sha256-p3feB9NhPgUBkZXdgbGoST5uhYbf/70jBBxA7n19zJ0=")
                # trilium-next-{desktop,server}: 0.90.12 -> 0.91.5 -> 0.91.6 -> (aarch64) -> 0.92.4
                (prPatch "378477" "0gf5hnhjsvfxg8pvhhn7hy3c8pk0sk3lvp2rknv5gl556rslhz9m")
                (prPatch "380940" "sha256-ja5QSlxdQ7i7OH6w5ozv0YR/V/nQVcUSKE2qN1NmuUQ=")
                (prPatch "389103" "sha256-Hp5IEKX3KDeJzbJfPkoj2C0shlp2l+Kr8Jtd3AfFhLM=")
                (prPatch "391217" "sha256-8ZZ4E/gGZ46aeZLpbNIUYHUIuOx2yS60e/x/1KpQAoI=")
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
