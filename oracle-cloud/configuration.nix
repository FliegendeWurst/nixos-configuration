{ config, lib, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    (builtins.fetchTarball {
      # Pick a release version you are interested in and set its hash, e.g.
      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/nixos-23.11/nixos-mailserver-nixos-23.11.tar.gz";
      # To get the sha256 of the nixos-mailserver tarball, we can use the nix-prefetch-url command:
      # release="nixos-23.05"; nix-prefetch-url "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/${release}/nixos-mailserver-${release}.tar.gz" --unpack
      sha256 = "122vm4n3gkvlkqmlskiq749bhwfd0r71v6vcmg1bbyg4998brvx8";
    })
  ];

  nixpkgs.overlays = [ (final: prev:
    {
      gitea = prev.gitea.overrideAttrs (old: {
        patches = (old.patches or []) ++ [
          (prev.fetchpatch {
            url = "https://github.com/FliegendeWurst/gitea/commit/d78d2d098dc97b77b36ea795682086ff623b0106.patch";
            hash = "sha256-vTykqt/ZgFDjKBuF3uTSv58j2c8wlkFo13HCBaaTCzI=";
          })
        ];
        doCheck = false;
      });
    }
  ) ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "net.ifnames=0" ];

  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;

  boot.loader.systemd-boot.configurationLimit = 5;
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 14d";

  virtualisation.docker.enable = true;

  networking = {
    hostName = "verschnuufeckli";
    defaultGateway = "10.0.0.1";
    # Use google's public DNS server
    nameservers = [ "1.1.1.1" ];
    interfaces.eth0 = {
      ipv4.addresses = [ { address = "10.0.0.90"; prefixLength = 24; } ];
      useDHCP = false;
    };
    firewall = {
      allowedTCPPorts = [ 22 80 443 25 993 587 465 ];
      logRefusedConnections = false;
      rejectPackets = true;
    };
  };

  services.cron.enable = true;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBt5gU0SiJtTYhAqziUi4VIc1xmvQI2vJUKqF50JkO4l arne@nixOS"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDFBEiIr2SjYgQsebxjbym1JxgmYEaQmwFXHrIq+swkE pi@himbeere-null"
  ];

  users.users.typicalc = {
    isSystemUser = true;
    group = "typicalc";
  };
  users.groups.typicalc = {};
  systemd.services.typicalc = {
    description = "Typicalc";
    serviceConfig = {
      ExecStart = "${pkgs.jre}/lib/openjdk/bin/java -Dserver.port=7729 -jar /opt/typicalc-1.0-SNAPSHOT.jar";
      User = "typicalc";
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    clientMaxBodySize = "10000m";

    virtualHosts = {
      "fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          root = "/var/www";
        };
      };
      "git.fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:26599";
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
      "typicalc.fliegendewurst.eu" = {
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:7729";
        };
      };
    };
  };

  services.gitea = {
    enable = true;
    appName = "gitea - Arne Keller";
    settings = {
      service.DISABLE_REGISTRATION = true;

      server.HTTP_PORT = 26599;
      server.HTTP_ADDR = "127.0.0.1";
      server.ROOT_URL = "https://git.fliegendewurst.eu/";
      # server.DISABLE_SSH = true;
      server.OFFLINE_MODE = true;
    };
    repositoryRoot = "/var/lib/gitea/data/gitea-repositories";
  };

  mailserver = {
    enable = true;
    fqdn = "mail.fliegendewurst.eu";
    domains = [ "fliegendewurst.eu" ];

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

  environment.systemPackages = with pkgs; [
    vim
    htop
    docker-compose
    ripgrep
    borgbackup
    jre
    killall
    cargo
    sqlite
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
