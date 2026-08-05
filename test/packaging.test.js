import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { test } from "node:test";

const readJson = (path) => JSON.parse(readFileSync(path, "utf8"));
const skillDirectories = (root) =>
  readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();

const claudeMarketplace = readJson(".claude-plugin/marketplace.json");
const claudePlugin = readJson("plugins/claude/valency/.claude-plugin/plugin.json");
const openaiMarketplace = readJson(".agents/plugins/marketplace.json");
const openaiPlugin = readJson("plugins/openai/valency/.codex-plugin/plugin.json");

test("root marketplaces route to independent provider packages", () => {
  const claudeEntry = claudeMarketplace.plugins.find(({ name }) => name === "valency");
  const openaiEntry = openaiMarketplace.plugins.find(({ name }) => name === "valency");

  assert.ok(claudeEntry, "Claude marketplace must list the valency plugin");
  assert.ok(openaiEntry, "OpenAI marketplace must list the valency plugin");
  assert.equal(claudeMarketplace.name, "valency-claude-plugin");
  assert.equal(claudeEntry.source, "./plugins/claude/valency");
  assert.equal(openaiMarketplace.name, "valency");
  assert.deepEqual(openaiEntry.source, {
    source: "local",
    path: "./plugins/openai/valency",
  });

  assert.equal(claudePlugin.name, "valency");
  assert.equal(claudePlugin.displayName, "Valency");
  assert.equal(openaiPlugin.name, "valency");
  assert.equal(openaiPlugin.interface.displayName, "Valency");

  assert.equal(claudePlugin.version, "0.3.0");
  assert.equal(claudeEntry.version, claudePlugin.version);
  assert.equal(openaiPlugin.version, "1.0.0");
});

test("both packages bundle the production Valency Bond MCP endpoint", () => {
  assert.equal(claudePlugin.mcpServers, "./.mcp.json");
  assert.equal(openaiPlugin.mcpServers, "./.mcp.json");

  const claudeMcp = readJson("plugins/claude/valency/.mcp.json");
  const openaiMcp = readJson("plugins/openai/valency/.mcp.json");

  assert.deepEqual(claudeMcp, {
    mcpServers: {
      valency: {
        type: "http",
        url: "https://labs.valency.io/mcp/",
        oauth: { callbackPort: 33418 },
      },
    },
  });
  assert.deepEqual(openaiMcp, {
    mcpServers: {
      valency: {
        type: "http",
        url: "https://labs.valency.io/mcp/",
      },
    },
  });
});

test("the OpenAI package preserves the production app mapping", () => {
  assert.equal(openaiPlugin.apps, "./.app.json");
  assert.deepEqual(readJson("plugins/openai/valency/.app.json"), {
    apps: {
      valency: {
        id: "plugin_asdk_app_6a691d5e51f08191acd4f3359d6348eb",
      },
    },
  });
});

test("each provider package contains its complete runtime payload", () => {
  assert.deepEqual(skillDirectories("plugins/claude/valency/skills"), [
    "fresh-collaborators",
    "landscape",
    "network",
    "profile",
    "reading-list",
    "similar",
    "trends",
  ]);
  assert.deepEqual(skillDirectories("plugins/openai/valency/skills"), [
    "valency-fresh-collaborators",
    "valency-landscape",
    "valency-network",
    "valency-profile",
    "valency-reading-list",
    "valency-similar",
    "valency-trends",
  ]);

  for (const path of [
    "plugins/claude/valency/LICENSE",
    "plugins/openai/valency/LICENSE",
    "plugins/openai/valency/assets/avatar_solid_black_valency.png",
    "plugins/openai/valency/assets/avatar_solid_white_valency.png",
    "plugins/openai/valency/assets/favicon_solid_cyan_valency.svg",
  ]) {
    assert.equal(existsSync(path), true, `${path} must be packaged`);
  }

  assert.equal(existsSync("plugins/claude/valency/hooks"), false);
  assert.equal(existsSync("plugins/claude/valency/CLAUDE.md"), false);
});

test("repository metadata and installation docs point at the monorepo", () => {
  assert.equal(
    claudePlugin.repository,
    "https://github.com/valency-oss/valency-bond",
  );
  assert.equal(
    openaiPlugin.repository,
    "https://github.com/valency-oss/valency-bond",
  );

  const readme = readFileSync("README.md", "utf8");
  assert.match(
    readme,
    /claude plugin marketplace add valency-oss\/valency-bond --scope user/,
  );
  assert.match(readme, /claude plugin install valency@valency-claude-plugin --scope user/);
  assert.match(readme, /codex plugin marketplace add valency-oss\/valency-bond/);
  assert.match(readme, /codex plugin add valency@valency/);
  assert.match(readme, /ChatGPT web/);
  assert.match(readme, /Valency Bond MCP server/);
  assert.doesNotMatch(readme, /claude mcp add/);
});
