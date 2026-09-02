import { readFileSync, statSync } from "fs";
import { dirname, join } from "path";
import * as vscode from "vscode";

const WALKTHROUGH_ID = "valencyio.valency#valency.gettingStarted";
const INSTALL_KEY = "valency.install";

interface InstallRecord {
  version: string;
  installedAt: number;
}

// What VS Code's extensions registry says about the current install.
interface RegistryEntry {
  installedTimestamp: number;
  updated: boolean;
}

// VS Code derives the server id from the extension id and the definition label.
const SERVER_ID = "valencyio.valency/Valency";

let log: vscode.LogOutputChannel;

export async function activate(
  context: vscode.ExtensionContext,
): Promise<void> {
  log = vscode.window.createOutputChannel("Valency", { log: true });
  context.subscriptions.push(
    log,
    vscode.lm.registerMcpServerDefinitionProvider("valency.mcp", {
      provideMcpServerDefinitions: () => [
        new vscode.McpHttpServerDefinition(
          "Valency",
          vscode.Uri.parse("https://mcp.valency.io/"),
        ),
      ],
    }),
    vscode.commands.registerCommand("valency.signIn", signIn),
  );

  const registry = readRegistryEntry(context);
  const current: InstallRecord = {
    version: String(context.extension.packageJSON.version),
    installedAt: installMarker(context, registry),
  };
  const previous = context.globalState.get<InstallRecord>(INSTALL_KEY);
  await context.globalState.update(INSTALL_KEY, current);

  const decision = onboardingDecision(previous, current, registry);
  log.info(
    `activate: previous=${JSON.stringify(previous)} current=${JSON.stringify(current)} registry=${JSON.stringify(registry)} onboard=${decision.onboard} (${decision.reason})`,
  );
  if (decision.onboard) {
    void showFirstRun();
  }
}

// Onboarding must run on every fresh install and every reinstall, and stay
// quiet on updates of an install that is already set up. Global state alone
// cannot tell these apart: VS Code keeps it across uninstall and reinstall.
// VS Code's registry can: installedTimestamp moves on every install, even a
// same-version reinstall that reuses the folder, and `updated` is true only
// when the install replaced an existing one (auto-update or Update button).
function onboardingDecision(
  previous: InstallRecord | undefined,
  current: InstallRecord,
  registry: RegistryEntry | undefined,
): { onboard: boolean; reason: string } {
  if (!previous) {
    return { onboard: true, reason: "no install record" };
  }
  if (current.installedAt === previous.installedAt) {
    return { onboard: false, reason: "install marker unchanged" };
  }
  if (registry) {
    if (registry.updated) {
      return { onboard: false, reason: "registry marks this install as an update" };
    }
    return { onboard: true, reason: "new install per registry" };
  }
  // Registry unreadable: a moved marker with the same version is a reinstall;
  // with a different version it is most likely an update.
  if (previous.version === current.version) {
    return { onboard: true, reason: "reinstall (registry unavailable)" };
  }
  return { onboard: false, reason: "version changed (registry unavailable)" };
}

// The registry lives next to the extension folder for the default profile and
// inside the profile directory for named profiles. Check the profile first,
// since the shared registry can hold a stale entry from another profile.
function readRegistryEntry(
  context: vscode.ExtensionContext,
): RegistryEntry | undefined {
  const candidates = [
    join(context.globalStorageUri.fsPath, "..", "..", "extensions.json"),
    join(dirname(context.extensionPath), "extensions.json"),
  ];
  const wanted = context.extension.id.toLowerCase();
  for (const registryPath of candidates) {
    try {
      const entries = JSON.parse(readFileSync(registryPath, "utf8")) as Array<{
        identifier: { id: string };
        metadata: { installedTimestamp: number; updated: boolean };
      }>;
      for (const entry of entries) {
        const matches =
          entry.identifier && entry.identifier.id.toLowerCase() === wanted;
        if (matches && entry.metadata && typeof entry.metadata.installedTimestamp === "number") {
          return {
            installedTimestamp: entry.metadata.installedTimestamp,
            updated: entry.metadata.updated === true,
          };
        }
      }
    } catch {
      // Missing or unreadable candidate: try the next one.
    }
  }
  return undefined;
}

// A fresh extraction bumps the folder mtime; a same-version reinstall that
// reuses the folder bumps only the registry timestamp. Take the newer.
function installMarker(
  context: vscode.ExtensionContext,
  registry: RegistryEntry | undefined,
): number {
  let folderMtime = 0;
  try {
    folderMtime = statSync(context.extensionPath).mtimeMs;
  } catch {
    // No local filesystem (for example the web): rely on the registry alone.
  }
  let installedTimestamp = 0;
  if (registry) {
    installedTimestamp = registry.installedTimestamp;
  }
  return Math.max(folderMtime, installedTimestamp);
}

// Starting the server interactively is what triggers the browser sign-in.
// Chat autostart deliberately suppresses prompts, so this is the one path
// that reliably brings the user through the sign-in flow. The start command
// returns nothing, so success is confirmed by the server's tools appearing.
async function signIn(): Promise<void> {
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: "Connecting to Valency…",
    },
    async () => {
      try {
        await vscode.commands.executeCommand(
          "workbench.mcp.startServer",
          SERVER_ID,
          { waitForLiveTools: true },
        );
      } catch {
        await vscode.commands.executeCommand("workbench.mcp.listServer");
      }
      await waitForValencyTools(3000);
    },
  );

  const toolCount = countValencyTools();
  if (toolCount > 0) {
    const openChat = "Open Chat";
    const choice = await vscode.window.showInformationMessage(
      `Valency is connected: ${toolCount} research tools are available to your agent.`,
      openChat,
    );
    if (choice === openChat) {
      await vscode.commands.executeCommand("workbench.action.chat.open");
    }
    return;
  }

  const showOutput = "Show Output";
  const choice = await vscode.window.showWarningMessage(
    "Valency did not finish connecting. Complete the sign-in if your browser is still open, or check the server output.",
    showOutput,
  );
  if (choice === showOutput) {
    await vscode.commands.executeCommand("workbench.mcp.showOutput", SERVER_ID);
  }
}

async function showFirstRun(): Promise<void> {
  const openWalkthrough = vscode.workspace
    .getConfiguration("workbench.welcomePage.walkthroughs")
    .get<boolean>("openOnInstall", true);
  if (openWalkthrough) {
    void openWalkthroughWhenRegistered();
  }

  const signInAction = "Sign in";
  const choice = await vscode.window.showInformationMessage(
    "Valency installed. Sign in to connect your agent to the research corpus.",
    signInAction,
  );
  if (choice === signInAction) {
    await signIn();
  }
}

// VS Code registers contributed walkthroughs asynchronously after startup, and
// opening ours before that lands on the generic Welcome list instead. Opening
// the sign-in step is idempotent (VS Code only reveals the step when the
// walkthrough is already showing), so the open is retried a few times over the
// window VS Code needs. Tab labels alone cannot confirm success, because the
// "Extension: Valency" details tab looks identical to "Walkthrough: Valency"
// through the API, so success is judged by what the open changed: a different
// Valency-labelled tab became active, or nothing changed because the
// walkthrough was already the active editor.
async function openWalkthroughWhenRegistered(): Promise<void> {
  const target = { category: WALKTHROUGH_ID, step: "valency.signIn" };
  const before = activeTabLabel();
  for (const wait of [0, 1500, 2000, 2500]) {
    await delay(wait);
    await vscode.commands.executeCommand(
      "workbench.action.openWalkthrough",
      target,
      false,
    );
    await delay(300);
    const after = activeTabLabel();
    const opened = after !== before && after.includes("Valency");
    const alreadyShowing = after === before && before.includes("Valency");
    log.info(`walkthrough open: before="${before}" after="${after}" opened=${opened} alreadyShowing=${alreadyShowing}`);
    if (opened || alreadyShowing) {
      return;
    }
  }
}

function activeTabLabel(): string {
  const tab = vscode.window.tabGroups.activeTabGroup.activeTab;
  if (!tab) {
    return "";
  }
  return tab.label;
}

function countValencyTools(): number {
  return vscode.lm.tools.filter(
    (tool) =>
      tool.name.startsWith("mcp_") && tool.name.toLowerCase().includes("valency"),
  ).length;
}

async function waitForValencyTools(timeoutMs: number): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (countValencyTools() === 0 && Date.now() < deadline) {
    await delay(250);
  }
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
