{
  description = "FliegendeWurst's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
                prPatch2 =
                  num: hash:
                  builtins.fetchurl {
                    url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/${num}.patch?full_index=1";
                    sha256 = hash;
                  };
              in
              [
                # hydra-check: 2.0 -> 2.0.3
                #(prPatch "359514" "0xasznqf7vpcykh2k0yj14s4h21gjaxynirrr93kqv3sdif0bm67")
                #(prPatch "378570" "1li0xpkbika15nzjvpp3gpl2hqk3y9x5n3f3gsnic18bzdnn0cg8")
                # jujutsu: 0.23 -> 0.24 -> 0.25 -> 0.26 -> 0.27
                (prPatch "361877" "1im5vsqz7r0m1fvifbn203ywx1b8cr8inw634iyaz8qb0gxq90lq")
                (prPatch "368985" "091q88j04jn7nq1n9dd18l7g6y2l34dfm1k0fj4hik1xl5qcrm19")
                (prPatch "370160" "1nbwwgql2pnbay3wivqay4mdz2jd3x8d3cdx2riawpibmwyhny0f")
                ./jujutsu-fetch-cargo-vendor.patch
                #(builtins.fetchurl {
                #  url = "https://github.com/NixOS/nixpkgs/commit/a6ef617de7a7b1514095bbf19e53e8ed80495c7a.patch?full_index=1";
                #  sha256 = "0w92m7xi5p42jfzs0ia4ypznkfcp6394y7260iymv3qc8kgca61k";
                #})
                (prPatch "379801" "11gh6n7dinlj7mriknkld147jzdlbfvfv7nh05ia53l3ss4df6k2")
                (prPatch "387469" "0gcwfql632qfwpjzqv8ky9hbm0k7h2kfnj4mkrsvlbvxg65gv2gy")
                ./jujutsu-fix-cargo-hash.patch
                # prusa-slicer: 2.8.0 -> 2.9.0
                #./prusa-revert-1.patch
                #(prPatch "367376" "07n0frirw2hi66x3wps7q995ahd7sc2mdmj0bh060z5f97y2xj5n")
                #(builtins.fetchurl {
                #  url = "https://github.com/FliegendeWurst/nixpkgs/commit/prusa-slicer-native-file-dialog.patch?full_index=1";
                #  sha256 = "0sdjq1rk9ncmv3fg75sv94j6kbfpsn1cvx0ppj1hdcjkmqg7vry2";
                #})
                #./prusa-bgcode.patch
                # cura-appimage: init at 5.9.0 -> 5.9.1
                (prPatch "372614" "0z1ci7vwyib7pab3329676a2dn630qsh18yy24yf9qbpvavsjra3")
                (prPatch "386520" "0qxh70xm8mcmscj6rbrjv92vdmidk26vf0rs43rbbps4xvfxfidl")
                # trilium-next-{desktop,server}: 0.90.12 -> 0.91.5 -> 0.91.6 -> .. -> 0.93.0
                (prPatch "378477" "0gf5hnhjsvfxg8pvhhn7hy3c8pk0sk3lvp2rknv5gl556rslhz9m")
                (prPatch "380940" "0k90wbmgx99fls4hz58gbsz68ajyrwyhaaspjcc8w7px4p42vflm")
                (prPatch "389103" "06jpib0c7yaqvijb3rzyq3jdwp4r1j802f8gfvwqwwv5di6w4fmp")
                (prPatch "391217" "17vljmylmibwbbd7gvw3kkwcfn6mr9b9v9lipn7n9sfpxr0gmyil")
                (prPatch "396918" "15b9ymx6xpvlf695nvh1q3yssx0hnd2w926kyp87yyxjwfjsrvb8")
                (prPatch2 "397922" "07ba6mz9vck2x7qy2y8fsszmd7hgzvi1y1bdicch4c18npivnzx4")
                (prPatch2 "400419" "1gmdsfap4pwarx3a1svqaf3d0k08zadqw64cyspf5fdm8lydg9g6")
                # zsh-histdb: init
                (prPatch "379862" "09himfp9bnnq4ssqm19xg1h3a07iji14ycl7bg54x1n9cvx6grl0")
              ];
          };
      nixpkgs' = import nixpkgs {
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
