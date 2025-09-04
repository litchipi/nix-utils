pkgs: let
  setup_typst_deps = deps: builtins.concatStringsSep "\n" (builtins.map (dep: ''
    mkdir -p $HOME/.cache/typst/packages/preview/${dep.name}
    cp -r ${dep.src} $HOME/.cache/typst/packages/preview/${dep.name}/${dep.version}
    echo "${dep.name}-${dep.version} dependency copied to $HOME/.cache/typst/ directory"
  '') deps);

  baseDeriv = buildScript: {
    common,
    fonts,
    typst_deps,
    addDeps ? [],
    addFiles ? [],
    mkdir ? true,
  ... }: src: pkgs.stdenv.mkDerivation {
    name = builtins.baseNameOf src;
    inherit src;
    buildInputs = [ pkgs.typst pkgs.bash ] ++ addDeps;

    phases = ["unpackPhase" "configurePhase" "buildPhase"];

    unpackPhase = ''
      export HOME=$(realpath ./.home)
      ${setup_typst_deps typst_deps}
      cp -r ${src} ./src
      chmod +w -R src
    '';

    configurePhase = ''
    '';

    buildPhase = ''
      cd src
      ln -s ${common} ./common
      mkdir -p $out

      find . -name "*.typ" -type f -print0 | while read -d $'\0' fpath; do
        unset SOURCE_DATE_EPOCH
        export HOME=$(realpath ../.home)
        export TYPST_FONT_PATHS=${fonts}
        export SRC=$(realpath .)
        set -e
        rootd=$(realpath `dirname $fpath`)
        fname=$(basename $fpath)
    ''
      + (if (! mkdir) then ''
          prefix=$(echo "''${rootd#$SRC}/" | cut -d'/' -f2- | sed 's+/+_+g')
      ''
      else ''
          prefix=$(echo "''${rootd#$SRC}/" | cut -d'/' -f2-)
          mkdir -p "$out/''${prefix}"
      '') + ''

        ${buildScript}

      done

      ${builtins.concatStringsSep "\n" (builtins.map (f: ''
        dirname ${f} | xargs realpath --relative-to=$PWD | xargs mkdir -p
        cp ./${f} $out/${f}
      '') addFiles)}
    '';
  };

in {
  inherit setup_typst_deps;

  typstpkgs = {
    suiji = {
      name = "suiji";
      version = "0.4.0";
      src = pkgs.fetchFromGitHub {
        owner = "liuguangxi";
        repo = "suiji";
        rev = "2c8216555252b76cf2e8e0baad8787de30d67299";
        sha256 = "sha256-iddw2zPuu/0qzuR6Ys+xtr/cvPm9ry6b564KvjQwuAc=";
      };
    };

    polylux = rec {
      name = "polylux";
      version = "0.4.0";
      src = pkgs.fetchFromGitHub {
        owner = "andreasKroepelin";
        repo = "polylux";
        rev = "v${version}";
        sha256 = "sha256-WUBxDHoyL2SNob6mzuE8aB0EIT1UxoTDTKedTsfhqmw=";
      };
    };
  };

  mkTypstDocs = baseDeriv ''
    outfname="''${prefix}''${fname%.typ}.pdf"
    echo "Generating PDF for $outfname"
    typst compile \
      --root "$SRC" \
      "$fpath" \
      "$out/$outfname"
  '';

  mkPolyluxPresentation = baseDeriv ''
    outfname="''${prefix}''${fname%.typ}.pdf"
    echo "Generating PDF for $outfname"

    typst compile \
      --root "$SRC" \
      "$fpath" \
      "$out/$outfname"
    docsha=$(sha256sum "$out/$outfname" | awk '{print $1}')

    if grep "slide" "$fpath" 1>/dev/null 2>/dev/null; then
      presout="''${fpath%.typ}_pres.typ"
      cp $fpath "$presout"
      sed -i "s+#code_annex+#silence+g" $presout
      sed -i "s+#annex+#silence+g" $presout

      mkdir -p $(dirname "$out/presentation/''${outfname}")
      typst compile \
        --root "$SRC" \
        --input presentation=1 \
        "$presout" \
        "$out/presentation/$outfname"
      pressha=$(sha256sum "$out/presentation/$outfname" | awk '{print $1}')

      if [[ "$pressha" == "$docsha" ]]; then
        echo "Presentation & document are the same"
        rm "$out/presentation/$outfname"
        ln -s "$out/$outfname" "$out/presentation/$outfname"
      fi
    fi
  '';

  mkDocFromText = { name, version, text, config }: pkgs.stdenv.mkDerivation {
    pname = name;
    inherit version;
    phases = ["buildPhase"];
    buildInputs = [ pkgs.typst pkgs.bash ];
    buildPhase = ''
      cat << EOF > ./src.typ
      ${text}
      EOF

      export HOME=$(realpath ./.home)
      ${setup_typst_deps config.typst_deps}
      ln -s ${config.common} ./common
      unset SOURCE_DATE_EPOCH
      export TYPST_FONT_PATHS=${config.fonts}
      mkdir -p $out
      typst compile ./src.typ $out/${name}-${version}.pdf
    '';
  };
}
