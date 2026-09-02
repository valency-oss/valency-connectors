import { statSync } from "fs";
import * as vscode from "vscode";

const WALKTHROUGH_ID = "valencyio.valency#valency.gettingStarted";
const INSTALL_KEY = "valency.install";

interface InstallRecord {
  version: string;
  installedAt: number;
}

// VS Code derives the server id from the extension id and the definition label.
const SERVER_ID = "valencyio.valency/Valency";

export async function activate(
  context: vscode.ExtensionContext,
): Promise<void> {
  context.subscriptions.push(
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

  // VS Code extracts a fresh directory on every install, so its mtime is an
  // install marker: reinstalls onboard again, while a version update on an
  // already-onboarded install stays quiet. Global state alone would not do,
  // because VS Code keeps it across uninstall and reinstall.
  const current: InstallRecord = {
    version: String(context.extension.packageJSON.version),
    installedAt: statSync(context.extensionPath).mtimeMs,
  };
  const previous = context.globalState.get<InstallRecord>(INSTALL_KEY);
  await context.globalState.update(INSTALL_KEY, current);
  if (shouldOnboard(previous, current)) {
    void showFirstRun();
  }
}

function shouldOnboard(
  previous: InstallRecord | undefined,
  current: InstallRecord,
): boolean {
  if (!previous) {
    return true;
  }
  if (previous.version !== current.version) {
    return false;
  }
  return previous.installedAt !== current.installedAt;
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

function countValencyTools(): number {
  return vscode.lm.tools.filter(
    (tool) =>
      tool.name.startsWith("mcp_") && tool.name.toLowerCase().includes("valency"),
  ).length;
}

async function waitForValencyTools(timeoutMs: number): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (countValencyTools() === 0 && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
}

async function showFirstRun(): Promise<void> {
  const openWalkthrough = vscode.workspace
    .getConfiguration("workbench.welcomePage.walkthroughs")
    .get<boolean>("openOnInstall", true);
  if (openWalkthrough) {
    await vscode.commands.executeCommand(
      "workbench.action.openWalkthrough",
      WALKTHROUGH_ID,
      false,
    );
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
