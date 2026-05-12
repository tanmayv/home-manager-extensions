{
  description = "Public Extensions for Minimal Cloudtop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    tasks-nvim = {
      url = "github:tanmayv/tasks.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pi-nix = {
      url = "github:lukasl-dev/pi.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, tasks-nvim, pi-nix, ... }@inputs: {
    homeManagerModules = {
      tasks = { config, pkgs, lib, ... }: {
        imports = [
          (import ./tasks.nix { inherit tasks-nvim; })
        ];
      };
      ai-agents = { config, pkgs, lib, ... }: {
        imports = [
          (import ./ai-agents.nix { inherit pi-nix; })
        ];
      };
    };
  };
}
