{
  description = "my xmonad configurations";

  inputs = {
    haedosa.url = "github:haedosa/flakes";
    nixpkgs.follows = "haedosa/nixpkgs";
    home-manager.follows = "haedosa/home-manager";
    wallpapers.url = "github:jjdosa/wallpapers";
    wallpapers.flake = false;
  };

  outputs = inputs@{ nixpkgs, ... }:
  let
    inherit (nixpkgs.lib) genAttrs;
    supportedSystems = [ "x86_64-linux" ];
    forAllSystems = genAttrs supportedSystems;
    pkgsFor = system: import ./pkgs.nix { inherit inputs system; };
  in
  {
    homeManagerModules = import ./modules/home-manager inputs;

    packages = forAllSystems (import ./packages inputs);

    devShells = forAllSystems (system: {
      default = import ./shell.nix { pkgs = pkgsFor system; };
    });

  };

}
