{
  config,
  lib,
  pkgs,
  ...
}:

# https://nix-community.github.io/home-manager/options.xhtml

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  home.username = "arne";
  home.homeDirectory = "/home/arne";

  home.stateVersion = "24.11";

  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  home.file = {
    # Disable Baloo.
    ".config/systemd/user/plasma-baloorunner.service".source = mkOutOfStoreSymlink "/dev/null";
    ".config/baloofilerc".text = ''
      [Basic Settings]
      Indexing-Enabled=false

      [General]
      dbVersion=2
      exclude filters=*~,*.part,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.ninja_deps,.ninja_log,build.ninja,*.csproj,*.m4,*.rej,*.gmo,*.pc,*.omf,*.aux,*.tmp,*.po,*.vm*,*.nvram,*.rcore,*.swp,*.swap,lzo,litmain.sh,*.orig,.histfile.*,.xsession-errors*,*.map,*.so,*.a,*.db,*.qrc,*.ini,*.init,*.img,*.vdi,*.vbox*,vbox.log,*.qcow2,*.vmdk,*.vhd,*.vhdx,*.sql,*.sql.gz,*.ytdl,*.tfstate*,*.class,*.pyc,*.pyo,*.elc,*.qmlc,*.jsc,*.fastq,*.fq,*.gb,*.fasta,*.fna,*.gbff,*.faa,po,CVS,.svn,.git,_darcs,.bzr,.hg,CMakeFiles,CMakeTmp,CMakeTmpQmake,.moc,.obj,.pch,.uic,.npm,.yarn,.yarn-cache,__pycache__,node_modules,node_packages,nbproject,.terraform,.venv,venv,core-dumps,lost+found
      exclude filters version=9
    '';
    ".config/htop/htoprc".source = dotfiles/htoprc;
    # Replaces services.xserver.autoRepeatInterval and autoRepeatDelay.
    ".config/kcminputrc".text = ''
      [Keyboard]
      RepeatDelay=183
      RepeatRate=30
    '';
    ".cache/CACHEDIR.TAG".text = "Signature: 8a477f597d28d172789f06886806bc55";
    # Disables useless DrKonqi processor.
    ".config/systemd/user/drkonqi-coredump-pickup.service".source = mkOutOfStoreSymlink "/dev/null";
    # Disable useless Klipper clipboard manager.
    ".config/klipperrc".text = ''
      [General]
      KeepClipboardContents=false
      MaxClipItems=1
      SelectionTextOnly=false
      Version=6.2.5
    '';
    # Manage home-manager in my repo.
    ".config/home-manager".source =
      mkOutOfStoreSymlink "/home/arne/src/nixos-configuration/home-manager";
    # KWin window rules, to fix positioning and other stuff.
    ".config/kwinrulesrc".source = dotfiles/kwinrulesrc;
    # KWin configuration: number of desktops, scale factor, etc.
    ".config/kwinrc".source = dotfiles/kwinrc;
    # Move Firefox cache to /tmp.
    ".cache/mozilla/firefox/s0kjua7b.default/cache2".source = mkOutOfStoreSymlink "/tmp/firefox-cache";
    # Move KDE thumbnails to /tmp.
    ".cache/thumbnails".source = mkOutOfStoreSymlink "/tmp/thumbnail-cache";
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/arne/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  systemd.user.tmpfiles.rules = [
    "d /tmp/firefox-cache 600 arne users 0 -"
    "d /tmp/thumbnail-cache 600 arne users 0 -"
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.ssh = {
    enable = true;
    compression = true;
    matchBlocks = {
      "github.com" = {
        identityFile = "~/.ssh/github_laptop";
      };
      "git.fliegendewurst.eu" = {
        identityFile = "~/.ssh/gitea_laptop";
      };
    };
  };

  programs.git = {
    enable = true;
    aliases = {
      "log-branches" = "log --all --graph --decorate --oneline --simplify-by-decoration";
      "pfusch" = "push --force";
    };
    delta = {
      enable = true;
      options = {
        decorations = {
          commit-decoration-style = "bold yellow box";
          file-style = "bold yellow ul";
          file-decoration-style = "none";
        };
        features = "line-numbers decorations";
        whitespace-error-style = "22 reverse";
      };
    };
    userEmail = "arne.keller@posteo.de";
    userName = "Arne Keller";
    extraConfig = {
      core = {
        askpass = "/run/current-system/sw/bin/ksshaskpass";
        quotepath = "off";
      };
      pull.ff = "only";
      rerere.enabled = "1";
      user.useConfigOnly = true;
    };
  };

  programs.jujutsu = {
    enable = true;
    package = pkgs.emptyDirectory;
    settings = {
      user = {
        email = "arne.keller@posteo.de";
        name = "FliegendeWurst";
      };
    };
  };

  programs.mpv = {
    enable = true;
    package = pkgs.mpv.override {
      scripts = with pkgs.mpvScripts; [ mpris ];
    };
    bindings = {
      "<" = "playlist_next";
      ">" = "playlist_prev";
    };
    config = {
      "profile" = "gpu-hq";
      "hwdec" = "auto-safe";
      "image-display-duration" = "2";
      "no-audio-display" = "";
    };
  };

  programs.alacritty = {
    enable = true;
    settings = {
      colors = {
        bright = {
          black = "#7f8c8d";
          blue = "#3daee9";
          cyan = "#16a085";
          green = "#1cdc9a";
          magenta = "#8e44ad";
          red = "#c0392b";
          white = "#fcfcfc";
          yellow = "#c8c81b";
        };
        dim = {
          black = "#31363b";
          blue = "#1b668f";
          cyan = "#186c60";
          green = "#17a262";
          magenta = "#614a73";
          red = "#783228";
          white = "#63686d";
          yellow = "#c8c842";
        };
        normal = {
          black = "#31363b";
          blue = "#1d99f3";
          cyan = "#1abc9c";
          green = "#11d116";
          magenta = "#9b59b6";
          red = "#ed1515";
          white = "#eff0f1";
          yellow = "#c8c800";
        };
        primary = {
          background = "#260b0b";
          bright_foreground = "#fcfcfc";
          dim_foreground = "#dce6e7";
          foreground = "#eff0f1";
        };
      };
      font = {
        size = 13;
        bold = {
          family = "CozetteVector";
          style = "Regular";
        };
        normal.family = "CozetteVector";
      };
      scrolling.history = 0;

      window = {
        decorations = "none";
        dimensions = {
          columns = 180;
          lines = 40;
        };
        padding = {
          x = 6;
          y = 4;
        };
      };
    };
  };

  programs.tmux = {
    enable = true;
    sensibleOnTop = false;
    terminal = "tmux-256color";
    baseIndex = 1;
    mouse = true;
    keyMode = "vi";
    clock24 = true;
    escapeTime = 0;
    historyLimit = 20000;
    extraConfig = builtins.readFile ./dotfiles/tmux.conf;
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
