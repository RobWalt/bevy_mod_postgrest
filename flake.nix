{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nci = {
      url = "github:yusdacra/nix-cargo-integration";
    };
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake
      {
        inherit inputs;
      }
      {
        systems = inputs.flake-utils.lib.defaultSystems;
        imports = [
          inputs.nci.flakeModule
          ./nix/crate.nix
          ./nix/test
        ];
        perSystem = { self', pkgs, ... }: {
          formatter = pkgs.nixpkgs-fmt;
          packages = rec {
            default = build-and-test;
            # compiles the example crate, sets up a temporary db with mock data and runs examples as tests
            run-examples = self'.packages.examples-runner-definition;
            # compiles and tests the lib and examples
            build-and-test = self'.packages.build-and-test-definition;
          };
          devShells.default = self'.devShells.default-definition;
          # checks via nci generated flake checks, not recommended for CI since it takes a long time and a lot of space in the gh actions cache
          checks.default = self'.checks.default-definition;
        };
      };
}
