{
  config,
  lib,
  pkgs,
  pr-dashboard,
  reddit-image-grid,
  wastebin,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    (builtins.fetchTarball {
      # Pick a release version you are interested in and set its hash, e.g.
      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/master/nixos-mailserver-nixos-master.tar.gz";
      # To get the sha256 of the nixos-mailserver tarball, we can use the nix-prefetch-url command:
      # release="nixos-23.05"; nix-prefetch-url "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/${release}/nixos-mailserver-${release}.tar.gz" --unpack
      # commit ?
      sha256 = "0hs42w1x7286wkxm4myq470z172iwpx6kajsfjhjmwv3ni4g81kz";
    })
  ];

  nixpkgs.overlays = [
    (final: prev: {
      forgejo-lts = prev.forgejo-lts.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace 'cmd/serv.go' \
            --replace-fail 'alphaDashDotPattern = regexp.MustCompile(`[^\w-\.]`)' \
            'alphaDashDotPattern = regexp.MustCompile(`[^\w-\.äöüÄÖÜ]`)'
        '';
        doCheck = false;
      });
    })
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "net.ifnames=0" ];

  zramSwap.enable = true;
  zramSwap.memoryPercent = 30;
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };

  # TODO: do this flake-based?
  # system.autoUpgrade.enable = true;
  # system.autoUpgrade.allowReboot = true;

  boot.loader.systemd-boot.configurationLimit = 5;
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 14d";
  nix.gc.dates = "monthly";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "home-pc:07v0PAF8ZWtVjxkl+RehTLUWvhYHod7c+fcru1sTQxg="
  ];
  nix.extraOptions = ''
    min-free = ${toString (10 * 1024 * 1024 * 1024)}
    max-free = ${toString (20 * 1024 * 1024 * 1024)}
  '';
  documentation.nixos.enable = false;

  virtualisation.docker.enable = true;

  networking = {
    hostName = "verschnuufeckli";
    defaultGateway = "10.0.0.1";
    # Use Quad9's DNS
    nameservers = [
      "9.9.9.9"
      "149.112.112.112"
      "2620:fe::fe"
      "2620:fe::9"
    ];
    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "10.0.0.90";
          prefixLength = 24;
        }
      ];
      useDHCP = true;
    };
    firewall = {
      allowedTCPPorts = [
        # SSH
        22
        # HTTP(S)
        80
        443
        # mail-related
        25
        993
        587
        465
        # Boludo
        20122
      ];
      logRefusedConnections = false;
      rejectPackets = true;
    };
  };

  services.journald.extraConfig = "SystemMaxUse=1G";

  services.logrotate.enable = true;
  services.logrotate.settings = {
    "/var/log/nginx/access*.log*" = {
      frequency = "weekly";
      rotate = "3";
    };
  };
  services.logrotate.settings.nginx = lib.mkForce { };

  services.cron.enable = true;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBt5gU0SiJtTYhAqziUi4VIc1xmvQI2vJUKqF50JkO4l arne@nixOS"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDFBEiIr2SjYgQsebxjbym1JxgmYEaQmwFXHrIq+swkE pi@himbeere-null"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBuF+rXgZvU5PsP1c7r5AG7kkHzKcZvFW8N1ILNS/L4X arne@framework"
  ];

  users.users.typicalc = {
    isSystemUser = true;
    group = "typicalc";
  };
  users.groups.typicalc = { };
  systemd.services.typicalc = {
    description = "Typicalc";
    serviceConfig = {
      ExecStart = "${pkgs.jre}/lib/openjdk/bin/java -Dserver.port=7729 -jar /opt/typicalc-1.0-SNAPSHOT.jar";
      User = "typicalc";
      # hardening
      CapabilityBoundingSet = "";
      LockPersonality = true;
      NoNewPrivileges = true;
      # MemoryDenyWriteExecute = true;
      RemoveIPC = true;
      RestrictAddressFamilies = [ "AF_INET" ]; # "AF_INET6"
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      PrivateDevices = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelTunables = true;
      PrivateMounts = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectKernelModules = true;
      ProtectProc = "noaccess";
      ProtectSystem = "strict";
      PrivateUsers = true;
      SystemCallArchitectures = "native";
      UMask = "0077";
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
  };

  services.hedgedoc.enable = true;
  services.hedgedoc.settings.domain = "hedgedoc.fliegendewurst.eu";
  services.hedgedoc.settings.host = "127.0.0.1";
  services.hedgedoc.settings.protocolUseSSL = true;

  services.wastebin = {
    enable = true;
    package = wastebin.packages.x86_64-linux-cross-aarch64-linux.wastebin;
    settings = {
      WASTEBIN_BASE_URL = "https://paste.fliegendewurst.eu";
      WASTEBIN_ADDRESS_PORT = "127.0.0.1:26247";
      WASTEBIN_MAX_BODY_SIZE = 5 * 1000 * 1000;
      WASTEBIN_MAX_PASTE_EXPIRATION = 14 * 24 * 60 * 60;
      WASTEBIN_HTTP_TIMEOUT = 30;
      WASTEBIN_TITLE = "pastebin of eternal failure";
    };
  };

  users.users.pr-dashboard = {
    home = "/home/pr-dashboard";
    isSystemUser = true;
    group = "pr-dashboard";
  };
  users.groups.pr-dashboard = { };
  systemd.services.pr-dashboard = {
    description = "PR dashboard";
    environment = {
      "GITHUB_PAT_FILE" = "/home/pr-dashboard/github-pat";
      "PR_DASHBOARD_DATABASE" = "/home/pr-dashboard/pr-dashboard.db";
      "PORT" = "18120";
    };
    serviceConfig = {
      ExecStart = lib.getExe pr-dashboard.packages.x86_64-linux-cross-aarch64-linux.pr-dashboard;
      User = "pr-dashboard";
      # hardening
      CapabilityBoundingSet = "";
      LockPersonality = true;
      NoNewPrivileges = true;
      MemoryDenyWriteExecute = true;
      RemoveIPC = true;
      RestrictAddressFamilies = [ "AF_INET" ]; # "AF_INET6"
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      PrivateDevices = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelTunables = true;
      PrivateMounts = true;
      PrivateTmp = true;
      # ProtectHome = true;
      ProtectKernelModules = true;
      ProtectProc = "noaccess";
      ProtectSystem = "strict";
      PrivateUsers = true;
      SystemCallArchitectures = "native";
      UMask = "0077";
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
  };

  users.users.reddit-image-grid = {
    home = "/home/reddit-image-grid";
    isSystemUser = true;
    group = "reddit-image-grid";
  };
  users.groups.reddit-image-grid = { };
  systemd.services.reddit-image-grid = {
    description = "Reddit Image Grid";
    environment = {
      "REDDIT_IMAGE_GRID_BASE_URL" = "https://fliegendewurst.eu/rig";
      "REDDIT_IMAGE_GRID_PORT" = "23377";
      "REDDIT_IMAGE_GRID_DATABASE" = "/home/reddit-image-grid/stars.db";
    };
    serviceConfig = {
      ExecStart = lib.getExe' reddit-image-grid.packages.x86_64-linux-cross-aarch64-linux.reddit-image-grid "server";
      User = "reddit-image-grid";
      Group= "reddit-image-grid";
      # hardening
      CapabilityBoundingSet = "";
      LockPersonality = true;
      NoNewPrivileges = true;
      MemoryDenyWriteExecute = true;
      RemoveIPC = true;
      RestrictAddressFamilies = [ "AF_INET" ]; # "AF_INET6"
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      PrivateDevices = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelTunables = true;
      PrivateMounts = true;
      PrivateTmp = true;
      # ProtectHome = true;
      ProtectKernelModules = true;
      ProtectProc = "noaccess";
      ProtectSystem = "strict";
      PrivateUsers = true;
      SystemCallArchitectures = "native";
      UMask = "0077";
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
  };

  services.tt-rss = {
    enable = true;
    selfUrlPath = "https://tt-rss.fliegendewurst.eu/";
    sessionCookieLifetime = 365 * 24 * 60 * 60;
    singleUserMode = true;
    virtualHost = "tt-rss.fliegendewurst.eu";
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    clientMaxBodySize = "10000m";

    virtualHosts = {
      "trilium-notes.eu" = {
        enableSSL = false;
        globalRedirect = "github.com/TriliumNext/Notes";
        redirectCode = 302;
      };

      "fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          root = "/var/www";
        };
        locations."/rig" = {
          extraConfig = ''
            rewrite ^/rig$ / break;
            rewrite ^/rig(.+)$ $1 break;
          '';
          proxyPass = "http://127.0.0.1:23377";
        };
      };
      "git.fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:26599";
        };
      };
      "hedgedoc.fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
        };
      };
      "nixpkgs-prs.fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:18120";
        };
      };
      "paste.fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:26247";
        };
      };
      "rsshub.fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:26944";
        };
      };
      "mail.fliegendewurst.eu" = {
        enableACME = true;
      };
      "tt-rss.fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          basicAuthFile = "/var/nginx/tt-rss-auth";
        };
      };
      "typicalc.fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:7729";
        };
      };
    };
  };

  services.forgejo = {
    enable = true;
    settings = {
      DEFAULT.APP_NAME = "Forgejo: FliegendeWurst's instance";
      service.DISABLE_REGISTRATION = true;

      server.HTTP_PORT = 26599;
      server.HTTP_ADDR = "127.0.0.1";
      server.ROOT_URL = "https://git.fliegendewurst.eu/";
      # server.DISABLE_SSH = true;
      server.OFFLINE_MODE = true;
    };
  };

  mailserver = {
    enable = true;
    fqdn = "mail.fliegendewurst.eu";
    domains = [ "fliegendewurst.eu" ];

    stateVersion = 1;

    # A list of all login accounts. To create the password hashes, use
    # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
    loginAccounts = {
      "info@fliegendewurst.eu" = {
        hashedPasswordFile = "/var/dovecot2/info_at_fliegendewurst_eu";
        aliases = [ "@fliegendewurst.eu" ];
        catchAll = [ "fliegendewurst.eu" ];
      };
    };

    certificateScheme = "acme";
  };
  services.dovecot2.sieve.extensions = [ "fileinto" ];

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "2012gdwu@posteo.de";

  programs.vim.enable = true;
  programs.vim.defaultEditor = true;
  environment.systemPackages = with pkgs; [
    vim
    htop
    docker-compose
    ripgrep
    borgbackup
    jre
    killall
    cargo
    sqlite-interactive
    git
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

}
