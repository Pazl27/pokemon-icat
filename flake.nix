{
  description = "Pokemon-icat with reproducible sprite versions and Home Manager module";

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
    let
      # Python dependencies helper
      mkPythonWithDeps =
        pkgs:
        pkgs.python3.withPackages (
          ps: with ps; [
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
          ]
        );

    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        pythonWithDeps = mkPythonWithDeps pkgs;

        # Default pokemon icons
        default-pokemon-icons = pkgs.stdenv.mkDerivation {
          pname = "pokemon-icons";
          version = "1.2.0";

          src = self;

          nativeBuildInputs = [
            pythonWithDeps
            pkgs.cacert
            pkgs.optipng
          ];

          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = "sha256-ntz0i9HWuJXeGRO7JX/wMsjiHcpmNv/HImgqeMN4YQ8=";

          buildPhase = ''
            export POKEMON_ICAT_DATA=$TMPDIR
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            export SPRITES_COMMIT=6127a37944160e603c1a707ac0c5f8e367b4050a

            mkdir -p $POKEMON_ICAT_DATA/pokemon-icons/normal
            mkdir -p $POKEMON_ICAT_DATA/pokemon-icons/shiny

            python3 setup_icons.py --upscale 3
          '';

          installPhase = ''
            mkdir -p $out
            cp -r $POKEMON_ICAT_DATA/pokemon-icons $out/
          '';
        };

        # Standalone package
        pokemon-icat = pkgs.rustPlatform.buildRustPackage {
          pname = "pokemon-icat";
          version = "1.2.0";

          src = self;

          cargoLock = {
            lockFile = self + "/Cargo.lock";
          };

          nativeBuildInputs = [ pkgs.makeWrapper ];

          postInstall = ''
            mkdir -p $out/share/pokemon-icat
            cp -r ${self}/bin/* $out/share/pokemon-icat/
            cp -r ${default-pokemon-icons}/pokemon-icons $out/share/pokemon-icat/

            wrapProgram $out/bin/pokemon-icat \
              --set POKEMON_ICAT_DATA $out/share/pokemon-icat
          '';

          meta = with pkgs.lib; {
            description = "Show Pokémons inside your terminal!";
            homepage = "https://github.com/aflaag/pokemon-icat";
            license = licenses.mit;
            mainProgram = "pokemon-icat";
          };
        };

      in
      {
        packages = {
          default = pokemon-icat;
          pokemon-icat = pokemon-icat;
          pokemon-icons = default-pokemon-icons;
        };

        apps.default = {
          type = "app";
          program = "${pokemon-icat}/bin/pokemon-icat";
        };

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
      }
    )
    // {
      # Home Manager Module
      homeManagerModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        let
          cfg = config.programs.pokemon-icat;
          pythonWithDeps = mkPythonWithDeps pkgs;

          # Download and prepare Pokemon icons with configurable commit
          pokemon-icons = pkgs.stdenv.mkDerivation {
            pname = "pokemon-icons";
            version = "1.2.0-${builtins.substring 0 7 cfg.spritesCommit}";

            src = self;

            nativeBuildInputs = [
              pythonWithDeps
              pkgs.cacert
              pkgs.optipng
            ];

            outputHashMode = "recursive";
            outputHashAlgo = "sha256";
            outputHash = cfg.spritesHash;

            buildPhase = ''
              export POKEMON_ICAT_DATA=$TMPDIR
              export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
              export SPRITES_COMMIT=${cfg.spritesCommit}

              mkdir -p $POKEMON_ICAT_DATA/pokemon-icons/normal
              mkdir -p $POKEMON_ICAT_DATA/pokemon-icons/shiny

              python3 setup_icons.py --upscale ${toString cfg.upscaleFactor}
            '';

            installPhase = ''
              mkdir -p $out
              cp -r $POKEMON_ICAT_DATA/pokemon-icons $out/
            '';
          };

          # Main pokemon-icat package
          pokemon-icat-wrapped = pkgs.rustPlatform.buildRustPackage {
            pname = "pokemon-icat";
            version = "1.2.0";

            src = self;

            cargoLock = {
              lockFile = self + "/Cargo.lock";
            };

            nativeBuildInputs = [ pkgs.makeWrapper ];

            postInstall = ''
              mkdir -p $out/share/pokemon-icat
              cp -r ${self}/bin/* $out/share/pokemon-icat/
              cp -r ${pokemon-icons}/pokemon-icons $out/share/pokemon-icat/

              wrapProgram $out/bin/pokemon-icat \
                --set POKEMON_ICAT_DATA $out/share/pokemon-icat
            '';

            meta = with pkgs.lib; {
              description = "Show Pokémons inside your terminal!";
              homepage = "https://github.com/aflaag/pokemon-icat";
              license = licenses.mit;
              mainProgram = "pokemon-icat";
            };
          };

        in
        {
          options.programs.pokemon-icat = {
            enable = mkEnableOption "pokemon-icat";

            spritesCommit = mkOption {
              type = types.str;
              default = "6127a37944160e603c1a707ac0c5f8e367b4050a";
              example = "abc123def456...";
              description = ''
                The commit hash from PokeAPI/sprites repository to use for fetching sprites.
                This allows pinning to a specific version of the sprites.
              '';
            };

            spritesHash = mkOption {
              type = types.str;
              default = "sha256-ntz0i9HWuJXeGRO7JX/wMsjiHcpmNv/HImgqeMN4YQ8=";
              example = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
              description = ''
                The expected hash of the downloaded sprites for the specified commit.

                To find the correct hash:
                1. Set this to a dummy value like "sha256-AAAA..."
                2. Try to build
                3. Nix will show you the expected hash in the error message
                4. Update this value with the expected hash from the error
                5. Build again - it should now succeed
              '';
            };

            upscaleFactor = mkOption {
              type = types.float;
              default = 3.0;
              example = 2.0;
              description = "Factor by which to upscale the Pokemon sprites";
            };
          };

          config = mkIf cfg.enable {
            home.packages = [ pokemon-icat-wrapped ];
          };
        };
    };
}
