{
  config,
  lib,
  pkgs,
  nixpkgs',
  nixpkgs-pr-build-bot,
  ...
}:

let
  gaming = true;
  linuxPackages = pkgs.linuxPackages_6_6;
  mpvPlus =
    with pkgs;
    mpv.override {
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
in
rec {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  nix.nrBuildUsers = 64;
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
    linuxPackages.v4l2loopback
    (pkgs.nur.repos.fliegendewurst.microsoft-ergonomic-keyboard.override {
      kernel = linuxPackages.kernel;
    })
  ];
  boot.kernelModules = [
    "v4l2loopback"
    "nct6775"
    "hid_microsoft_ergonomic"
  ];
  boot.kernelParams = [
    # bad bit in 0x193e4e5540
    "memmap=0x1000$0x193e4e5000"
    "mitigations=off"
    "amdgpu.noretry=0"
    # this system has 128GB of RAM, I'm not writing that to disk
    "nohibernate"
    # increase dmesg limit
    "log_buf_len=128M"
  ];
  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = false;
    # enable Alt+SysRq commands
    "kernel.sysrq" = 1;
    # for funky network experiments
    #"net.ipv4.ip_forward" = 1;
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
      spec = "UUID=7d5c0dfc-4040-4576-8c1b-5d77520f223b";
      hashTableSizeMB = 8192;
      verbosity = "crit";
    };
  };
  systemd.services."beesd@root".wantedBy = lib.mkForce [ ];

  # disable CPU boost by default
  systemd.services.disableCPUBoost = {
    description = "Disable CPU Boost and configure fan";
    script = ''
      set +x
      echo 0 > /sys/devices/system/cpu/cpufreq/boost
      # auxiliary fan
      echo 1 > /sys/devices/platform/nct6775.2592/hwmon/hwmon*/pwm1_enable
      echo 115 > /sys/devices/platform/nct6775.2592/hwmon/hwmon*/pwm1
      # red, green LED
      chmod go+w /sys/devices/platform/nct6775.2592/hwmon/hwmon*/pwm{5,6}{,_enable}
      # power
      echo `date '+%s'`,0 >> /home/arne/src/power-monitor/data.csv
    '';
    path = with pkgs; [
      coreutils
    ];
    serviceConfig = {
      User = "root";
      Type = "oneshot";
    };
    wantedBy = [ "basic.target" ];
  };
  systemd.services.preSuspend = {
    description = "Pre-suspend actions";
    script = ''
      # power
      echo `date '+%s'`,0 >> /home/arne/src/power-monitor/data.csv
    '';
    path = with pkgs; [
      coreutils
    ];
    serviceConfig = {
      User = "root";
      Type = "oneshot";
    };
    wantedBy = [ "suspend.target" ];
    after = [ "suspend.target" ];
  };
  systemd.services.configureAuxFan = {
    description = "Configure fan";
    script = ''
      # auxiliary fan
      echo 1 > /sys/devices/platform/nct6775.2592/hwmon/hwmon*/pwm1_enable
      echo 115 > /sys/devices/platform/nct6775.2592/hwmon/hwmon*/pwm1
      # power
      echo `date '+%s'`,0 >> /home/arne/src/power-monitor/data.csv
    '';
    path = with pkgs; [
      coreutils
    ];
    serviceConfig = {
      User = "root";
      Type = "oneshot";
    };
    wantedBy = [ "suspend.target" ];
    after = [ "suspend.target" ];
  };
  systemd.services.niceNixBuilds = {
    description = "Renice Nix builds";
    script = ''
      set +e
      nd=$(pgrep nix-daemon | head -n1)
      all=$(seq 1 64 | sed -s 's/^/nixbld/g' | tr '\n' ',' | head -c-1)
      while true; do
        sleep 5
        running=$(cat /proc/$nd/task/$nd/children)
        [[ -z "$running" ]] && continue
        renice 20 --pid `ps --no-heading -o tid --user $all` >/dev/null 2>/dev/null
      done
    '';
    serviceConfig = {
      User = "root";
      Type = "simple";
    };
    path = with pkgs; [
      procps
      utillinux
    ];
    wants = [ "nix-daemon.service" ];
    wantedBy = [ "multi-user.target" ];
  };
  systemd.services.prBuildBot = {
    description = "nixpkgs PR build bot";
    script = ''
      export PATH="$PATH:/run/wrappers/bin"
      jj --version
      git --version
      nix-shell --version
      sudo --version
      source ~/src/nixpkgs-pr-build-bot/.env
      exec ${lib.getExe nixpkgs-pr-build-bot.packages.x86_64-linux.nixpkgs-pr-build-bot}
    '';
    serviceConfig = {
      User = "arne";
      Type = "simple";
      OOMPolicy = "continue";
    };
    path = with pkgs; [
      nixpkgs'.pkgs.jujutsu
      git
      pkgs.nix
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "network-online.target" ];
    after = [ "network-online.target" ];
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
  networking.hostName = "nixOS";
  networking.firewall.logRefusedConnections = false;
  networking.firewall.rejectPackets = true;
  networking.firewall.allowedTCPPorts = [
    12783
    12975
    25565
  ];
  networking.firewall.allowedTCPPortRanges = [
    # KDE Connect
    {
      from = 1714;
      to = 1764;
    }
  ];
  networking.firewall.allowedUDPPorts = [ 12975 ];
  networking.firewall.allowedUDPPortRanges = [
    # KDE Connect
    {
      from = 1714;
      to = 1764;
    }
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
    "sysconfig/lm_sensors".text = ''
      HWMON_MODULES="nct6775"
    '';
  };

  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;
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
  services.displayManager.sddm.theme = "${pkgs.nur.repos.fliegendewurst.sddm-theme-utah}/share/sddm/themes/sddm-theme-custom";
  services.displayManager.logToJournal = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";
  services.displayManager.sddm.wayland.enable = true;
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

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = false;
  virtualisation.docker.logDriver = "journald";

  # services.printing.enable = true;
  services.trilium-server.enable = true;
  services.trilium-server.package = nixpkgs'.pkgs.trilium-next-server;
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

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    amdvlk
    vaapiVdpau
    libvdpau-va-gl
  ];
  hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];

  hardware.sane.enable = true;

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
      "electron-31.7.7"
    ];
  };
  programs.steam.enable = gaming;
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
  programs.adb.enable = true;
  programs.firefox.enable = true;
  programs.firefox.wrapperConfig.speechSynthesisSupport = false;
  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark;
  programs.ssh.startAgent = true;
  # use the neat X11 password entry dialog (only need to enter 'yes')
  programs.ssh.enableAskPassword = true;
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

  systemd.services.defragStuff = {
    script = ''
      set +x
      shopt -s nullglob
      for f in /home/*/.mozilla/firefox/*.default/{favicons,places}.sqlite /home/*/.local/share/trilium-data/document.db /var/log/journal/*/*; do
        ${lib.getExe' pkgs.btrfs-progs "btrfs"} fi defrag -czstd $f
      done
      rm /home/*/.cache/gradle/daemon/*/daemon-*.out.log || true
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    startAt = "*-*-* 16:10:00";
  };
  systemd.services.powerMeasure = {
    script = ''
      ~/.cache/cargo/target/release/power-monitor
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "arne";
    };
    startAt = "*:0/5";
  };

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "arne";
    overrideFolders = false;
    overrideDevices = false;
    settings.gui = {
      user = "arne";
      password = "syncthing";
    };
  };
  services.syncthing = {
    key = "/etc/nixos/syncthing/key.pem";
    cert = "/etc/nixos/syncthing/cert.pem";
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
    git-branchless
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
    pandoc
    poppler_utils
    libnotify
    ddrescue
    nvme-cli
    zola
    colorized-logs
    nix-index
    # TODO(25.05): use regular version
    nixpkgs'.pkgs.jujutsu
    bees
    schedtool
    compsize
    # TODO(25.05): use regular version
    nixpkgs'.pkgs.hydra-check
    e2fsprogs # filefrag
    moreutils # parallel
    evtest
    xdotool

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
    cargo-outdated
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
    josm
    #anki
    #tor-browser-bundle-bin
    #mathematica
    gparted
    nixpkgs'.pkgs.trilium-next-desktop
    qdirstat
    filelight
    #libreoffice-fresh
    qbittorrent
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
    skrooge
    mpvPlus
    inkscape
    element-desktop
    nixpkgs'.pkgs.cura-appimage

    #xorg.xkbcomp
    xorg.xrandr
    #evtest
    lm_sensors

    xclip
    ntfs3g
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

    # Games
    (prismlauncher.override {
      jdks = [
        jdk8
        jdk21
      ];
    })
    #minecraft
    #logmein-hamachi

    update-resolv-conf # for OpenVPN configs

    # List of packages to get on demand
    #wineWowPackages.full
    #winetricks
    #texlive.combined.scheme-full

    nixpkgs'.pkgs.prusa-slicer
    #blender
  ];
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
