import * as vscode from "vscode";

export function activate(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.lm.registerMcpServerDefinitionProvider("valency.mcp", {
      provideMcpServerDefinitions: () => [
        new vscode.McpHttpServerDefinition(
          "Valency",
          vscode.Uri.parse("https://mcp.valency.io/"),
        ),
      ],
    }),
  );
}
