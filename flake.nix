{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
        pkgs = nixpkgs.legacyPackages.${system};

        cousine-font = pkgs.fetchurl {
          url = "https://github.com/google/fonts/raw/main/apache/cousine/Cousine-Regular.ttf";
          sha256 = "sha256-aeHqWet3ABQgTlF0+AV1D5p5PbSiUx5lFrMLdGDUcLM=";
        };

        comic-shans-font = pkgs.fetchurl {
          url = "https://github.com/shannpersand/comic-shanns/raw/master/v2/comic%20shanns.otf";
          sha256 = "sha256-ogAILIIBbTnwUYzUSdX6VIbbSo7kuXihDUOZpVo1fVQ=";
        };

        # Ligaturizer.
        lig = pkgs.fetchgit {
          url = "https://github.com/ToxicFrog/Ligaturizer";
          rev = "c4065187a544a8fab40826fc91db1c6180a2d342";
          sha256 = "sha256-3gDD3jCyuXpb/V44RI+AgViqZ54gYN0fgdEvqSKyJdo=";
          fetchSubmodules = true;
          sparseCheckout = [
            "fonts/fira"
          ];
        };

        # Nerdfont Font Patcher.
        nf = pkgs.fetchzip {
          url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FontPatcher.zip";
          sha256 = "koZj0Tn1HtvvSbQGTc3RbXQdUU4qJwgClOVq1RXW6aM=";
          stripRoot = false;
        };

      in {
        packages.komisch-mono = pkgs.stdenv.mkDerivation {
          pname = "Komisch Mono";
          version = "1.1.0";
          src = ./.;

          nativeBuildInputs = with pkgs; [
            python311
            fontforge
          ];

          buildPhase = ''
            mkdir -p vendor output

            ln -sf "${cousine-font}" vendor/Cousine-Regular.ttf
            ln -sf "${comic-shans-font}" vendor/comic-shanns.otf

            TMP=$(mktemp -d)
            python generate.py "$TMP"

            # Patch Nerdfont symbols.
            patchNF() {
              local file_name="$1"
              local ext="$2"

              fontforge -script ${nf}/font-patcher -q \
                --fontlogos --codicons --fontawesome --octicons --powersymbols --pomicons --powerline --powerlineextra --weather \
                -out="$TMP" --makegroups -1 -ext "$ext" "$file_name"
            }

            # TTF.
            patchNF "$TMP/komisch-mono-regular.ttf" "ttf"
            patchNF "$TMP/komisch-mono-bold.ttf" "ttf"
            # OTF.
            patchNF "$TMP/komisch-mono-regular.ttf" "otf"
            patchNF "$TMP/komisch-mono-bold.ttf" "otf"

            # Ligaturize.
            ligaturize() {
              local file_name="$1"

              fontforge -lang py -script ligaturize.py "$file_name" \
                --output-dir="$pwd/output"  \
                --prefix=""
            }
            pwd=$(pwd)
            pushd ${lig} || exit
            # TTF.
            ligaturize "$TMP/KomischMono-Regular.ttf"
            ligaturize "$TMP/KomischMono-Bold.ttf"
            # OTF.
            ligaturize "$TMP/KomischMono-Regular.otf"
            ligaturize "$TMP/KomischMono-Bold.otf"
            popd || exit
          '';

          installPhase = ''
            install -m444 -Dt "$out" "output/"*.{ttf,otf}
          '';
        };

        defaultPackage = self.packages.${system}.komisch-mono;
      }
    );
}
