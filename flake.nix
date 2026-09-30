{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
        pkgs = nixpkgs.legacyPackages.${system};

        cousine-font = pkgs.fetchurl {
          url = "https://github.com/google/fonts/raw/ab75f7cf3e87c9ba8663f431f2ee4279c6406ee3/ofl/cousine/Cousine-Regular.ttf";
          sha256 = "sha256-HaIiUGdfxMQvzzqXNsRLwFcFFhBTMUQ7Zj/Vz70UEv4=";
        };

        comic-shans-font = pkgs.fetchurl {
          url = "https://github.com/shannpersand/comic-shanns/raw/b98eee0894464de98754d6c89ffdfb8c29ce9e45/v2/comic%20shanns%202.ttf";
          sha256 = "sha256-ZFkLeUyrdBk3iJ03myBa4SbKTz7Vy+TxmDnSv6wkbaY=";
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
          url = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/FontPatcher.zip";
          sha256 = "sha256-gZ41oZPnsVLcchA58eJ1Vl28ccqePpOZd/ZCEKYywX4=";
          stripRoot = false;
        };

      in {
        packages.komisch-mono = pkgs.stdenv.mkDerivation {
          pname = "Komisch Mono";
          version = "1.1.0";
          src = ./.;

          nativeBuildInputs = with pkgs; [
            python314
            python314Packages.fontforge
          ];

          buildPhase = ''
            mkdir -p vendor output

            ln -sf "${cousine-font}" vendor/Cousine-Regular.ttf
            ln -sf "${comic-shans-font}" vendor/comic-shanns.ttf

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

            ligaturize() {
              local file_name="$1"

              fontforge -lang py -script ligaturize.py "$file_name" \
                --output-dir="$pwd/output"  \
                --prefix=""
            }

            # Hack: Ligaturizer reads ligatures.py from its own directory, so
            # overwrite it using our own ligatures.py.
            pwd="$(pwd)"
            cp -r --no-preserve=mode ${lig} "$TMP/ligaturizer"
            cp ${./ligatures.py} "$TMP/ligaturizer/ligatures.py"
            pushd "$TMP/ligaturizer" || exit 1
            # TTF.
            ligaturize "$TMP/KomischMono-Regular.ttf"
            ligaturize "$TMP/KomischMono-Bold.ttf"
            # OTF.
            ligaturize "$TMP/KomischMono-Regular.otf"
            ligaturize "$TMP/KomischMono-Bold.otf"
            popd || exit 1
          '';

          installPhase = ''
            install -m444 -Dt "$out" "output/"*.{ttf,otf}
          '';
        };

        defaultPackage = self.packages.${system}.komisch-mono;
      }
    );
}
