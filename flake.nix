{
  description = "Public Extensions for Minimal Cloudtop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    tasks-nvim = {
      url = "github:tanmayv/tasks.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, tasks-nvim, ... }@inputs: {
    homeManagerModules = {
      tasks = { config, pkgs, lib, ... }: {
        imports = [
          (import ./tasks.nix { inherit tasks-nvim; })
        ];
      };
    };
  };
}
