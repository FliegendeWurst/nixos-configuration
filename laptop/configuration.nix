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

  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.wireless.networks = {
    "Charlie Brown".pskRaw = "98aa71084a9bf5ca76feea0ccfd738459d3032116827cdd12fd063e6dd9ef45e";
    "WLAN-HXMPZB".pskRaw = "388eeaec0e32f4e95275c553ee4f1dcf6e03c8c2e26676266c01dbe540d6573a";
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
  ];
  networking.firewall.allowedTCPPortRanges = [
    # KDE Connect
    {
      from = 1714;
      to = 1764;
    }
  ];
  networking.firewall.allowedUDPPorts = [
  ];
  networking.firewall.allowedUDPPortRanges = [
    # KDE Connect
    {
      from = 1714;
      to = 1764;
    }
  ];

  services.libinput.enable = true;
  #services.xserver.libinput.accelProfile = "flat";
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.theme = "${pkgs.nur.repos.fliegendewurst.sddm-theme-utah}/share/sddm/themes/sddm-theme-custom";
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

  programs.tmux.enable = true;
  programs.tmux.baseIndex = 1;
  programs.tmux.clock24 = true;
  programs.tmux.escapeTime = 0;
  programs.tmux.historyLimit = 10000;
  programs.tmux.terminal = "tmux-256color";
  programs.tmux.plugins = with pkgs.tmuxPlugins; [ pkgs.nur.repos.fliegendewurst.tmux-thumbs ];

  programs.adb.enable = true;

  services.syncthing = {
    key = "/etc/nixos/syncthing/key.pem";
    cert = "/etc/nixos/syncthing/cert.pem";
  };
  #services.mopidy = {
  #  enable = true;
  #  extensionPackages = with pkgs; [ nixpkgs'.pkgs.mopidy-bandcamp mopidy-iris ];
  #  extraConfigFiles = [ "/home/arne/mopidy.conf" ];
  #};
  #users.users.mopidy.extraGroups = [ "pipewire" ];

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
    p7zip
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
    # TODO(25.05): use regular version
    nixpkgs'.pkgs.jujutsu
    schedtool
    compsize
    # TODO(25.05): use regular version
    nixpkgs'.pkgs.hydra-check
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
    androidStudioPackages.stable
    clang
    #gnumake cmake
    llvmPackages.bintools

    #cplex
    #key
    #cvc5
    #zotero

    # CLI applications
    #lynx
    #droidcam
    sqlite
    borgbackup
    nix-tree
    rnix-hashes
    #nixpkgs-review
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
    nixpkgs'.pkgs.trilium-next-desktop
    qdirstat
    #filelight
    #libreoffice-fresh
    #qbittorrent
    tdesktop
    signal-desktop
    alacritty
    kdePackages.kwalletmanager
    kdePackages.okular
    kdePackages.akregator
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
    #ksshaskpass
    notepadqq
    #skrooge
    inkscape
    element-desktop
    nixpkgs'.pkgs.cura-appimage

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

    nixpkgs'.pkgs.prusa-slicer
  ];
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
