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
    strictDepsByDefault = config.system.nixos.release == "25.11";
    permittedInsecurePackages = [
    ];
  };
  nixpkgs.overlays = [
    (final: prev: {
      openscad-unstable = prev.openscad-unstable.overrideAttrs (old: {
        version = "2025-05-15";
        src = final.fetchFromGitHub {
          owner = "openscad";
          repo = "openscad";
          rev = "168b3ec9905cb541a80099ef2848d3bdfe280ac8";
          hash = "sha256-nv0V2tp1itkfqyUXGkrGtP1Hu+onZdYzmGNCilbQWHo=";
          fetchSubmodules = true;
        };
        doCheck = false;
      });
      libbgcode = prev.libbgcode.overrideAttrs (old: {
        version = "2025-02-19";
        src = final.fetchFromGitHub {
          owner = "prusa3d";
          repo = "libbgcode";
          rev = "5041c093b33e2748e76d6b326f2251310823f3df";
          hash = "sha256-EaxVZerH2v8b1Yqk+RW/r3BvnJvrAelkKf8Bd+EHbEc=";
        };

        buildInputs = [
          final.heatshrink
          final.zlib
          final.boost
          final.catch2_3
        ];
      });
      prusa-slicer = prev.prusa-slicer.overrideAttrs (old: {
        version = "2.9.2";

        src = final.fetchFromGitHub {
          owner = "prusa3d";
          repo = "PrusaSlicer";
          hash = "sha256-j/fdEgcFq0nWBLpyapwZIbBIXCnqEWV6Tk+6sTHk/Bc=";
          tag = "version_2.9.2";
        };

        patches = [
          (final.fetchpatch {
            name = "build-with-boost-187";
            url = "https://946495.bugs.gentoo.org/attachment.cgi?id=914594";
            hash = "sha256-FVCpfkOe8a7zRG7QXoBu6i8I4sFu2i/j+E9uKPGmcec=";
          })
        ];

        postPatch = null;

        buildInputs =
          let
            wxGTK-prusa = final.wxGTK32.overrideAttrs (old: {
              pname = "wxwidgets-prusa3d-patched";
              version = "3.2.0";
              configureFlags = old.configureFlags ++ [ "--disable-glcanvasegl" ];
              patches = [
                ./wxWidgets-Makefile.in-fix.patch
                (final.fetchpatch {
                  url = "https://github.com/FliegendeWurst/wxWidgets/commit/50f7d5db40be3f3b5791f12d5cf09f320d8a8641.patch";
                  hash = "sha256-i/nBf2gKvbqYJbLUVGa2zAt8lY8Ot8EuyuNilpybQtU=";
                })
              ];
              src = final.fetchFromGitHub {
                owner = "prusa3d";
                repo = "wxWidgets";
                rev = "78aa2dc0ea7ce99dc19adc1140f74c3e2e3f3a26";
                hash = "sha256-rYvmNmvv48JSKVT4ph9AS+JdstnLSRmcpWz1IdgBzQo=";
                fetchSubmodules = true;
              };
            });
            nanosvg-fltk = final.nanosvg.overrideAttrs (old: rec {
              pname = "nanosvg-fltk";
              version = "unstable-2022-12-22";

              src = final.fetchFromGitHub {
                owner = "fltk";
                repo = "nanosvg";
                rev = "abcd277ea45e9098bed752cf9c6875b533c0892f";
                hash = "sha256-WNdAYu66ggpSYJ8Kt57yEA4mSTv+Rvzj9Rm1q765HpY=";
              };
            });
            openvdb_tbb_2021_8 = final.openvdb.override { tbb = final.tbb_2021_11; };
            wxGTK-override' = wxGTK-prusa;
            opencascade-override' = final.opencascade-occt_7_6_1;
          in
          [
            final.binutils
            final.boost
            final.cereal
            final.cgal
            final.curl
            final.dbus
            final.eigen
            final.expat
            final.glew
            final.glib
            final.glib-networking
            final.gmp
            final.gtk3
            final.hicolor-icon-theme
            final.ilmbase
            final.libpng
            final.mpfr
            nanosvg-fltk
            final.nlopt
            opencascade-override'
            openvdb_tbb_2021_8
            final.qhull
            final.tbb_2021_11
            wxGTK-override'
            final.xorg.libX11
            final.libbgcode
            final.heatshrink
            final.catch2_3
            final.webkitgtk_4_1
            final.z3-cmake
            final.systemd
          ];
      });
      z3-cmake = (
        final.stdenv.mkDerivation {
          inherit (final.z3) pname version src;

          patches = [
            ./0001-fix-pkgconfig-prefixes.patch
          ];

          cmakeFlags = [
            "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
          ];

          nativeBuildInputs = [
            final.cmake
            final.python3
          ];
        }
      );
    })
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
  i18n.extraLocaleSettings = {
    LC_MESSAGES = "en_US.UTF-8";
    LC_CTYPE = "C.UTF-8";
  };
  console = {
    keyMap = "dvorak";
  };

  environment.sessionVariables = rec {
    TIME_STYLE = "long-iso";

    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_DATA_HOME = "$HOME/.local/share";

    CARGO_HOME = "${XDG_CACHE_HOME}/cargo";
    CARGO_TARGET_DIR = "${CARGO_HOME}/target";
    RUSTUP_HOME = "$HOME/.local/rustup";
    NPM_PACKAGES = "$HOME/.local/share/npm";
    NPM_CONFIG_USERCONFIG = "$HOME/.config/npmrc";
    KDEHOME = "$HOME/.config/kde";
    KDE_UTF8_FILENAMES = "1";
    ANDROID_SDK_HOME = "${XDG_CACHE_HOME}";
    GRADLE_USER_HOME = "${XDG_CACHE_HOME}/gradle";
    XCOMPOSECACHE = "${XDG_CACHE_HOME}/X11/xcompose";
    _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=$HOME/.config/java";

    # enable Wayland for Chromium/Electron
    NIXOS_OZONE_WL = "1";

    # illegal trick to make GTK applications use the KDE file picker
    GTK_USE_PORTAL = "1";

    # development libraries for Rust
    LIBCLANG_PATH = "${lib.getLib pkgs.llvmPackages.libclang}/lib";
    LIBSQLITE3_SYS_USE_PKG_CONFIG = "1";
    ZSTD_SYS_USE_PKG_CONFIG = "1";
    # disable stupid auto-downloader for dev tools
    COREPACK_ENABLE_AUTO_PIN = "0";
    RUSTUP_AUTO_INSTALL = "0";
  };
  environment.variables = {
    EDITOR = "vim";
  };

  environment.etc = {
    "zshenv.local" = {
      text = ''
        ZDOTDIR=$HOME/.config/zsh
      '';
      mode = "0444";
    };
    "zshrc.local".text = builtins.readFile ./sysroot/etc/zshrc.local;
    "zsh-aliases.zsh".text =
      builtins.readFile ./sysroot/etc/zsh-aliases.zsh
      + ''
        source "${nixpkgs'.pkgs.zsh-histdb}/share/zsh-histdb/sqlite-history.zsh"
      '';
  };

  programs.bash.interactiveShellInit = ''
    HISTCONTROL=ignoreboth:erasedups
    HISTFILE=$HOME/.local/share/bash_history
  '';

  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
  };

  programs.less = {
    enable = true;
    lessopen = null;
  };

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
        url = "https://gist.github.com/FliegendeWurst/856bd34536028b5579bdb102f324325a/raw/24f8ac70b920708e8b94a1e457d6b2a4524c6afe/dvorak-custom";
        hash = "sha256-VhYbDkVYtnrUSjz2c1+luMABbjTxWUDMXdUQ9p2hA24=";
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
  # TODO: still doesn't work
  programs.ssh.enableAskPassword = true;
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
    overrideFolders = false;
    overrideDevices = false;
    settings.gui = {
      user = "arne";
      password = "syncthing";
    };
  };

  services.udisks2.settings."mount_options.conf" = {
    defaults = {
      defaults = "noatime";
      ext4_defaults = "noatime,errors=remount-ro";
      exfat_defaults = "noatime,uid=$UID,gid=$GID,iocharset=utf8,errors=remount-ro";
      vfat_defaults = "noatime,uid=$UID,gid=$GID,shortname=mixed,utf8=1,showexec,flush";
    };
  };

  environment.systemPackages = with pkgs; [
    sqlite-interactive
    nix-tree
    duf
    ripgrep
    sysstat
    _7zz
  ];
}
