{ pi-nix }:
{ config, pkgs, lib, userSettings ? {}, ... }:

with lib;

let
  piPackage = pi-nix.packages.${pkgs.system}.default;
in
{
  services.agent-tracker.enable = mkDefault (userSettings.enable-agent-tracker or false);
  services.agent-tracker.enableTmuxIntegration = mkDefault true;
  services.agent-tracker.agents = {
    gemini = mkDefault "gemini";
    pi = mkDefault "${piPackage}/bin/pi";
  };

  home.packages = mkIf (!config.services.agent-tracker.enable) [
    piPackage
  ];
}
