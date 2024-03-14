{ inputs, ... }:
{
  perSystem = { pkgs, lib, system, ... }:
    let
      rust = import ./rust.nix { inherit inputs system; };
      # this is basically the postgrest tutorial setup and should suffice for testing purposes
      postgrest-db-setup = ''${builtins.replaceStrings ["$"] ["\\$"] (builtins.readFile ./init_db.sql)}'';
      runtimeInputs = [
        pkgs.pkg-config
        pkgs.udev
        pkgs.alsaLib
        pkgs.vulkan-loader
        pkgs.wayland
        pkgs.libxkbcommon
        pkgs.openssl

        pkgs.cargo-nextest
        pkgs.postgresql
        pkgs.postgrest

        pkgs.curl

        rust.stable
      ];
      # this drops into a dev shell first since I couldn't find a way to configure the LD_LIBRARY_PATH in writeShellApplication
      runInDevshell = { name, runtimeInputs, text }:
        let
          realCommand = pkgs.writeShellApplication { inherit name runtimeInputs text; };
        in
        pkgs.writeShellApplication {
          name = "${name}-outer";
          runtimeInputs = [ ];
          text = "nix develop --command ${realCommand}/bin/${name}";
        };
    in
    {
      packages = {
        build-and-test-definition = runInDevshell {
          name = "build-and-tests";
          inherit runtimeInputs;
          text = '' 
          cargo build --release 
          cargo nextest run --release 
          '';
        };
        examples-runner-definition = runInDevshell rec {
          name = "examples";
          inherit runtimeInputs;
          text = '' 
          # PostgreSQL server variables for testing
          PGDATA=$(mktemp -d)
          PGPORT=5432
          PGHOST="$PGDATA/run/postgresql"
          POSTGREST_CONF="$PGDATA/postgrest.conf"

          # init the database
          initdb -D "$PGDATA"

          # create run directory
          mkdir -p "$PGHOST"
          # set run directory in config
          echo "unix_socket_directories = '$PGHOST'" >> "$PGDATA/postgresql.auto.conf"
          # start the database
          pg_ctl -D "$PGDATA" start

          # create user and db
          createuser -h "$PGHOST" || true
          createdb -h "$PGHOST" || true
          
          # create dummy data
          psql -h "$PGDATA/run/postgresql" -c "${postgrest-db-setup}"
          
          # configure and start postgrest
          echo "db-uri = \"postgres://authenticator:mysecretpassword@localhost:$PGPORT/$(whoami)\"" > "$POSTGREST_CONF"
          echo "db-schemas = \"api\"" >> "$POSTGREST_CONF"
          echo "db-anon-role = \"web_anon\"" >> "$POSTGREST_CONF"

          echo "postgres setup complete"

          postgrest "$POSTGREST_CONF" &

          postgrest_pid=$!

          # wait for postgrest to
          sleep 1

          # verify it worked
          curl http://localhost:3000/todos

          cleanup() {
            # stop postgrest
            kill $postgrest_pid
            # stop postgres
            pg_ctl -D "$PGDATA" stop
            # remove data dirs
            rm -rf "$PGDATA"
          }

          # Run your tests here
          (cargo run --release -p examples-runner && cleanup && exit 0) || (cleanup && exit 1)
          '';
        };
      };
    };
}
