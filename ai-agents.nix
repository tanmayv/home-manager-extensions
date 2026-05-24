{ pi-nix }:
{ config, pkgs, lib, userSettings ? {}, ... }:

with lib;

let
  enablePi = userSettings.enable-pi-agent or false;
  piPackage = pi-nix.packages.${pkgs.system}.default;
  claudePackage = builtins.tryEval pkgs.claude-code;
  codexPackage = builtins.tryEval pkgs.codex;
  codexCommand = if codexPackage.success then "${codexPackage.value}/bin/codex" else "codex";
in
{
  services.agent-tracker.enable = mkDefault (userSettings.enable-agent-tracker or false);
  services.agent-tracker.enableTmuxIntegration = mkDefault true;
  services.agent-tracker.agents = {
    gemini = mkDefault "gemini";
    claude = mkDefault "claude";
    codex = mkDefault codexCommand;
  } // (optionalAttrs enablePi {
    pi = mkDefault "${piPackage}/bin/pi";
  });

  home.packages = mkIf (!config.services.agent-tracker.enable) (
    (optional claudePackage.success claudePackage.value)
    ++ (optional codexPackage.success codexPackage.value)
    ++ (optional enablePi piPackage)
  );

  home.file = {
    ".gemini/GEMINI.md".source = ./GEMINI.md;
    ".gemini/CLAUDE.md".source = ./GEMINI.md;
    ".gemini/CODEX.md".source = ./GEMINI.md;
    ".gemini/PI.md".source = ./GEMINI.md;
  };
}
