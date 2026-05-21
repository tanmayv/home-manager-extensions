{ pi-nix }:
{ config, pkgs, lib, userSettings ? {}, ... }:

with lib;

let
  enablePi = userSettings.enable-pi-agent or false;
  piPackage = pi-nix.packages.${pkgs.system}.default;
  claudePackage = builtins.tryEval pkgs.claude-code;
in
{
  services.agent-tracker.enable = mkDefault (userSettings.enable-agent-tracker or false);
  services.agent-tracker.enableTmuxIntegration = mkDefault true;
  services.agent-tracker.agents = {
    gemini = mkDefault "gemini";
    claude = mkDefault "claude";
    codex = mkDefault "codex";
  } // (optionalAttrs enablePi {
    pi = mkDefault "${piPackage}/bin/pi";
  });

  home.packages = mkIf (!config.services.agent-tracker.enable) (
    (optional claudePackage.success claudePackage.value) ++ [
      pkgs.codex
    ] ++ (optional enablePi piPackage)
  );

  home.file = {
    ".gemini/GEMINI.md".source = ./GEMINI.md;
    ".gemini/CLAUDE.md".source = ./GEMINI.md;
    ".gemini/CODEX.md".source = ./GEMINI.md;
    ".gemini/PI.md".source = ./GEMINI.md;
  };
}
