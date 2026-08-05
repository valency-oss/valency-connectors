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

test("Copilot marketplace routes to its independent provider package", () => {
  assert.deepEqual(readJson(".github/plugin/marketplace.json"), {
    name: "valency-copilot-plugin",
    owner: {
      name: "Valency Systems Inc",
    },
    metadata: {
      description:
        "The Valency research plugin marketplace for GitHub Copilot CLI, powered by Valency Bond.",
      version: "1.0.0",
    },
    plugins: [
      {
        name: "valency",
        source: "./plugins/copilot/valency",
        description:
          "Search, profile, and analyze research papers through Valency Bond.",
        version: "0.1.0",
      },
    ],
  });

  assert.deepEqual(readJson("plugins/copilot/valency/plugin.json"), {
    name: "valency",
    description:
      "Search, profile, and analyze research papers through the Valency Bond MCP server.",
    version: "0.1.0",
    author: {
      name: "Valency Systems Inc",
      email: "support@valency.io",
      url: "https://valency.io",
    },
    homepage: "https://valency.io",
    repository: "https://github.com/valency-oss/valency-bond",
    license: "MIT",
    keywords: [
      "research",
      "papers",
      "literature-review",
      "semantic-search",
    ],
    skills: "skills/",
    mcpServers: ".mcp.json",
  });
});

test("Copilot package enables the complete Valency Bond tool surface", () => {
  assert.deepEqual(readJson("plugins/copilot/valency/.mcp.json"), {
    mcpServers: {
      valency: {
        type: "http",
        url: "https://labs.valency.io/mcp/",
        tools: ["*"],
      },
    },
  });

  assert.doesNotMatch(
    readFileSync("plugins/copilot/valency/.mcp.json", "utf8"),
    /oauthClientId|clientSecret|bearer|authorization/i,
  );
});

test("repository root is an installable Gemini extension", () => {
  assert.deepEqual(readJson("gemini-extension.json"), {
    name: "valency",
    version: "1.1.0",
    description:
      "Search, profile, and analyze research papers through the Valency Bond MCP server.",
    mcpServers: {
      valency: {
        httpUrl: "https://labs.valency.io/mcp/",
        authProviderType: "dynamic_discovery",
        oauth: {
          enabled: true,
          redirectUri: "http://localhost:33418/oauth/callback",
        },
      },
    },
    contextFileName: "GEMINI.md",
  });

  assert.doesNotMatch(
    readFileSync("gemini-extension.json", "utf8"),
    /clientId|clientSecret/,
  );
});

test("Gemini extension bundles seven skills, seven commands, and context", () => {
  assert.deepEqual(skillDirectories("skills"), [
    "fresh-collaborators",
    "landscape",
    "network",
    "profile",
    "reading-list",
    "similar",
    "trends",
  ]);
  assert.deepEqual(
    readdirSync("commands/valency")
      .filter((name) => name.endsWith(".toml"))
      .sort(),
    [
      "fresh-collaborators.toml",
      "landscape.toml",
      "network.toml",
      "profile.toml",
      "reading-list.toml",
      "similar.toml",
      "trends.toml",
    ],
  );
  assert.equal(existsSync("GEMINI.md"), true);
});

test("Gemini commands route arguments to the matching shared skill", () => {
  for (const skill of [
    "fresh-collaborators",
    "landscape",
    "network",
    "profile",
    "reading-list",
    "similar",
    "trends",
  ]) {
    const command = readFileSync(`commands/valency/${skill}.toml`, "utf8");
    assert.match(command, new RegExp("Activate the `" + skill + "` skill"));
    assert.match(command, /\{\{args\}\}/);
    assert.match(command, /Valency MCP tools loaded by this extension/);
    assert.doesNotMatch(command, /companion extension|install .*connector/i);
  }
});

test("all providers ship byte-identical unprefixed skills", () => {
  for (const skill of [
    "fresh-collaborators",
    "landscape",
    "network",
    "profile",
    "reading-list",
    "similar",
    "trends",
  ]) {
    const canonical = readFileSync(`skills/${skill}/SKILL.md`, "utf8");
    assert.equal(
      readFileSync(
        `plugins/claude/valency/skills/${skill}/SKILL.md`,
        "utf8",
      ),
      canonical,
      `Claude ${skill} must match the shared skill`,
    );
    assert.equal(
      readFileSync(
        `plugins/openai/valency/skills/${skill}/SKILL.md`,
        "utf8",
      ),
      canonical,
      `OpenAI ${skill} must match the shared skill`,
    );
    assert.equal(
      readFileSync(
        `plugins/copilot/valency/skills/${skill}/SKILL.md`,
        "utf8",
      ),
      canonical,
      `Copilot ${skill} must match the shared skill`,
    );
  }
});

test("shared skills contain only provider-neutral invocation guidance", () => {
  for (const skill of [
    "fresh-collaborators",
    "landscape",
    "network",
    "profile",
    "reading-list",
    "similar",
    "trends",
  ]) {
    const contents = readFileSync(`skills/${skill}/SKILL.md`, "utf8");
    assert.match(contents, new RegExp(`^name: ${skill}$`, "m"));
    assert.match(
      contents,
      /Use the Valency Bond MCP tools available in the current host\./,
    );
    assert.match(
      contents,
      /If the\s+required Valency Bond tools are unavailable, say so and stop\./,
    );
    assert.doesNotMatch(
      contents,
      /mcp__|companion Valency connector|install the connector|\/valency:/,
    );
  }
});

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
    "fresh-collaborators",
    "landscape",
    "network",
    "profile",
    "reading-list",
    "similar",
    "trends",
  ]);
  assert.deepEqual(skillDirectories("plugins/copilot/valency/skills"), [
    "fresh-collaborators",
    "landscape",
    "network",
    "profile",
    "reading-list",
    "similar",
    "trends",
  ]);

  for (const path of [
    "plugins/claude/valency/LICENSE",
    "plugins/openai/valency/LICENSE",
    "plugins/copilot/valency/LICENSE",
    "plugins/openai/valency/assets/avatar_solid_black_valency.png",
    "plugins/openai/valency/assets/avatar_solid_white_valency.png",
    "plugins/openai/valency/assets/favicon_solid_cyan_valency.svg",
  ]) {
    assert.equal(existsSync(path), true, `${path} must be packaged`);
  }

  assert.equal(existsSync("plugins/claude/valency/hooks"), false);
  assert.equal(existsSync("plugins/claude/valency/CLAUDE.md"), false);
});

test("renamed OpenAI skills preserve their provider-specific metadata", () => {
  for (const skill of [
    "fresh-collaborators",
    "landscape",
    "network",
    "profile",
    "reading-list",
    "similar",
    "trends",
  ]) {
    assert.equal(
      existsSync(`plugins/openai/valency/skills/${skill}/agents/openai.yaml`),
      true,
    );
    assert.equal(
      existsSync(
        `plugins/openai/valency/skills/${skill}/assets/favicon_solid_cyan_valency.svg`,
      ),
      true,
    );
  }
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
  const development = readFileSync("docs/development.md", "utf8");
  assert.match(readme, /^# Valency Bond$/m);
  assert.match(
    readme,
    /claude plugin marketplace add valency-oss\/valency-bond --scope user/,
  );
  assert.match(readme, /claude plugin install valency@valency-claude-plugin --scope user/);
  assert.match(readme, /codex plugin marketplace add valency-oss\/valency-bond/);
  assert.match(readme, /codex plugin add valency@valency/);
  assert.match(
    readme,
    /gemini extensions install https:\/\/github\.com\/valency-oss\/valency-bond --auto-update/,
  );
  assert.match(readme, /\/mcp auth valency/);
  assert.match(readme, /gemini extensions update valency/);
  assert.match(readme, /gemini extensions uninstall valency/);
  assert.match(readme, /ChatGPT web/);
  assert.match(readme, /Valency Bond MCP server/);
  assert.match(readme, /\.\/docs\/development\.md/);
  assert.doesNotMatch(readme, /valency-gemini/);
  assert.doesNotMatch(readme, /^## Permissions$/m);
  assert.doesNotMatch(readme, /^## Development and validation$/m);
  assert.doesNotMatch(readme, /claude mcp add/);
  assert.match(development, /^# Development and validation$/m);
  assert.match(development, /npm test/);
  assert.match(development, /npm run validate:claude/);
  assert.match(development, /npm run validate:openai/);
  assert.match(development, /gemini-extension\.json/);
  assert.match(development, /static checks for the Gemini extension/);
});

test("Copilot documentation uses marketplace-first CLI-only support", () => {
  const readme = readFileSync("README.md", "utf8");
  const development = readFileSync("docs/development.md", "utf8");

  assert.match(
    readme,
    /copilot plugin marketplace add valency-oss\/valency-bond/,
  );
  assert.match(
    readme,
    /copilot plugin install valency@valency-copilot-plugin/,
  );
  assert.match(readme, /\/mcp auth valency/);
  assert.match(readme, /GitHub Copilot CLI/);
  assert.match(readme, /Copilot coding agent/);
  assert.match(readme, /Copilot code review/);
  assert.doesNotMatch(
    readme,
    /copilot plugin install (?:valency-oss\/valency-bond|https:\/\/github\.com\/valency-oss\/valency-bond(?:\.git)?)/,
  );

  assert.match(development, /Copilot\s+marketplace and provider package/);
  assert.match(
    development,
    /do not prove that GitHub\s+Copilot CLI can install the plugin, complete OAuth, or invoke a remote tool/,
  );
});
