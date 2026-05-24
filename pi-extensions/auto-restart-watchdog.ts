import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const DEFAULT_TIMEOUT_MS = 5 * 60 * 1000;
const EXTENSION_NAME = "auto-restart-watchdog";

function parsePositiveInt(value: string | undefined, fallback: number): number {
	if (!value) return fallback;
	const parsed = Number.parseInt(value, 10);
	return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function parseEnabled(value: string | undefined): boolean {
	if (!value) return true;
	return !["0", "false", "off", "no", "disabled"].includes(value.toLowerCase());
}

function notify(ctx: ExtensionContext, message: string, level: "info" | "warning" | "error" = "info") {
	if (ctx.hasUI) ctx.ui.notify(message, level);
}

export default function (pi: ExtensionAPI) {
	let enabled = parseEnabled(process.env.PI_AUTO_RESTART_WATCHDOG_ENABLED);
	let timeoutMs = parsePositiveInt(process.env.PI_AUTO_RESTART_WATCHDOG_MS, DEFAULT_TIMEOUT_MS);
	let maxRestarts = parsePositiveInt(process.env.PI_AUTO_RESTART_WATCHDOG_MAX_RESTARTS, 0);
	let timer: ReturnType<typeof setTimeout> | undefined;
	let statusInterval: ReturnType<typeof setInterval> | undefined;
	let deadlineMs: number | undefined;
	let activeTurn = 0;
	let restartCount = 0;
	let pendingContinuation = false;

	const continuationPrompt = process.env.PI_AUTO_RESTART_WATCHDOG_PROMPT
		?? "Continue from where you were automatically stopped. Briefly re-check current state, avoid repeating completed work, then proceed with the user's task.";

	function maxRestartText(): string {
		return maxRestarts > 0 ? `${restartCount}/${maxRestarts}` : `${restartCount}/∞`;
	}

	function statusText(): string {
		if (!enabled) return "watchdog: off";
		if (pendingContinuation) return `watchdog: restarting (${maxRestartText()})`;
		if (deadlineMs !== undefined) {
			const remaining = Math.max(0, Math.ceil((deadlineMs - Date.now()) / 1000));
			return `watchdog: ${remaining}s left (${maxRestartText()})`;
		}
		return `watchdog: idle ${Math.round(timeoutMs / 1000)}s (${maxRestartText()})`;
	}

	function updateStatus(ctx: ExtensionContext) {
		if (ctx.hasUI) ctx.ui.setStatus(EXTENSION_NAME, statusText());
	}

	function clearWatchdog(ctx?: ExtensionContext) {
		if (timer) {
			clearTimeout(timer);
			timer = undefined;
		}
		if (statusInterval) {
			clearInterval(statusInterval);
			statusInterval = undefined;
		}
		deadlineMs = undefined;
		if (ctx) updateStatus(ctx);
	}

	function sendContinuationAfterAbort(ctx: ExtensionContext) {
		if (!pendingContinuation) return;
		pendingContinuation = false;
		updateStatus(ctx);

		// Let Pi finish transitioning from aborted -> idle before sending a normal
		// user message. Sending with deliverAs: "followUp" before abort can leave a
		// visible queued follow-up instead of immediately starting the replacement turn.
		setTimeout(() => {
			try {
				if (ctx.isIdle()) {
					pi.sendUserMessage(continuationPrompt);
				} else {
					pi.sendUserMessage(continuationPrompt, { deliverAs: "steer" });
				}
			} catch (error) {
				notify(ctx, `Watchdog could not send continuation: ${error instanceof Error ? error.message : String(error)}`, "error");
			}
		}, 100);
	}

	function armWatchdog(ctx: ExtensionContext) {
		clearWatchdog();
		updateStatus(ctx);
		if (!enabled) return;

		const turnId = ++activeTurn;
		deadlineMs = Date.now() + timeoutMs;
		updateStatus(ctx);
		statusInterval = setInterval(() => updateStatus(ctx), 1000);

		timer = setTimeout(() => {
			if (turnId !== activeTurn || ctx.isIdle()) return;
			if (maxRestarts > 0 && restartCount >= maxRestarts) {
				clearWatchdog(ctx);
				notify(ctx, `Watchdog reached max restarts (${maxRestarts}); leaving agent running.`, "warning");
				return;
			}

			restartCount += 1;
			pendingContinuation = true;
			deadlineMs = undefined;
			updateStatus(ctx);
			notify(ctx, `Watchdog stopping this turn after ${Math.round(timeoutMs / 1000)}s; continuation will start after abort #${restartCount}.`, "warning");
			ctx.abort();
		}, timeoutMs);
	}

	pi.on("session_start", async (_event, ctx) => {
		restartCount = 0;
		pendingContinuation = false;
		updateStatus(ctx);
		notify(ctx, `Auto-restart watchdog loaded (${enabled ? `${Math.round(timeoutMs / 1000)}s` : "off"}; max restarts ${maxRestarts > 0 ? maxRestarts : "unlimited"}).`, "info");
	});

	pi.on("agent_start", async (_event, ctx) => {
		armWatchdog(ctx);
	});

	pi.on("agent_end", async (_event, ctx) => {
		clearWatchdog(ctx);
		sendContinuationAfterAbort(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		clearWatchdog();
		pendingContinuation = false;
		if (ctx.hasUI) ctx.ui.setStatus(EXTENSION_NAME, undefined);
	});

	async function watchdogCommand(args: string, ctx: ExtensionContext) {
		const parts = args.trim().split(/\s+/).filter(Boolean);
		const command = parts[0] ?? "status";

		if (command === "on") {
			enabled = true;
			updateStatus(ctx);
			notify(ctx, `Watchdog enabled (${Math.round(timeoutMs / 1000)}s; max restarts ${maxRestarts > 0 ? maxRestarts : "unlimited"}).`, "info");
			return;
		}

		if (command === "off") {
			enabled = false;
			pendingContinuation = false;
			clearWatchdog(ctx);
			notify(ctx, "Watchdog disabled.", "info");
			return;
		}

		if (command === "seconds" || command === "timeout") {
			const seconds = parsePositiveInt(parts[1], 0);
			if (!seconds) {
				notify(ctx, "Usage: /watchdog seconds <positive-number>", "warning");
				return;
			}
			timeoutMs = seconds * 1000;
			updateStatus(ctx);
			notify(ctx, `Watchdog timeout set to ${seconds}s. It applies to the next agent turn.`, "info");
			return;
		}

		if (command === "max" || command === "max-restarts") {
			const value = parts[1];
			if (value === "unlimited" || value === "infinite" || value === "0") {
				maxRestarts = 0;
				updateStatus(ctx);
				notify(ctx, "Watchdog max restarts set to unlimited.", "info");
				return;
			}
			const parsed = parsePositiveInt(value, -1);
			if (parsed < 0) {
				notify(ctx, "Usage: /watchdog max <positive-number|0|unlimited>", "warning");
				return;
			}
			maxRestarts = parsed;
			updateStatus(ctx);
			notify(ctx, `Watchdog max restarts set to ${maxRestarts}.`, "info");
			return;
		}

		if (command === "reset") {
			restartCount = 0;
			updateStatus(ctx);
			notify(ctx, "Watchdog restart counter reset.", "info");
			return;
		}

		notify(
			ctx,
			`Watchdog ${enabled ? "enabled" : "disabled"}; timeout=${Math.round(timeoutMs / 1000)}s; restarts=${maxRestartText()}.`,
			"info",
		);
	}

	pi.registerCommand("watchdog", {
		description: "Manage the auto-restart watchdog: /watchdog status|on|off|seconds <n>|max <n|unlimited>|reset",
		handler: watchdogCommand,
	});

	pi.registerCommand("watchdon", {
		description: "Alias for /watchdog",
		handler: watchdogCommand,
	});
}
