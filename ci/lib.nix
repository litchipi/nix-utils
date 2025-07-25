pkgs: {
  check_conventional_commit = import ./check_conventional_commit.nix pkgs;
  check_todos = import ./check_todos.nix pkgs;
  lint = {
    nix = src: let
      deadnix = "${pkgs.deadnix}/bin/deadnix";
      alejandra = "${pkgs.alejandra}/bin/alejandra";
      statix = "${pkgs.statix}/bin/statix";
    in pkgs.writeShellScript "lint_nix" ''
      set +e
      ERRCODE=0

      if ! ${statix} check -- ${src}; then
        ${statix} fix ${src}
        ERRCODE=1
      fi

      if ! ${deadnix} -f ${src}; then
        ERRCODE=1
      fi

      if ! ${alejandra} -q -c ${src}; then
        ${alejandra} -q ${src}
        ERRCODE=1
      fi
      exit $ERRCODE
    '';

    rust = {
      src ? "./",
      nightly ? false,
      version ? "latest",
      audit ? true,
    }: let
      chain = if nightly then "nightly" else "stable";
      rust = pkgs.rust-bin.${chain}.${version}.default;
    in pkgs.writeShellScript "lint-rust" ''
      set -e
      cd ${src}
      ${rust}/bin/cargo fmt --check
      ${rust}/bin/cargo clippy
      ${if audit
        then "${pkgs.cargo-audit}/bin/cargo-audit audit"
        else ""
      }
    '';
  };
}
