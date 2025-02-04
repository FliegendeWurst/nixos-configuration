{
  config,
  lib,
  pkgs,
  nixpkgs',
  ...
}:

rec {
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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = false;

  documentation.nixos.enable = false;
  environment.etc.issue.source = "/dev/null";

  boot.initrd.systemd.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  # normal zram compression ratio: 5-6
  # use 150 / 5 = 30% of memory as compressed swap
  zramSwap.enable = true;
  zramSwap.memoryPercent = 150;
  boot.kernel.sysctl = {
    "vm.swappiness" = 150;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };

  hardware.cpu.amd.updateMicrocode = true;
  hardware.mcelog.enable = true;
  services.fstrim.enable = true;
  # the journal tends to fill up with junk
  services.journald.extraConfig = "SystemMaxUse=100M";

  networking.useDHCP = true;
  networking.dhcpcd.wait = "background";
  networking.firewall.logRefusedConnections = false;
  networking.firewall.rejectPackets = true;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";
  console = {
    keyMap = "dvorak";
  };

  environment.sessionVariables = rec {
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_DATA_HOME = "$HOME/.local/share";

    CARGO_HOME = "${XDG_CACHE_HOME}/cargo";
    CARGO_TARGET_DIR = "${CARGO_HOME}/target";
    RUSTUP_HOME = "$HOME/.local/rustup";
    KDEHOME = "$HOME/.config/kde";
    KDE_UTF8_FILENAMES = "1";
    ANDROID_SDK_HOME = "${XDG_CACHE_HOME}";
    GRADLE_USER_HOME = "${XDG_CACHE_HOME}/gradle";
    XCOMPOSECACHE = "${XDG_CACHE_HOME}/X11/xcompose";
    _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=$HOME/.config/java";
    GTK_USE_PORTAL = "1";

    LIBCLANG_PATH = "${lib.getLib pkgs.llvmPackages.libclang}/lib";
    LIBSQLITE3_SYS_USE_PKG_CONFIG = "1";
    ZSTD_SYS_USE_PKG_CONFIG = "1";
  };
  environment.variables = {
    EDITOR = "vim";
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

  programs.zsh.enable = true;
  programs.zsh.enableGlobalCompInit = false;
  programs.zsh.interactiveShellInit = ''
    source ${pkgs.nix-index}/etc/profile.d/command-not-found.sh
  '';

  programs.less.enable = true;
  programs.less.lessopen = null;

  security.sudo.package = pkgs.sudo.override {
    withInsults = true;
  };
  security.sudo.extraConfig = ''
    Defaults insults
    Defaults timestamp_timeout=-1
  '';

  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;
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

  xdg.portal.enable = true;
  xdg.portal.xdgOpenUsePortal = true;
  systemd.services."drkonqi-coredump-processor@".enable = false;
  services.displayManager.logToJournal = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.graphics.enable = true;

  hardware.sane.enable = true;

  programs.command-not-found.enable = false;
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

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "arne";
    settings.gui = {
      user = "arne";
      password = "syncthing";
    };
  };
}
