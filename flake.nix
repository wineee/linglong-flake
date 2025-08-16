{
  description = "Deploy Linglong anywhere";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        linyaps-box = pkgs.callPackage (self.outPath + "/pkgs/linyaps-box.nix") { };

        linyaps = pkgs.callPackage (self.outPath + "/pkgs") {
          inherit linyaps-box;
        };
      in
      {
        packages = {
          inherit linyaps-box linyaps;
        };
      }
    )
    // {
      nixosModules = {
        linyaps =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          with lib;
          let
            cfg = config.services.linyaps;
            linyaps-box = self.packages.${pkgs.system}.linyaps-box;
            linyaps = self.packages.${pkgs.system}.linyaps;
          in
          {
            options = {
              services.linyaps = {
                enable = mkEnableOption "linyaps" // {
                  default = true;
                };
              };
            };

            config = mkIf cfg.enable {
              environment = {
                profiles = [ "/var/lib/linglong/entries" ];
                systemPackages = [
                  linyaps
                  linyaps-box
                ];
              };

              security.polkit.enable = true;

              fonts.fontDir.enable = true;

              services.dbus.packages = [ linyaps ];

              systemd = {
                packages = [ linyaps ];
                tmpfiles.packages = [ linyaps ];
              };

              users = {
                groups.deepin-linglong = { };
                users.deepin-linglong = {
                  group = "deepin-linglong";
                  isSystemUser = true;
                };
              };

              # 添加polkit规则
              security.polkit.extraConfig = ''
                polkit.addRule(function(action, subject) {
                  if (action.id == "org.deepin.linglong.PackageManager1.install" &&
                      subject.local && subject.active && subject.isInGroup("deepin-linglong")) {
                    return polkit.Result.YES;
                  }
                });
              '';
            };
          };
      };
    };
}
