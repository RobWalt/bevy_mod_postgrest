{ inputs, ... }: {
  perSystem = { pkgs, system, ... }:
    let
      rust = import ./rust.nix { inherit inputs system; };

      generalPkgs = [
        pkgs.pkg-config
        pkgs.udev
        pkgs.alsaLib
        pkgs.vulkan-loader
        pkgs.wayland
        pkgs.libxkbcommon
        pkgs.openssl
      ];
      nightlyPkgs = [ ];

      mkName = name: "Bevy (" + name + ") dev shell";
      mkBevyShell = { name, packages }: pkgs.mkShell {
        name = mkName name;
        inherit packages;
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath generalPkgs;
      };
    in
    {
      devShells = rec {
        default = stable;

        stable = mkBevyShell {
          name = "stable";
          packages = generalPkgs ++ [ rust.stable ];
        };

        nightly = mkBevyShell {
          name = "nightly";
          packages = generalPkgs ++ nightlyPkgs ++ [ rust.nightly ];
        };
      };
    };
}
