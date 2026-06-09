{ pi-nix }:
{ config, pkgs, lib, userSettings ? {}, ... }:

with lib;

let
  enablePi = userSettings.enable-pi-agent or true;
  enableThirdPartyAgents = userSettings.enable-third-party-agents or false;
  piPackage = pi-nix.packages.${pkgs.system}.default;
  claudePackage = builtins.tryEval pkgs.claude-code;
  codexPackage = builtins.tryEval pkgs.codex;
  geminiPackage = builtins.tryEval pkgs.gemini-cli;
  agentCommand = package: binName:
    mkDefault (if package.success then "${package.value}/bin/${binName}" else binName);
in
{
  services.agent-tracker.enable = mkDefault (userSettings.enable-agent-tracker or false);
  services.agent-tracker.enableTmuxIntegration = mkDefault true;
  services.agent-tracker.agents = {
    gemini = agentCommand geminiPackage "gemini";
  } // (optionalAttrs enablePi {
    pi = mkDefault "${piPackage}/bin/pi";
  } // (optionalAttrs enableThirdPartyAgents {
    claude = agentCommand claudePackage "claude";
    codex = agentCommand codexPackage "codex";
  }));

  # Install the raw agent commands directly. We no longer create command-name
  # wrappers such as `pi -> broccoli-comms track`; tracked launches must be
  # explicit via `broccoli-comms run NAME --cwd DIR -- COMMAND [ARGS...]`.
  home.packages =
    (optional claudePackage.success claudePackage.value)
    ++ (optional codexPackage.success codexPackage.value)
    ++ (optional geminiPackage.success geminiPackage.value)
    ++ (optional enablePi piPackage);

  home.file = {
    ".gemini/GEMINI.md".source = ./GEMINI.md;
    ".gemini/CLAUDE.md".source = ./GEMINI.md;
    ".gemini/CODEX.md".source = ./GEMINI.md;
    ".gemini/PI.md".source = ./GEMINI.md;
    ".claude/CLAUDE.md".source = ./GEMINI.md;
    ".claude/skills/broccoli-comms-cli".source = ./skills/broccoli-comms-cli;
    ".claude/skills/agent-inbox-user-reply".source = ./skills/agent-inbox-user-reply;
    ".codex/AGENTS.md".source = ./GEMINI.md;
    ".codex/skills/broccoli-comms-cli".source = ./skills/broccoli-comms-cli;
    ".codex/skills/agent-inbox-user-reply".source = ./skills/agent-inbox-user-reply;
    ".pi/agent/skills/broccoli-comms-cli".source = ./skills/broccoli-comms-cli;
    ".pi/agent/skills/agent-inbox-user-reply".source = ./skills/agent-inbox-user-reply;
    ".pi/agent/extensions/auto-restart-watchdog.ts".source = ./pi-extensions/auto-restart-watchdog.ts;
  };
}
