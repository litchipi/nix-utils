# nix-utils

Useful Nix templates, tools, and derivation, for misc tasks

## Usage

In a flake:
```
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # ...
    utils = {
      url = "github:litchipi/nix-utils/ci";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixpkgs, ...} @ inputs: let
    pkgs = import nixpkgs {
      # ...
      overlays = [ inputs.utils.overlays.${system}.default ];
    };
    lib = pkgs.lib;
    mkApp = exec: { type = "app"; program = toString exec; };

    # Build a typst document
    # Especially a polylux presentation
    typstcfg = {
      common = ./common;
      fonts = ./fonts/dir;
      typst_deps = [ lib.typst.typstpkgs.polylux ];
      presentation = true;
    };
    pres = lib.typst.mkPolyluxPresentation typstcfg ./my/presentation.typ;
  in {
    # ...

    # Scripts used inside your super nixified CI
    apps.${system} = {
      checkTodo = mkApp (lib.ci.check_todos {
        ignored_files = [ ".github" ];
      });
    };
  };
}
```
