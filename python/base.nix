{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import inputs.nixpkgs { inherit system; };
    python_version = pkgs.python312;
    custom_pkgs = (import ./packages.nix pkgs python_version.pkgs);
    pythonpkg = python_version.withPackages (p: with p; [
    ]);

    env = {
    };

    envexport = builtins.concatStringsSep "\n" (pkgs.lib.attrsets.mapAttrsToList
      (n: v: "export ${n}=${v}")
    ) env;

    mkApp = name: script: {
      type = "app";
      program = let
        f = pkgs.writeShellScript name ''
          ${envexport}

          ${script}
        '';
      in "${f}";
    };
  in {
    apps = builtins.mapAttrs mkApp {
      default = "${pythonpkg}/bin/python ./script.py";
    };

    devShells.default = pkgs.mkShell ({
      buildInputs = [ pythonpkg ];
      PYTHONPATH = "${pythonpkg}/${pythonpkg.sitePackages}:$PYTHONPATH";
      LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib$LD_LIBRARY_PATH";
    } // env);
  });
}
