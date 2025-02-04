{
  config,
  lib,
  pkgs,
  nixpkgs',
  ...
}:

let
  linuxPackages = pkgs.linuxPackages_6_6;
  mpvPlus =
    with pkgs;
    mpv.override {
      scripts = [ mpvScripts.mpris ];
    };
in
rec {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = false;

  documentation.nixos.enable = false;
  environment.etc.issue.source = "/dev/null";

  boot.initrd.systemd.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = linuxPackages;
  boot.blacklistedKernelModules = [ "sp5100_tco" ];
  boot.extraModulePackages = [
  ];
  boot.kernelModules = [
  ];
  boot.kernelParams = [
    "mitigations=off"
    "nohibernate"
    # increase dmesg limit
    "log_buf_len=128M"
  ];
  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = false;
    # enable Alt+SysRq commands
    "kernel.sysrq" = 1;
    # silence kernel warning
    "fs.suid_dumpable" = 0;
  };
  # disable coredumps
  systemd.coredump.extraConfig = ''
    Storage=none
  '';
  security.pam.loginLimits = [
    {
      domain = "*";
      item = "core";
      type = "hard";
      value = "0";
    }
  ];
  # /tmp should be a tmpfs
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "100%";
  zramSwap.enable = true;
  # normal compression ratio: 5-6
  # use 150 / 5 = 30% of memory as compressed swap
  zramSwap.memoryPercent = 150;
  boot.kernel.sysctl = {
    "vm.swappiness" = 150;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };

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

  hardware.cpu.amd.updateMicrocode = true;
  hardware.mcelog.enable = true;
  services.fstrim.enable = true;
  # the journal tends to fill up with junk
  services.journald.extraConfig = "SystemMaxUse=100M";

  hardware.bluetooth.enable = true;

  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.wireless.networks."Charlie Brown".pskRaw = "98aa71084a9bf5ca76feea0ccfd738459d3032116827cdd12fd063e6dd9ef45e";
  networking.useDHCP = true;
  networking.dhcpcd.wait = "background";
  networking.hostName = "framework";
  networking.firewall.logRefusedConnections = false;
  networking.firewall.rejectPackets = true;
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

  security.sudo.package = pkgs.sudo.override {
    withInsults = true;
  };
  security.sudo.extraConfig = ''
    Defaults insults
    Defaults timestamp_timeout=-1
  '';

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console = {
    keyMap = "dvorak";
  };
  environment.sessionVariables = {
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_DATA_HOME = "$HOME/.local/share";

    CARGO_HOME = "$XDG_CACHE_HOME/cargo";
    CARGO_TARGET_DIR = "$CARGO_HOME/target";
    RUSTUP_HOME = "$HOME/.local/rustup";
    KDEHOME = "$HOME/.config/kde";
    #KDESYCOCA = "$HOME/.cache/kdesycoca";
    KDE_UTF8_FILENAMES = "1";
    ANDROID_SDK_HOME = "$HOME/.cache";
    GRADLE_USER_HOME = "$HOME/.cache/gradle";
    XCOMPOSECACHE = "$HOME/.cache/X11/xcompose";
    _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=$HOME/.config/java";
    GTK_USE_PORTAL = "1";

    LIBCLANG_PATH = "${lib.getLib pkgs.llvmPackages.libclang}/lib";
    LIBSQLITE3_SYS_USE_PKG_CONFIG = "1";
    ZSTD_SYS_USE_PKG_CONFIG = "1";
  };
  environment.etc = {
    "resolv.conf".text = ''
      domain fritz.box
      nameserver 192.168.178.1
      nameserver fd00::e228:6dff:fe3d:545a
      options edns0
    '';
    "zshenv.local" = {
      text = ''
        ZDOTDIR=$HOME/.config/zsh
      '';
      mode = "0444";
    };
  };

  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;
  #services.xserver.enable = true;
  #services.xserver.enableCtrlAltBackspace = true;
  services.libinput.enable = true;
  #services.xserver.libinput.accelProfile = "flat";
  services.xserver.xkb.layout = "dvorak-custom";
  services.xserver.xkb.extraLayouts = {
    dvorak-custom = {
      description = "Dvorak customized";
      languages = [ "eng" ];
      symbolsFile = pkgs.fetchurl {
        url = "https://gist.github.com/FliegendeWurst/856bd34536028b5579bdb102f324325a/raw/caa2a2c52c3450b5fb27212d43f5624586dcbee8/dvorak-custom";
        hash = "sha256-/SWLa/OefNNmBmXLP7bhD0g1bc5VpmPXNkU+Qunouok=";
      };
    };
  };
  services.xserver.autoRepeatDelay = 183;
  services.xserver.autoRepeatInterval = 33;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.theme = "${pkgs.nur.repos.fliegendewurst.sddm-theme-utah}/share/sddm/themes/sddm-theme-custom";
  services.displayManager.logToJournal = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";
  xdg.portal.enable = true;
  xdg.portal.xdgOpenUsePortal = true;
  systemd.services."drkonqi-coredump-processor@".enable = false;

  fonts.enableDefaultPackages = true;
  fonts.packages = with pkgs; [
    noto-fonts-emoji
    liberation_ttf
    cozette
    font-awesome
  ];

  #virtualisation.docker.enable = true;
  #virtualisation.docker.enableOnBoot = false;
  #virtualisation.docker.logDriver = "journald";

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

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    #amdvlk
    #vaapiVdpau
    #libvdpau-va-gl
  ];
  hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];

  hardware.sane.enable = true;

  users.mutableUsers = false;
  users.users.arne = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
      "adbusers"
      "wireshark"
      "audio"
      "cdrom"
      "dialout"
      "scanner"
      "kvm"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = "/etc/nixos/arne.passwd";
  };

  nixpkgs.config = {
    allowUnfreePredicate =
      pkg:
      builtins.elem (pkgs.lib.getName pkg) [
        "minecraft-launcher"
        "steam"
        "steam-original"
        "steam-runtime"
        "steam-run"
        "steam-unwrapped"
        "mathematica"
        "idea-ultimate"
        "android-studio-stable"
        "sddm-theme-utah"
      ];
    strictDepsByDefault = config.system.nixos.release == "25.05";
    permittedInsecurePackages = [
    ];
  };
  programs.zsh.enable = true;
  programs.zsh.enableGlobalCompInit = false;
  programs.zsh.interactiveShellInit = ''
    source ${pkgs.nix-index}/etc/profile.d/command-not-found.sh
  '';

  programs.less.enable = true;
  programs.less.lessopen = null;

  programs.tmux.enable = true;
  programs.tmux.baseIndex = 1;
  programs.tmux.clock24 = true;
  programs.tmux.escapeTime = 0;
  programs.tmux.historyLimit = 10000;
  programs.tmux.terminal = "tmux-256color";
  programs.tmux.plugins = with pkgs.tmuxPlugins; [ pkgs.nur.repos.fliegendewurst.tmux-thumbs ];

  programs.command-not-found.enable = false;
  #programs.adb.enable = true;
  programs.firefox.enable = true;
  programs.firefox.wrapperConfig.speechSynthesisSupport = false;
  programs.ssh.startAgent = true;
  # use the neat X11 password entry dialog (only need to enter 'yes')
  programs.ssh.askPassword = "${pkgs.x11_ssh_askpass}/libexec/x11-ssh-askpass";
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    pinentryPackage = pkgs.pinentry-qt;
  };

  # full list: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/desktop-managers/plasma6.nix
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    baloo-widgets
  ];
  environment.variables.EDITOR = "vim";
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
    nix-index
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
    #androidStudioPackages.stable
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
    mpvPlus
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
