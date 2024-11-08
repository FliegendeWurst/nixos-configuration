{ config, lib, pkgs, ... }:

let
  gaming = true;
  linuxPackages = pkgs.linuxPackages_6_6;
  mpvPlus = with pkgs; mpv.override {
    scripts = [ mpvScripts.mpris ];
  };
  python3-pkgs = with pkgs.python3-packages; [
    z3
    #requests
    #beautifulsoup4
    tkinter
    #lxml
    #pyside2
    #markdown
    #psutil

    #scipy
    #numpy
    #pillow
  ];
  python3-with-pkgs = pkgs.python3.withPackages python3-pkgs;
  nur = config.nur;
in
rec {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  documentation.nixos.enable = false;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = linuxPackages;
  boot.blacklistedKernelModules = [ "sp5100_tco" ];
  boot.extraModulePackages = [ linuxPackages.v4l2loopback (
    nur.repos.fliegendewurst.microsoft-ergonomic-keyboard.override { kernel = linuxPackages.kernel; }
  )];
  boot.kernelModules = [ "v4l2loopback" "nct6775" "hid_microsoft_ergonomic" ];
  boot.kernelParams = [
    "mitigations=off"
    "amdgpu.noretry=0"
    # this system has 128GB of RAM, I'm not writing that to disk
    "nohibernate"
  ];
  boot.kernel.sysctl = {
    # enable Alt+SysRq commands
    "kernel.sysrq" = 1;
    "vm.swappiness" = 1;
    # for funky network experiments
    #"net.ipv4.ip_forward" = 1;
    # silence kernel warning
    "fs.suid_dumpable" = 0;
  };
  # disable coredumps
  systemd.coredump.extraConfig = ''
    Storage=none
  '';
  systemd.enableUnifiedCgroupHierarchy = lib.mkForce true;
  security.pam.loginLimits = [
    { domain = "*"; item = "core"; type = "hard"; value = "0"; }
  ];
  # /tmp should be a tmpfs
  boot.tmp.useTmpfs = true;
  # disable CPU boost by default
  systemd.services.disableCPUBoost = {
    description = "Disable CPU Boost";
    script = ''
      echo 0 > /sys/devices/system/cpu/cpufreq/boost
    '';
    serviceConfig = {
      Type = "oneshot";
    };
    wantedBy = [ "basic.target" ];
  };

  hardware.cpu.amd.updateMicrocode = true;
  hardware.mcelog.enable = true;
  services.fstrim.enable = true;
  # the journal tends to fill up with junk
  services.journald.extraConfig = "SystemMaxUse=100M";
  
  #services.triggerhappy.enable = true;
  #services.triggerhappy.user = "root";
  #services.triggerhappy.bindings = [
  #  { keys = ["LEFTMETA" "RIGHTSHIFT" "F21"];  cmd = "${pkgs.bash}/bin/bash -c 'sync && sleep 1 && ${pkgs.systemd}/bin/systemctl suspend && ${pkgs.systemd}/bin/loginctl lock-session'"; }
  #];

  hardware.bluetooth.enable = false;

  networking.useDHCP = true;
  networking.dhcpcd.wait = "background";
  # systemd.services.accounts-daemon.wantedBy = lib.mkForce [ ];
  # systemd.services.network-local-commands.enable = lib.mkForce false;
  # services.logrotate.enable = lib.mkForce false;
  #networking.interfaces.enp39s0.useDHCP = true;
  #networking.interfaces.enp42s0f3u2.useDHCP = false;
  #networking.interfaces.enp42s0f3u2.proxyARP = true;
  #networking.interfaces.enp42s0f3u2.ipv4.routes = [
  #  {
  #    address = "10.0.0.0";
  #    prefixLength = 24;
  #  }
  #];
  #networking.interfaces.enp42s0f3u2.ipv4.addresses = [
  #  {
  #    address = "10.0.0.1";
  #    prefixLength = 24;
  #  }
  #];
  # 
  networking.hostName = "nixOS";
  networking.firewall.logRefusedConnections = false;
  networking.firewall.rejectPackets = true;
  networking.firewall.allowedTCPPorts = [ 12783 12975 25565 ];
  networking.firewall.allowedTCPPortRanges = [
    # KDE Connect
    { from = 1714; to = 1764; }
  ];
  networking.firewall.allowedUDPPorts = [ 12975 ];
  networking.firewall.allowedUDPPortRanges = [
    # KDE Connect
    { from = 1714; to = 1764; }
  ];
  # Or disable the firewall altogether.
  #networking.firewall.enable = false;

  security.sudo.package = pkgs.sudo.override {
    withInsults = true;
  };
  security.sudo.extraConfig = ''
    Defaults insults
    Defaults timestamp_timeout=-1
  '';

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  #i18n.supportedLocales = [
  #  "C.UTF-8/UTF-8"
  #  "de_DE.UTF-8/UTF-8"
  #  "en_US.UTF-8/UTF-8"
  #  "en_GB.UTF-8/UTF-8"
  #];
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
    "sysconfig/lm_sensors".text = ''
      HWMON_MODULES="nct6775"
    '';
  };

  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;
  services.xserver.enable = true;
  services.xserver.enableCtrlAltBackspace = true;
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
  services.displayManager.sddm.theme = "${nur.repos.fliegendewurst.sddm-theme-utah}/share/sddm/themes/sddm-theme-custom";
  services.displayManager.logToJournal = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasmax11";
  services.displayManager.sddm.wayland.enable = false;
  xdg.portal.enable = true;
  xdg.portal.xdgOpenUsePortal = true;

  fonts.enableDefaultPackages = true;
  fonts.packages = with pkgs; [
    noto-fonts-emoji
    liberation_ttf
    cozette
    font-awesome
  ];

  #virtualisation.virtualbox.host.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = false;
  virtualisation.docker.logDriver = "journald";
  #virtualisation.anbox.enable = true;

  # services.printing.enable = true;
  services.trilium-server.enable = true;
  services.trilium-server.host = "0.0.0.0";
  services.trilium-server.port = 12783;
  services.boinc.enable = false;
  services.vnstat.enable = true;
  services.gitlab-runner.enable = false;
  services.gitlab-runner.services = {
    shell = {
      registrationConfigFile = "/home/arne/Documents/gitlab-runner-registration";
      executor = "shell";
      buildsDir = "/tmp/builds_dir";
    };
    #shell2 = {
    #  registrationConfigFile = "/home/arne/Documents/gitlab-runner-registration-kv";
    #  executor = "shell";
    #};
  };
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
  # services.logmein-hamachi.enable = true;

  sound.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # this does not exist (yet?)
    #pulse.support32Bit = true;
  };

  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages = with pkgs; [ amdvlk vaapiVdpau libvdpau-va-gl ];
  hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];

  hardware.sane.enable = true;

  users.users.arne = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "adbusers" "wireshark" "audio" "cdrom" "dialout" "scanner" "kvm" ];
    shell = pkgs.zsh;
  };

  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
      "minecraft-launcher"
      "steam"
      "steam-original"
      "steam-runtime"
      "steam-run"
      "mathematica"
      "idea-ultimate"
      "android-studio-stable"
      "sddm-theme-utah"
    ];
    permittedInsecurePackages = [
      "qbittorrent-4.6.4"
    ];
    overlays = [ nur.overlay ];
  };
  programs.steam.enable = gaming;
  programs.zsh.enable = true;
  programs.zsh.enableGlobalCompInit = false;
  programs.zsh.interactiveShellInit = ''
    source ${pkgs.nix-index}/etc/profile.d/command-not-found.sh
  '';

  programs.tmux.enable = true;
  programs.tmux.baseIndex = 1;
  programs.tmux.clock24 = true;
  programs.tmux.escapeTime = 0;
  programs.tmux.historyLimit = 10000;
  programs.tmux.terminal = "tmux-256color";
  programs.tmux.plugins = with pkgs.tmuxPlugins; [ nur.repos.fliegendewurst.tmux-thumbs ];

  programs.command-not-found.enable = false;
  programs.adb.enable = true;
  programs.k3b.enable = true;
  programs.firefox.enable = true;
  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark;
  programs.ssh.startAgent = true;
  # use the neat X11 password entry dialog (only need to enter 'yes')
  programs.ssh.askPassword = "${pkgs.x11_ssh_askpass}/libexec/x11-ssh-askpass";
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    pinentryPackage = pkgs.pinentry-qt;
  };
  # do not show unlock prompt on login
  security.pam.services.sddm.enableKwallet = lib.mkOverride 0 false;

  services.paperless.enable = true;
  services.paperless.consumptionDirIsPublic = true;
  services.paperless.settings = {
    PAPERLESS_TRAIN_TASK_CRON = "5 16 * * *";
    PAPERLESS_EMAIL_TASK_CRON = "disable";
    # https://github.com/NixOS/nixpkgs/issues/240591
    PAPERLESS_WORKER_TIMEOUT = "90";
  };

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
    vim htop radeontop curl wget file zsh git git-branchless
    tree killall
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
    pandoc
    poppler_utils
    libnotify
    ddrescue
    nvme-cli
    zola

    #nur.repos.fliegendewurst.ripgrep-all
    nur.repos.fliegendewurst.map
    nur.repos.fliegendewurst.diskgraph
    nur.repos.fliegendewurst.freqtop
    openscad-unstable

    # programming environments
    python3
    #python3-with-pkgs
    pipenv
    jdk17
    #visualvm
    rustup
    cargo-outdated cargo-edit cargo-feature
    #jupyter
    vscodium
    jetbrains.idea-ultimate
    androidStudioPackages.stable
    clang
    #gnumake cmake
    llvmPackages.bintools

    #cplex
    #key
    #cvc5
    #zotero

    # CLI applications
    lynx
    droidcam
    sqlite
    borgbackup
    nix-tree rnix-hashes nixpkgs-review
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
    thunderbird
    #ungoogled-chromium
    keepassxc
    josm
    #anki
    #tor-browser-bundle-bin
    #mathematica
    gparted
    trilium-desktop
    qdirstat
    filelight
    #libreoffice-fresh
    qbittorrent
    tdesktop
    signal-desktop
    alacritty
    kwalletmanager
    okular akregator gwenview ark kcalc kcolorchooser kompare kcharselect kmag
    plasma5Packages.kruler
    kdeconnect
    plasma-vault
    #ksshaskpass
    notepadqq kate
    skrooge
    mpvPlus
    inkscape

    #xorg.xkbcomp
    xorg.xrandr
    #evtest
    lm_sensors

    xclip
    ntfs3g
    cryptsetup pinentry-qt
    cdrkit
    vnstat
    aspellDicts.de
    hunspellDicts.de-de
    #linuxPackages.perf
    #perf-tools
    smartmontools
    #libfaketime
    #afl

    # Games
    (prismlauncher.override { jdks = [ jdk8 jdk22 ]; })
    #minecraft
    #logmein-hamachi

    update-resolv-conf # for OpenVPN configs

    # List of packages to get on demand
    #wineWowPackages.full
    #winetricks
    #texlive.combined.scheme-full

    prusa-slicer
    blender
    xml2rfc
  ];
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
