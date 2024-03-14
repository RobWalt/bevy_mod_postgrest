{ inputs, ... }: {
  perSystem = { config, pkgs, lib, system, ... }:
    let
      rust = import ./test/rust.nix { inherit inputs system; };
      buildInputs = [
        pkgs.pkg-config
        pkgs.udev
        pkgs.alsaLib
        pkgs.vulkan-loader
        pkgs.wayland
        pkgs.libxkbcommon
        pkgs.openssl
      ];
      drvCfg = {
        mkDerivation = { inherit buildInputs; };
        env.LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;
      };
      crateCfg = {
        depsDrvConfig = drvCfg;
        drvConfig = drvCfg;
      };
      crateName = "bevy_mod_postgrest";
      examplesCrateName = "examples-runner";
    in
    {
      nci = {
        projects.${crateName}.path = ../.;

        crates.${crateName} = crateCfg;
        crates.${examplesCrateName} = crateCfg;
      };

      packages = {
        "${crateName}" = config.nci.outputs.${crateName}.packages.release;
        "${examplesCrateName}" = config.nci.outputs.${examplesCrateName}.packages.release;
      };
      devShells.default-definition = pkgs.mkShell {
        packages = buildInputs ++ [ rust.stable ];
        LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;
      };
      checks.default-definition = config.nci.outputs.${crateName}.check;
    };
}
