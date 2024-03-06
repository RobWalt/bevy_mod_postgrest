{ inputs, ... }:
{
  perSystem = { pkgs, system, ... }:
    let
      rust = import ./../rust.nix { inherit inputs system; };
      # this is basically the postgrest tutorial setup and should suffice for testing purposes
      postgrest-db-setup = ''"${builtins.replaceStrings ["$"] ["\\$"] (builtins.readFile ./init_db.sql)}"'';
    in
    {
      devShells = rec {
        run-test = pkgs.mkShell rec {
          packages = [
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

            (pkgs.writeShellScriptBin "cleanup" '' 
            ${pkgs.postgresql}/bin/pg_ctl -D $PGDATA stop
            rm -rf $PGDATA 
            rm -rf /run/postgresql
            '')

            rust.stable
          ];
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath packages;
          shellHook = '' 
          # PostgreSQL server variables for testing
          export PGDATA=$(mktemp -d)
          export PGPORT=5432
          export PGHOST="$PGDATA/run/postgresql"
          export POSTGREST_CONF="$PGDATA/postgrest.conf"

          # init the database
          initdb -D $PGDATA
          # create run directory
          mkdir -p $PGHOST
          # set run directory in config
          echo "unix_socket_directories = '$PGHOST'" >> $PGDATA/postgresql.auto.conf
          # start the database
          pg_ctl -D $PGDATA start

          # create user and db
          createuser
          createdb
          
          # create dummy data
          psql -c ${postgrest-db-setup}
          
          # configure and start postgrest
          echo "db-uri = \"postgres://authenticator:mysecretpassword@localhost:$PGPORT/aviac\"" > $POSTGREST_CONF
          echo "db-schemas = \"api\"" >> $POSTGREST_CONF
          echo "db-anon-role = \"web_anon\"" >> $POSTGREST_CONF

          postgrest $POSTGREST_CONF &

          postgrest_pid=$!

          # wait for postgrest to
          sleep 1

          # verify it worked
          ${pkgs.curl}/bin/curl http://localhost:3000/todos

          # Run your tests here
          cargo nextest run --no-capture

          # Clean up
          
          # stop postgrest
          kill $postgrest_pid
          # stop postgres
          pg_ctl -D $PGDATA stop
          # remove data dirs
          rm -rf $PGDATA 
          # exit shell (success)
          exit
          '';
        };

        develop-test = pkgs.mkShell rec {
          packages = [ pkgs.postgresql ];
        };
      };
    };
}
