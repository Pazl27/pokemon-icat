{
  description = "pokemon-icat";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        # Python environment with required dependencies
        pythonWithDeps = pkgs.python3.withPackages (ps: with ps; [
          aiohappyeyeballs
          aiohttp
          aiosignal
          async-timeout
          attrs
          frozenlist
          idna
          markdown-it-py
          mdurl
          multidict
          pillow
          propcache
          pygments
          python-slugify
          rich
          text-unidecode
          typing-extensions
          yarl
        ]);

        # Download and prepare Pokemon icons
        pokemon-icons = pkgs.stdenv.mkDerivation {
          pname = "pokemon-icons";
          version = "1.2.0";

          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./setup_icons.py
              ./bin
            ];
          };

          nativeBuildInputs = [
            pythonWithDeps
            pkgs.cacert
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.optipng
          ];

          # Fixed output derivation to cache the downloaded icons
          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = "sha256-ntz0i9HWuJXeGRO7JX/wMsjiHcpmNv/HImgqeMN4YQ8=";

          buildPhase = ''
            export POKEMON_ICAT_DATA=$TMPDIR
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

            mkdir -p $POKEMON_ICAT_DATA/pokemon-icons/normal
            mkdir -p $POKEMON_ICAT_DATA/pokemon-icons/shiny

            python3 setup_icons.py --upscale 3
          '';

          installPhase = ''
            mkdir -p $out
            cp -r $POKEMON_ICAT_DATA/pokemon-icons $out/
          '';
        };

        # Main pokemon-icat package
        pokemon-icat = pkgs.rustPlatform.buildRustPackage {
          pname = "pokemon-icat";
          version = "1.2.0";

          src = pkgs.lib.cleanSource ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          nativeBuildInputs = [
            pkgs.makeWrapper
          ];

          postInstall = ''
            # Create the data directory structure
            mkdir -p $out/share/pokemon-icat

            # Copy the CSV data file and Python modules
            cp -r bin/* $out/share/pokemon-icat/

            # Copy the downloaded Pokemon icons
            cp -r ${pokemon-icons}/pokemon-icons $out/share/pokemon-icat/

            # Wrap the binary to set the POKEMON_ICAT_DATA environment variable
            wrapProgram $out/bin/pokemon-icat \
              --set POKEMON_ICAT_DATA $out/share/pokemon-icat
          '';

          meta = with pkgs.lib; {
            description = "Show Pokémons inside your terminal!";
            homepage = "https://github.com/aflaag/pokemon-icat";
            license = licenses.mit;
            maintainers = [ ];
            mainProgram = "pokemon-icat";
          };
        };

      in {
        packages = {
          default = pokemon-icat;
          pokemon-icat = pokemon-icat;
          pokemon-icons = pokemon-icons;
        };

        # For development
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustc
            cargo
            pkg-config
            pythonWithDeps
          ];

          shellHook = ''
            export POKEMON_ICAT_DATA="$PWD/.local/share/pokemon-icat"
            mkdir -p "$POKEMON_ICAT_DATA"
          '';
        };

        # Make the app runnable with `nix run`
        apps.default = {
          type = "app";
          program = "${pokemon-icat}/bin/pokemon-icat";
          meta = {
            description = "Show Pokémons inside your terminal!";
            mainProgram = "pokemon-icat";
          };
        };
      }
    );
}
