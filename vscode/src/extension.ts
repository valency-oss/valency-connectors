import * as vscode from "vscode";

const WALKTHROUGH_ID = "valencyio.valency#valency.gettingStarted";
const ONBOARDED_KEY = "valency.onboarded";

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

  if (!context.globalState.get<boolean>(ONBOARDED_KEY)) {
    await context.globalState.update(ONBOARDED_KEY, true);
    void showFirstRun();
  }
}

// Starting the server interactively is what triggers the browser sign-in.
// Chat autostart deliberately suppresses prompts, so this is the one path
// that reliably brings the user through the sign-in flow.
async function signIn(): Promise<void> {
  try {
    await vscode.commands.executeCommand(
      "workbench.mcp.startServer",
      SERVER_ID,
    );
  } catch {
    await vscode.commands.executeCommand("workbench.mcp.listServer");
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
