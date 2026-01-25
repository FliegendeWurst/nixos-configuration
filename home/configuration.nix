{
  config,
  lib,
  pkgs,
  nixpkgs',
  nixpkgs-pr-build-bot,
  sysinfo,
  ...
}:

let
  gaming = true;
  linuxPackages = pkgs.linuxPackages_6_12; # some LTS version
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
  utahBackground = pkgs.fetchurl {
    url = "https://fliegendewurst.eu/tmp/utah.png";
    hash = "sha256-eREFKG5Uj991UB6GppZEOgrao1WToq1OtA+rKB5szs8=";
  };
  git = pkgs.git.override {
    perlSupport = false;
    doInstallCheck = false;
  };
in
rec {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  nix.nrBuildUsers = 64;
  nix.package = pkgs.lixPackageSets.stable.lix;

  boot.loader.systemd-boot.memtest86.enable = true;
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
  boot.kernelParams = lib.mkForce [
    "mitigations=off"
    "amdgpu.noretry=0"
    # this system has 128GB of RAM, I'm not writing that to disk
    "nohibernate"
    # increase dmesg limit
    "log_buf_len=128M"
  ];
  boot.kernel.sysctl = {
    # for funky network experiments
    #"net.ipv4.ip_forward" = 1;
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };
  services.beesd.filesystems = {
    "-" = {
      spec = "UUID=7d5c0dfc-4040-4576-8c1b-5d77520f223b";
      hashTableSizeMB = 16384;
      verbosity = "crit";
    };
  };
  systemd.services."beesd@-".wantedBy = lib.mkForce [ ];

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
        running=$(cat /proc/$nd/task/*/children)
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
      util-linux
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
      jujutsu
      git
      pkgs.nix
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
  };

  #services.triggerhappy.enable = true;
  #services.triggerhappy.user = "root";
  #services.triggerhappy.bindings = [
  #  { keys = ["LEFTMETA" "RIGHTSHIFT" "F21"];  cmd = "${pkgs.bash}/bin/bash -c 'sync && sleep 1 && ${pkgs.systemd}/bin/systemctl suspend && ${pkgs.systemd}/bin/loginctl lock-session'"; }
  #];

  hardware.bluetooth.enable = false;

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
  networking.firewall.allowedTCPPorts = [
    12783
    12975
    25565
  ];
  networking.firewall.allowedUDPPorts = [ 12975 ];
  # Or disable the firewall altogether.
  #networking.firewall.enable = false;

  environment.etc = {
    "resolv.conf".text = ''
      domain fritz.box
      nameserver 192.168.178.1
      nameserver fd00::e228:6dff:fe3d:545a
      options edns0
    '';
    "sysconfig/lm_sensors".text = ''
      HWMON_MODULES="nct6775"
    '';
  };

  services.libinput.enable = true;
  #services.xserver.libinput.accelProfile = "flat";
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";
  services.displayManager.sddm.wayland.enable = true;

  fonts.enableDefaultPackages = true;
  fonts.packages = with pkgs; [
    noto-fonts-color-emoji
    liberation_ttf
    cozette
    font-awesome
  ];

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = false;
  virtualisation.docker.logDriver = "journald";

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

  services.pipewire = {
    alsa.support32Bit = true;
  };

  hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];

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

  programs.steam.enable = gaming;

  programs.zsh.interactiveShellInit = ''
    source ${pkgs.nix-index}/etc/profile.d/command-not-found.sh
  '';

  programs.tmux.enable = true;
  programs.tmux.baseIndex = 1;
  programs.tmux.clock24 = true;
  programs.tmux.escapeTime = 0;
  programs.tmux.historyLimit = 10000;
  programs.tmux.terminal = "tmux-256color";
  programs.tmux.plugins = with pkgs.tmuxPlugins; [ pkgs.nur.repos.fliegendewurst.tmux-thumbs ];

  programs.adb.enable = true;
  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark;
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

  programs.kdeconnect.enable = true;

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
    git-branchless
    tree
    killall
    # premium utilities
    delta
    jq
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
    poppler-utils
    libnotify
    ddrescue
    nvme-cli
    zola
    colorized-logs
    nix-index
    jujutsu
    bees
    schedtool
    compsize
    hydra-check
    e2fsprogs # filefrag
    moreutils # parallel
    evtest
    xdotool
    landrun

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
    jetbrains.idea
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
    borgbackup
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

    # SDDM theme
    (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
      [General]
      background=${utahBackground}
    '')

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
    qdirstat
    libreoffice-qt6-fresh
    qbittorrent
    telegram-desktop
    signal-desktop
    alacritty
    kdePackages.filelight
    #kdePackages.kwalletmanager
    kdePackages.okular
    #kdePackages.akregator
    kdePackages.gwenview
    kdePackages.ark
    kdePackages.kate
    kdePackages.kcalc
    kdePackages.kcolorchooser
    kdePackages.kompare
    kdePackages.kcharselect
    #kdePackages.kmag
    kdePackages.k3b
    kdePackages.kruler
    kdePackages.plasma-vault
    skrooge
    mpvPlus
    inkscape
    element-desktop
    cura-appimage
    prusa-slicer

    lm_sensors

    wl-clipboard
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
    ftb-app
    #minecraft
    #logmein-hamachi

    update-resolv-conf # for OpenVPN configs

    # List of packages to get on demand
    #wineWowPackages.full
    #winetricks
    #texlive.combined.scheme-full
  ];
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
