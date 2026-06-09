{ pi-nix }:
{ config, pkgs, lib, userSettings ? {}, ... }:

with lib;

let
  enableThirdPartyAgents = userSettings.enable-third-party-agents or false;
  enablePi = userSettings.enable-pi-agent or true;
  enableClaude = userSettings.enable-claude-agent or enableThirdPartyAgents;
  enableCodex = userSettings.enable-codex-agent or enableThirdPartyAgents;
  enableGemini = userSettings.enable-gemini-agent or enableThirdPartyAgents;
  piPackage = pi-nix.packages.${pkgs.system}.default;
  claudePackage = builtins.tryEval pkgs.claude-code;
  codexPackage = builtins.tryEval pkgs.codex;
  geminiPackage = builtins.tryEval pkgs.gemini-cli;
in
{
  services.agent-tracker.enable = mkDefault (userSettings.enable-agent-tracker or false);
  services.agent-tracker.enableTmuxIntegration = mkDefault true;

  # Install the raw agent commands directly. In particular, `pi` must resolve
  # to the pi.nix package's final Nix-store command (for example
  # `/nix/store/...-pi-coding-agent-*/bin/pi`), never to a generated tracking
  # wrapper. Tracked launches must be explicit via:
  #   broccoli-comms run NAME --cwd DIR -- COMMAND [ARGS...]
  home.packages =
    (optional (enableClaude && claudePackage.success) claudePackage.value)
    ++ (optional (enableCodex && codexPackage.success) codexPackage.value)
    ++ (optional (enableGemini && geminiPackage.success) geminiPackage.value)
    ++ (optional enablePi piPackage);

  home.file =
    (optionalAttrs enableGemini {
      ".gemini/GEMINI.md".source = ./GEMINI.md;
      ".gemini/CLAUDE.md".source = ./GEMINI.md;
      ".gemini/CODEX.md".source = ./GEMINI.md;
      ".gemini/PI.md".source = ./GEMINI.md;
      ".gemini/skills/agent-memory-audit".source = ./skills/agent-memory-audit;
    })
    // (optionalAttrs enableClaude {
      ".claude/CLAUDE.md".source = ./GEMINI.md;
      ".claude/skills/broccoli-comms-cli".source = ./skills/broccoli-comms-cli;
      ".claude/skills/agent-inbox-user-reply".source = ./skills/agent-inbox-user-reply;
      ".claude/skills/agent-memory-audit".source = ./skills/agent-memory-audit;
    })
    // (optionalAttrs enableCodex {
      ".codex/AGENTS.md".source = ./GEMINI.md;
      ".codex/skills/broccoli-comms-cli".source = ./skills/broccoli-comms-cli;
      ".codex/skills/agent-inbox-user-reply".source = ./skills/agent-inbox-user-reply;
      ".codex/skills/agent-memory-audit".source = ./skills/agent-memory-audit;
    })
    // (optionalAttrs enablePi {
      ".pi/agent/skills/broccoli-comms-cli".source = ./skills/broccoli-comms-cli;
      ".pi/agent/skills/agent-inbox-user-reply".source = ./skills/agent-inbox-user-reply;
      ".pi/agent/skills/agent-memory-audit".source = ./skills/agent-memory-audit;
      ".pi/agent/extensions/auto-restart-watchdog.ts".source = ./pi-extensions/auto-restart-watchdog.ts;
    });
}
