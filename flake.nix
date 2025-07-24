{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system: let
    pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [
        inputs.rust-overlay.overlays.default
      ];
    };
    typst = import ./typst.nix pkgs;
    ci = import ./ci/lib.nix pkgs;
  in {
    overlays.default = (self: super: {
      lib = super.lib // {
        inherit typst;
        inherit ci;
      };
    });
  });
}
