{ config, pkgs, lib, userSettings ? {}, ... }:

with lib;

{
  services.agent-tracker.enable = mkDefault (userSettings.enable-agent-tracker or false);
  services.agent-tracker.enableTmuxIntegration = mkDefault true;
  services.agent-tracker.agents = {
    gemini = mkDefault "gemini";
  };
}
