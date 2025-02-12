{
  description = "FliegendeWurst's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sysinfo = {
      url = "github:FliegendeWurst/sysinfo";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nur,
      nixos-hardware,
      nix-index-database,
      sysinfo,
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
                # hydra-check: 2.0
                (prPatch "359514" "0xasznqf7vpcykh2k0yj14s4h21gjaxynirrr93kqv3sdif0bm67")
                # jujutsu: 0.23 -> 0.24 -> 0.25 -> 0.26
                (prPatch "361877" "1im5vsqz7r0m1fvifbn203ywx1b8cr8inw634iyaz8qb0gxq90lq")
                (prPatch "368985" "091q88j04jn7nq1n9dd18l7g6y2l34dfm1k0fj4hik1xl5qcrm19")
                (prPatch "370160" "1nbwwgql2pnbay3wivqay4mdz2jd3x8d3cdx2riawpibmwyhny0f")
                ./jujutsu-fetch-cargo-vendor.patch
                #(builtins.fetchurl {
                #  url = "https://github.com/NixOS/nixpkgs/commit/a6ef617de7a7b1514095bbf19e53e8ed80495c7a.patch?full_index=1";
                #  sha256 = "0w92m7xi5p42jfzs0ia4ypznkfcp6394y7260iymv3qc8kgca61k";
                #})
                (prPatch "379801" "11gh6n7dinlj7mriknkld147jzdlbfvfv7nh05ia53l3ss4df6k2")
                ./jujutsu-fix-cargo-hash.patch
                # prusa-slicer: 2.8.0 -> 2.9.0
                (prPatch "367376" "07n0frirw2hi66x3wps7q995ahd7sc2mdmj0bh060z5f97y2xj5n")
                (builtins.fetchurl {
                  url = "https://github.com/FliegendeWurst/nixpkgs/commit/prusa-slicer-native-file-dialog.patch?full_index=1";
                  sha256 = "0sdjq1rk9ncmv3fg75sv94j6kbfpsn1cvx0ppj1hdcjkmqg7vry2";
                })
                ./prusa-bgcode.patch
                # cura-appimage: init at 5.9.0
                (prPatch "372614" "0z1ci7vwyib7pab3329676a2dn630qsh18yy24yf9qbpvavsjra3")
                # electron_34: init
                (prPatch "376770" "125qhz6w9iikrgl0xhp6pcqhm4qxwkafi9a6480qsb826wxs8yw0")
                # trilium-next-{desktop,server}: 0.90.12 -> 0.91.5
                (prPatch "378477" "0gf5hnhjsvfxg8pvhhn7hy3c8pk0sk3lvp2rknv5gl556rslhz9m")
                # zsh-histdb: init
                (prPatch "379862" "09himfp9bnnq4ssqm19xg1h3a07iji14ycl7bg54x1n9cvx6grl0")
                # mopidy-bandcamp: fix
                #./mopidy-bandcamp.patch
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

            nix-index-database.nixosModules.nix-index
            nixos-hardware.nixosModules.framework-13-7040-amd
          ];
          specialArgs = {
            inherit nixpkgs' sysinfo;
          };
        };
      };
    };
}
