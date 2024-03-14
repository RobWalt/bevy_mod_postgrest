{ inputs, system }:
let
  fnx = inputs.fenix.packages.${system};
  mkRustDeriv = fnx-version: extra-components:
    let
      std-components = [
        fnx-version.cargo
        fnx-version.clippy
        fnx-version.rust-src
        fnx-version.rustc
        fnx-version.rust-analyzer

        # it's generally recommended to use nightly rustfmt
        fnx.complete.rustfmt
      ];
      all-components = std-components ++ extra-components;
    in
    fnx.combine all-components;
in
{
  stable = mkRustDeriv fnx.stable [ fnx.targets.wasm32-unknown-unknown.stable.rust-std ];
  nightly = mkRustDeriv fnx.complete [ fnx.targets.wasm32-unknown-unknown.latest.rust-std ];
}
