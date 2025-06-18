{
  config,
  lib,
  pkgs,
  nixpkgs',
  sysinfo,
  ...
}:

let
  linuxPackages = pkgs.linuxPackages_6_6;
  sddm-theme = pkgs.nur.repos.fliegendewurst.sddm-theme-utah.overrideAttrs (
    finalAttrs: previousAttrs: {
      src = /home/arne/Pictures/Utah_Desert_Contact_Info.jpg;
      installPhase =
        previousAttrs.installPhase
        + ''
          substituteInPlace $out/share/sddm/themes/sddm-theme-custom/Main.qml \
            --replace-fail 'state: loginScreenRoot.uiVisible ? "on" : "off"' 'state: "off"' \
            --replace-fail 'config.type === "image"' 'false'
        '';
    }
  );
in
rec {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.memtest86.enable = true;
  boot.kernelPackages = linuxPackages;
  boot.blacklistedKernelModules = [ "sp5100_tco" ];
  boot.extraModulePackages = [
    linuxPackages.ryzen-smu
  ];
  boot.kernelModules = [
    "ryzen_smu"
  ];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };
  services.beesd.filesystems = {
    root = {
      spec = "UUID=cd5c01b2-e97e-45f2-84d5-720a731fff03";
      hashTableSizeMB = 4096;
      verbosity = "crit";
    };
  };
  systemd.services."beesd@root".wantedBy = lib.mkForce [ ];

  services.pipewire.systemWide = true;

  services.fwupd.enable = true;

  hardware.bluetooth.enable = true;

  networking.wireless.enable = true; # Enables wireless support via wpa_supplicant.
  networking.wireless.networks = {
    "Charlie Brown".pskRaw = "98aa71084a9bf5ca76feea0ccfd738459d3032116827cdd12fd063e6dd9ef45e";
    "WLAN-HXMPZB".pskRaw = "388eeaec0e32f4e95275c553ee4f1dcf6e03c8c2e26676266c01dbe540d6573a";
    "WLAN-676951".pskRaw = "a74b46a551b3d487ad9f070d383c9b5512e2bc49ce4b330cebeb6f052236933d";
    "Belvedere".pskRaw = "145212fc6bf6dbcb925e761c072281d7086cbb9e3c89e04514a3d8dd193c5a67";
    eduroam.auth = ''
      key_mgmt=WPA-EAP
      pairwise=CCMP TKIP
      group=CCMP TKIP
      eap=TTLS
      phase2="auth=PAP"
      anonymous_identity="anonymous@kit.edu"
      identity="uskyk@kit.edu"
      password="${builtins.readFile "/home/arne/Documents/KIT-password.txt"}"
    '';
    innohub-GUEST.auth = ''
      key_mgmt=NONE
    '';
    "WIFI@DB".auth = ''
      key_mgmt=NONE
    '';
  };
  networking.hostName = "framework";
  networking.firewall.allowedTCPPorts = [
    # misc. HTTP stuff
    8080
    # wireless ADB
    5037
    # Boludo
    20122
    # Trilium
    12783
  ];
  networking.firewall.allowedTCPPortRanges = [
    # KDE Connect
    {
      from = 1714;
      to = 1764;
    }
  ];
  networking.firewall.allowedUDPPorts = [
    # ADB
    5353
  ];
  networking.firewall.allowedUDPPortRanges = [
    # KDE Connect
    {
      from = 1714;
      to = 1764;
    }
  ];

  networking.interfaces."enp195s0f3u1" = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = "169.254.1.2";
        prefixLength = 16;
      }
    ];
  };
  systemd.services.network-addresses-enp195s0f3u1.wantedBy = lib.mkForce [ ];

  # static IPv6 interface
  #networking.interfaces.enp193s0f3u2 = {
  #  useDHCP = false;
  #  ipv6 = {
  #    addresses = [
  #      {
  #        address = "fd9a:de16:dfa3:11::1";
  #        prefixLength = 48;
  #      }
  #    ];
  #  };
  #};

  services.libinput.enable = true;
  #services.xserver.libinput.accelProfile = "flat";
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.theme = "${sddm-theme}/share/sddm/themes/sddm-theme-custom";
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";

  fonts.enableDefaultPackages = true;
  fonts.packages = with pkgs; [
    noto-fonts-emoji
    liberation_ttf
    cozette
    font-awesome
  ];

  services.printing.enable = true;
  services.vnstat.enable = true;
  services.openvpn.servers = {
    kit-split = {
      config = ''
        config /home/arne/Documents/KIT/kit-split.ovpn
      '';
      autoStart = false;
    };
    kit = {
      config = ''
        config /home/arne/Documents/KIT/kit.ovpn
      '';
      autoStart = false;
    };
  };

  users.mutableUsers = false;
  users.users.arne = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
      "adbusers"
      "wireshark"
      "audio"
      "pipewire"
      "cdrom"
      "dialout"
      "scanner"
      "kvm"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = "/etc/nixos/arne.passwd";
    homeMode = "701";
  };

  environment.variables = {
    # Make the desktop app a sync server on this port.
    TRILIUM_PORT = "12783";
  };

  programs.tmux.enable = true;
  programs.tmux.baseIndex = 1;
  programs.tmux.clock24 = true;
  programs.tmux.escapeTime = 0;
  programs.tmux.historyLimit = 10000;
  programs.tmux.terminal = "tmux-256color";
  programs.tmux.plugins = with pkgs.tmuxPlugins; [ pkgs.nur.repos.fliegendewurst.tmux-thumbs ];

  programs.adb.enable = true;

  services.syncthing = {
    dataDir = "/home/arne";
    key = "/etc/nixos/syncthing/key.pem";
    cert = "/etc/nixos/syncthing/cert.pem";
  };

  #TODO(25.05) programs.steam.enable = true;

  # full list: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/desktop-managers/plasma6.nix
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    baloo-widgets
  ];
  environment.systemPackages = with pkgs; [
    # standard utilities
    (coreutils.override {
      openssl = null;
      withOpenssl = false;
    })
    gzip
    man-pages
    dnsutils
    vim
    htop
    radeontop
    curl
    wget
    file
    zsh
    git
    tree
    killall
    # premium utilities
    duf
    delta
    jq
    ripgrep
    iotop
    img2pdf
    pdftk
    eza
    fd
    zoxide
    fzf
    entr
    oxipng
    ffmpeg_4
    unzip
    poppler_utils
    libnotify
    ddrescue
    nvme-cli
    zola
    colorized-logs
    jujutsu
    schedtool
    compsize
    hydra-check
    e2fsprogs # filefrag
    moreutils # parallel
    evtest
    xdotool
    fw-ectool
    ryzenadj
    wl-clipboard
    sysinfo.packages.x86_64-linux.sysinfo

    #nur.repos.fliegendewurst.ripgrep-all
    #nur.repos.fliegendewurst.map
    #nur.repos.fliegendewurst.diskgraph
    #nur.repos.fliegendewurst.freqtop
    openscad-unstable

    # programming environments
    python3
    #python3-with-pkgs
    #pipenv
    #jdk17
    #visualvm
    rustup
    #cargo-outdated
    #jupyter
    vscodium
    #jetbrains.idea-ultimate
    #TODO(25.05) androidStudioPackages.stable
    clang
    #gnumake cmake
    llvmPackages.bintools

    #cplex
    #key
    #cvc5
    #zotero

    # CLI applications
    #lynx
    borgbackup
    nixpkgs-review
    nixfmt-rfc-style
    #gallery-dl
    yt-dlp
    #plantuml
    #tectonic
    #docker-compose
    #qemu
    graphviz
    fend

    # GUI applications
    sqlitebrowser
    #(gimp-with-plugins.override { plugins = [ gimpPlugins.gmic ]; })
    gimp
    (thunderbird.override {
      cfg.speechSynthesisSupport = false;
    })
    #ungoogled-chromium
    keepassxc
    #josm
    #anki
    #tor-browser-bundle-bin
    #mathematica
    gparted
    qdirstat
    #filelight
    libreoffice-qt-fresh
    qbittorrent
    tdesktop
    signal-desktop
    alacritty
    kdePackages.kwalletmanager
    kdePackages.okular
    kdePackages.gwenview
    kdePackages.ark
    kdePackages.kate
    kdePackages.kcalc
    kdePackages.kcolorchooser
    kdePackages.kompare
    kdePackages.kcharselect
    kdePackages.kmag
    kdePackages.k3b
    kdePackages.kruler
    kdePackages.kdeconnect-kde
    kdePackages.plasma-vault
    kdePackages.ksshaskpass
    #ksshaskpass
    notepadqq
    skrooge
    inkscape
    element-desktop
    cura-appimage

    #xorg.xkbcomp
    #xorg.xrandr
    #evtest
    lm_sensors

    #xclip
    #ntfs3g
    cryptsetup
    pinentry-qt
    cdrkit
    vnstat
    aspellDicts.de
    hunspellDicts.de-de
    #linuxPackages.perf
    #perf-tools
    smartmontools
    #libfaketime
    #afl

    update-resolv-conf # for OpenVPN configs

    # List of packages to get on demand
    #wineWowPackages.full
    #winetricks
    #texlive.combined.scheme-full

    prusa-slicer
  ];
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  services.udev.packages = with pkgs; [ platformio-core.udev ];
}
