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
const cursorMarketplace = readJson(".cursor-plugin/marketplace.json");
const cursorPlugin = readJson("plugins/cursor/valency/.cursor-plugin/plugin.json");
const openaiMarketplace = readJson(".agents/plugins/marketplace.json");
const openaiPlugin = readJson("plugins/openai/valency/.codex-plugin/plugin.json");
const kiroPowerRoot = ".";
const kiroWorkflows = [
  "profile",
  "landscape",
  "similar",
  "trends",
  "network",
  "reading-list",
  "fresh-collaborators",
];

test("Agent Skills CLI groups every canonical skill under one select-all row", () => {
  assert.deepEqual(readJson(".claude-plugin/plugin.json"), {
    name: "valency-skills",
    version: "0.1.0",
    description:
      "Portable research-corpus workflows for agents using the Valency Bond MCP server.",
    author: {
      name: "Valency Systems Inc",
    },
    homepage: "https://valency.io",
    repository: "https://github.com/valency-oss/valency-bond",
    license: "MIT",
    skills: [
      "./skills/fresh-collaborators",
      "./skills/landscape",
      "./skills/network",
      "./skills/profile",
      "./skills/reading-list",
      "./skills/similar",
      "./skills/trends",
    ],
  });
});

test("repository root is an installable Antigravity plugin", () => {
  assert.deepEqual(readJson("plugin.json"), {
    name: "valency",
    description:
      "Search, profile, and analyze research papers through the Valency Bond MCP server.",
  });

  assert.deepEqual(readJson("mcp_config.json"), {
    mcpServers: {
      valency: {
        serverUrl: "https://labs.valency.io/mcp/",
      },
    },
  });

  assert.doesNotMatch(
    readFileSync("mcp_config.json", "utf8"),
    /authProviderType|oauth|redirectUri|33418|clientId|clientSecret|bearer|authorization/i,
  );
});

test("Antigravity reuses the root skills and adds host-specific guidance", () => {
  assert.deepEqual(skillDirectories("skills"), [
    "fresh-collaborators",
    "landscape",
    "network",
    "profile",
    "reading-list",
    "similar",
    "trends",
  ]);
  assert.equal(existsSync("gemini-extension.json"), true);
  assert.equal(existsSync("GEMINI.md"), true);
  assert.equal(existsSync("rules/valency.md"), true);

  const rule = readFileSync("rules/valency.md", "utf8");
  assert.match(rule, /Valency Bond/);
  assert.match(rule, /interactive `\/mcp` manager/);
  assert.match(rule, /skill-derived slash commands/);
  assert.doesNotMatch(rule, /Gemini|33418|\/mcp auth valency|\/valency:/i);
});

test("Grok marketplace routes to its dedicated provider package", () => {
  assert.deepEqual(readJson(".grok-plugin/marketplace.json"), {
    name: "valency",
    owner: {
      name: "Valency Systems Inc",
      email: "support@valency.io",
    },
    plugins: [
      {
        name: "valency",
        source: "./plugins/grok/valency",
        description:
          "Search, profile, and analyze research papers through Valency Bond.",
        version: "0.1.0",
        author: {
          name: "Valency Systems Inc",
        },
      },
    ],
  });
});

test("native Grok package is credential-free and contains only expected components", () => {
  const packageRoot = "plugins/grok/valency";
  const manifestPath = `${packageRoot}/.grok-plugin/plugin.json`;
  const mcpPath = `${packageRoot}/.mcp.json`;

  assert.deepEqual(readJson(manifestPath), {
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
      "valency",
      "research",
      "papers",
      "literature-review",
      "semantic-search",
      "grok",
      "grok-build",
    ],
  });

  assert.deepEqual(readJson(mcpPath), {
    mcpServers: {
      valency: {
        type: "http",
        url: "https://labs.valency.io/mcp/",
      },
    },
  });
  assert.doesNotMatch(
    readFileSync(mcpPath, "utf8"),
    /command|args|env|oauth|clientId|clientSecret|redirectUri|bearer|token|headers|authorization/i,
  );

  assert.deepEqual(readdirSync(packageRoot).sort(), [
    ".grok-plugin",
    ".mcp.json",
    "LICENSE",
    "skills",
  ]);
  assert.deepEqual(readdirSync(`${packageRoot}/.grok-plugin`).sort(), [
    "plugin.json",
  ]);
  for (const component of ["agents", "commands", "hooks", ".lsp.json"]) {
    assert.equal(
      existsSync(`${packageRoot}/${component}`),
      false,
      `${component} must not be packaged for Grok`,
    );
  }
});

test("repository root is a native Valency Power with host-managed OAuth", () => {
  assert.equal(existsSync("plugins/kiro/valency"), false);
  const power = readFileSync(`${kiroPowerRoot}/POWER.md`, "utf8");
  const frontmatter = power.match(/^---\n([\s\S]*?)\n---/);

  assert.ok(frontmatter, "Kiro POWER.md must start with YAML frontmatter");
  assert.deepEqual(
    frontmatter[1]
      .split("\n")
      .map((line) => line.match(/^([A-Za-z][A-Za-z0-9]*):/)?.[1])
      .filter(Boolean),
    ["name", "displayName", "description", "keywords", "author"],
  );
  assert.match(frontmatter[1], /^name: "valency"$/m);
  assert.match(frontmatter[1], /^displayName: "Valency"$/m);
  assert.match(frontmatter[1], /^author: "Valency Systems Inc"$/m);
  assert.match(power, /^# Valency$/m);
  assert.match(power, /Valency Bond MCP server/);
  assert.match(power, /MCP server named `valency`/);
  assert.match(power, /dynamic client registration \(DCR\)/);
  assert.match(power, /Kiro's `readSteering` action/);
  assert.match(power, /Power license: \[MIT\]/);
  assert.match(power, /Valency Bond MCP server license: Proprietary/);
  assert.match(power, /https:\/\/www\.valency\.io\/privacy/);
  assert.match(power, /mailto:support@valency\.io/);

  assert.deepEqual(readJson(`${kiroPowerRoot}/mcp.json`), {
    mcpServers: {
      valency: {
        url: "https://labs.valency.io/mcp/",
      },
    },
  });
  assert.doesNotMatch(
    readFileSync(`${kiroPowerRoot}/mcp.json`, "utf8"),
    /auth|oauth|clientId|clientSecret|redirectUri|bearer|token|headers|autoApprove/i,
  );
});

test("Kiro routes all seven workflows to byte-identical canonical guidance", () => {
  const power = readFileSync(`${kiroPowerRoot}/POWER.md`, "utf8");
  const mappings = [...power.matchAll(
    /^- `([^`]+)` — .+ → `steering\/([^`]+)\.md`$/gm,
  )].map((match) => [match[1], match[2]]);

  assert.deepEqual(
    mappings,
    kiroWorkflows.map((workflow) => [workflow, workflow]),
  );
  assert.deepEqual(
    readdirSync(`${kiroPowerRoot}/steering`)
      .filter((name) => name.endsWith(".md"))
      .sort(),
    kiroWorkflows.map((workflow) => `${workflow}.md`).sort(),
  );

  for (const workflow of kiroWorkflows) {
    assert.equal(
      readFileSync(`${kiroPowerRoot}/steering/${workflow}.md`, "utf8"),
      readFileSync(`skills/${workflow}/SKILL.md`, "utf8"),
      `Kiro ${workflow} guidance must match the canonical skill`,
    );
  }
});

test("Copilot marketplace routes to its independent provider package", () => {
  assert.deepEqual(readJson(".github/plugin/marketplace.json"), {
    name: "valency-copilot-plugin",
    owner: {
      name: "Valency Systems Inc",
    },
    metadata: {
      description:
        "The Valency research plugin marketplace for GitHub Copilot CLI, powered by Valency Bond.",
      version: "0.1.0",
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

test("Cursor marketplace routes to its full-surface provider package", () => {
  assert.deepEqual(cursorMarketplace, {
    name: "valency-cursor-plugin",
    owner: {
      name: "Valency Systems Inc",
      email: "support@valency.io",
    },
    metadata: {
      description:
        "The Valency research plugin marketplace for Cursor, powered by Valency Bond.",
    },
    plugins: [
      {
        name: "valency",
        source: "./plugins/cursor/valency",
        description:
          "Search, profile, and analyze research papers through Valency Bond.",
      },
    ],
  });

  assert.deepEqual(cursorPlugin, {
    name: "valency",
    displayName: "Valency",
    description:
      "Search, profile, and analyze research papers through the Valency Bond MCP server.",
    version: "0.1.0",
    author: {
      name: "Valency Systems Inc",
      email: "support@valency.io",
    },
    publisher: "Valency Systems Inc",
    homepage: "https://valency.io",
    repository: "https://github.com/valency-oss/valency-bond",
    license: "MIT",
    keywords: [
      "research",
      "papers",
      "literature-review",
      "semantic-search",
    ],
    skills: "./skills/",
    rules: "./rules/",
    mcpServers: "./mcp.json",
  });
});

test("Cursor package exposes only the complete Valency Bond MCP surface", () => {
  assert.deepEqual(readJson("plugins/cursor/valency/mcp.json"), {
    mcpServers: {
      valency: {
        type: "http",
        url: "https://labs.valency.io/mcp/",
      },
    },
  });

  const mcpContents = readFileSync("plugins/cursor/valency/mcp.json", "utf8");
  const packageContents = [
    mcpContents,
    readFileSync("plugins/cursor/valency/.cursor-plugin/plugin.json", "utf8"),
    readFileSync("plugins/cursor/valency/rules/valency-bond.mdc", "utf8"),
  ].join("\n");
  assert.doesNotMatch(
    packageContents,
    /\/mcp\/authoring|valency-authoring/i,
  );
  assert.doesNotMatch(
    mcpContents,
    /"oauth"|"clientId"|"clientSecret"|"bearer"|"authorization"/i,
  );
  assert.equal(existsSync("plugins/cursor/valency/hooks"), false);
  assert.equal(existsSync("plugins/cursor/valency/commands"), false);
  assert.equal(existsSync("plugins/cursor/valency/agents"), false);
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
  assert.deepEqual(skillDirectories("plugins/grok/valency/skills"), [
    "fresh-collaborators",
    "landscape",
    "network",
    "profile",
    "reading-list",
    "similar",
    "trends",
  ]);
  assert.equal(
    readFileSync("plugins/grok/valency/LICENSE", "utf8"),
    readFileSync("LICENSE", "utf8"),
    "Grok package license must match the repository MIT license",
  );

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
    assert.equal(
      readFileSync(
        `plugins/cursor/valency/skills/${skill}/SKILL.md`,
        "utf8",
      ),
      canonical,
      `Cursor ${skill} must match the shared skill`,
    );
    assert.equal(
      readFileSync(
        `plugins/grok/valency/skills/${skill}/SKILL.md`,
        "utf8",
      ),
      canonical,
      `Grok ${skill} must match the shared skill`,
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
  assert.deepEqual(skillDirectories("plugins/cursor/valency/skills"), [
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
    "plugins/cursor/valency/LICENSE",
    "plugins/cursor/valency/rules/valency-bond.mdc",
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
  assert.equal(
    cursorPlugin.repository,
    "https://github.com/valency-oss/valency-bond",
  );

  const readme = readFileSync("README.md", "utf8");
  const development = readFileSync("docs/development.md", "utf8");
  const uninstall = readFileSync("docs/uninstall.md", "utf8");
  assert.match(readme, /^# Valency Bond$/m);
  assert.match(readme, /\.\/docs\/assets\/horizontal_solid_cyan_valency\.svg/);
  assert.equal(
    existsSync("docs/assets/horizontal_solid_cyan_valency.svg"),
    true,
  );
  for (const surface of [
    "Claude Code",
    "Codex",
    "ChatGPT",
    "Cursor",
    "Gemini CLI",
    "GitHub Copilot CLI",
    "Antigravity CLI",
    "Grok Build",
    "Kiro",
    "Skills-only installation",
  ]) {
    assert.match(readme, new RegExp(`^### ${surface}$`, "m"));
  }
  assert.match(
    readme,
    /claude plugin marketplace add valency-oss\/valency-bond --scope user/,
  );
  assert.match(readme, /claude plugin install valency@valency-claude-plugin --scope user/);
  assert.match(readme, /codex plugin marketplace add valency-oss\/valency-bond/);
  assert.match(readme, /codex plugin add valency@valency/);
  assert.match(
    readme,
    /cursor-agent plugin marketplace add https:\/\/github\.com\/valency-oss\/valency-bond/,
  );
  assert.doesNotMatch(readme, /mcp\/authoring|valency-authoring/);
  assert.match(
    readme,
    /npx skills@latest add valency-oss\/valency-bond(?=\s|`|$)/,
  );
  assert.match(readme, /Toggle \*\*Valency Skills\*\* to select or clear all seven/);
  assert.match(readme, /does not configure or authenticate the MCP server/);
  assert.match(
    readme,
    /gemini extensions install https:\/\/github\.com\/valency-oss\/valency-bond --auto-update/,
  );
  assert.match(readme, /\/mcp auth valency/);
  assert.match(readme, /ChatGPT web/);
  assert.match(readme, /Valency Bond MCP server/);
  assert.match(readme, /\.\/docs\/uninstall\.md/);
  assert.match(readme, /\.\/docs\/development\.md/);
  assert.doesNotMatch(readme, /valency-gemini/);
  assert.doesNotMatch(readme, /^## Permissions$/m);
  assert.doesNotMatch(readme, /^## Development and validation$/m);
  assert.doesNotMatch(readme, /claude mcp add/);
  assert.match(development, /^# Development and validation$/m);
  assert.match(development, /npm test/);
  assert.match(development, /npm run validate:claude/);
  assert.match(development, /npm run validate:openai/);
  assert.match(development, /Cursor provider package/);
  assert.match(development, /plugins\/cursor\/valency/);
  assert.match(development, /gemini-extension\.json/);
  assert.match(
    development,
    /static checks for the native Antigravity plugin, the Gemini\s+extension/,
  );
  assert.match(uninstall, /^# Uninstall Valency Bond$/m);
});

test("Kiro documentation uses the supported root GitHub lifecycle", () => {
  const readme = readFileSync("README.md", "utf8");
  const development = readFileSync("docs/development.md", "utf8");
  const uninstall = readFileSync("docs/uninstall.md", "utf8");
  const kiroSection = readme.match(
    /^### Kiro$([\s\S]*?)(?=^### |^## )/m,
  )?.[1];

  assert.ok(kiroSection, "README must contain a Kiro install section");
  assert.match(kiroSection, /Powers/);
  assert.match(kiroSection, /Add Custom Power/);
  assert.match(kiroSection, /Import power from\s+GitHub/);
  assert.match(kiroSection, /https:\/\/github\.com\/valency-oss\/valency-bond/);
  assert.doesNotMatch(kiroSection, /plugins\/kiro\/valency/);
  assert.match(uninstall, /^## Kiro$/m);
  assert.match(uninstall, /Powers → Installed Powers → Valency/);

  assert.match(development, /Kiro Power/);
  assert.match(development, /`POWER\.md` frontmatter/);
  assert.match(development, /endpoint in `mcp\.json`/);
  assert.match(development, /seven\s+workflows to `steering\/\*\.md`/);
  assert.match(development, /byte-for-byte skill\s+synchronization/);
  assert.match(
    development,
    /do not\s+prove\s+that Kiro can\s+install the Power,\s+complete OAuth, or invoke a remote tool/,
  );
  assert.match(development, /Import power from\s+GitHub/);
  assert.match(development, /select the repository root/);
  assert.match(development, /dynamic client registration/);
});

test("uninstall instructions live in the linked guide", () => {
  const readme = readFileSync("README.md", "utf8");
  const uninstall = readFileSync("docs/uninstall.md", "utf8");

  assert.match(readme, /\[Uninstall Valency Bond\]\(\.\/docs\/uninstall\.md\)/);
  assert.doesNotMatch(readme, /^### (?:Update or |Disable, enable, or )?Uninstall/m);

  for (const surface of [
    "Claude Code",
    "Codex",
    "ChatGPT",
    "Cursor",
    "Gemini CLI",
    "GitHub Copilot CLI",
    "Antigravity CLI",
    "Grok Build",
    "Kiro",
    "Skills-only installation",
  ]) {
    assert.match(uninstall, new RegExp(`^## ${surface}$`, "m"));
  }

  for (const command of [
    "claude plugin uninstall valency@valency-claude-plugin --scope user",
    "codex plugin remove valency@valency",
    "gemini extensions uninstall valency",
    "copilot plugin uninstall valency",
    "agy plugin uninstall valency",
    "grok plugin uninstall valency",
    "npx skills@latest remove",
  ]) {
    assert.ok(uninstall.includes(command), `${command} must be documented`);
  }

  assert.match(
    uninstall,
    /This repository is registered as `valency`.*source `valency-oss\/valency-bond`/s,
  );
  assert.match(
    uninstall,
    /`valency-copilot-plugin` is the marketplace name declared by this repository/,
  );
});

test("repository layout guide explains every intentional root entry", () => {
  const readme = readFileSync("README.md", "utf8");
  const layout = readFileSync("docs/repository-layout.md", "utf8");

  assert.match(readme, /\.\/docs\/repository-layout\.md/);
  assert.match(layout, /^# Repository root layout$/m);
  assert.match(layout, /multiple providers require root-level\s+entry points/);
  assert.match(layout, /Do not consolidate similarly named files/);
  assert.match(
    layout,
    /Agent Skills CLI reuses Claude's plugin-manifest convention/,
  );
  assert.match(layout, /That group works when the selected destination is Codex/);
  assert.match(
    layout,
    /the root grouping manifest does not replace, rename, or enter the normal Claude\s+marketplace package/,
  );

  for (const entry of [
    ".agents/",
    ".claude-plugin/marketplace.json",
    ".claude-plugin/plugin.json",
    ".cursor-plugin/",
    ".github/",
    "commands/",
    "docs/",
    "plugins/",
    "rules/",
    "scripts/",
    "skills/",
    "steering/",
    "test/",
    "GEMINI.md",
    "LICENSE",
    "POWER.md",
    "README.md",
    "gemini-extension.json",
    "mcp.json",
    "mcp_config.json",
    "package.json",
    "plugin.json",
  ]) {
    assert.ok(layout.includes(`\`${entry}\``), `${entry} must be documented`);
  }
});

test("Antigravity and Gemini documentation keep separate lifecycle contracts", () => {
  const readme = readFileSync("README.md", "utf8");
  const development = readFileSync("docs/development.md", "utf8");
  const uninstall = readFileSync("docs/uninstall.md", "utf8");
  const antigravitySection = readme.match(
    /^### Antigravity CLI$([\s\S]*?)(?=^### |^## )/m,
  )?.[1];

  assert.ok(antigravitySection, "README must contain an Antigravity install section");
  assert.match(
    antigravitySection,
    /agy plugin install https:\/\/github\.com\/valency-oss\/valency-bond/,
  );
  assert.match(antigravitySection, /agy plugin list/);
  assert.match(antigravitySection, /`\/mcp` manager/);
  assert.match(uninstall, /agy plugin uninstall valency/);
  assert.doesNotMatch(
    antigravitySection,
    /--auto-update|gemini extensions|\/mcp auth valency|33418|agy plugin update/i,
  );

  assert.match(development, /native Antigravity plugin/);
  assert.match(development, /`plugin\.json`\s+and\s+`mcp_config\.json`/);
  assert.match(development, /agy --version/);
  assert.match(
    development,
    /do not prove that Antigravity CLI can\s+install the plugin, complete OAuth, or invoke a remote tool/,
  );
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

  assert.match(
    development,
    /Copilot, Cursor, and Grok marketplaces and provider packages/,
  );
  assert.match(
    development,
    /do not prove that GitHub\s+Copilot CLI can install its\s+plugin, complete OAuth, or invoke a remote tool/,
  );
});

test("Cursor documentation keeps installation interactive and profile-free", () => {
  const readme = readFileSync("README.md", "utf8");
  const development = readFileSync("docs/development.md", "utf8");
  const uninstall = readFileSync("docs/uninstall.md", "utf8");
  const cursorSection = readme.match(
    /^### Cursor$([\s\S]*?)(?=^### |^## )/m,
  )?.[1];

  assert.ok(cursorSection, "README must contain a Cursor install section");
  assert.match(
    cursorSection,
    /cursor-agent plugin marketplace add https:\/\/github\.com\/valency-oss\/valency-bond/,
  );
  assert.match(cursorSection, /`\/plugin`/);
  assert.match(cursorSection, /Marketplace\*\* tab/);
  assert.match(cursorSection, /Cursor-managed authentication/);
  assert.match(cursorSection, /Customize/);
  assert.match(uninstall, /^## Cursor$/m);
  assert.match(uninstall, /disable or uninstall \*\*Valency\*\*/);
  assert.doesNotMatch(
    cursorSection,
    /mcp\/authoring|valency-authoring|authoring profile|install\.sh/i,
  );

  assert.match(development, /Cursor provider package/);
  assert.match(development, /official Cursor schemas/);
  assert.match(development, /npm test/);
  assert.match(
    development,
    /Cursor package checks do not\s+prove\s+that Cursor can\s+install the plugin,\s+complete OAuth, or invoke a remote\s+tool/,
  );
});

test("Grok documentation uses the private marketplace lifecycle", () => {
  const readme = readFileSync("README.md", "utf8");
  const development = readFileSync("docs/development.md", "utf8");
  const layout = readFileSync("docs/repository-layout.md", "utf8");
  const uninstall = readFileSync("docs/uninstall.md", "utf8");
  const grokSection = readme.match(
    /^### Grok Build$([\s\S]*?)(?=^### |^## |(?![\s\S]))/m,
  )?.[1];

  assert.ok(grokSection, "README must contain a Grok Build install section");
  assert.match(
    grokSection,
    /grok plugin marketplace add valency-oss\/valency-bond/,
  );
  assert.match(grokSection, /grok plugin install valency --trust/);
  assert.match(readme, /repository is private/i);
  assert.match(readme, /GitHub credentials\s+> with access/i);
  assert.match(grokSection, /`\/mcps`/);
  assert.match(uninstall, /grok plugin uninstall valency/);
  assert.match(
    uninstall,
    /grok plugin marketplace remove https:\/\/github\.com\/valency-oss\/valency-bond\.git/,
  );
  assert.doesNotMatch(
    grokSection,
    /grok plugin install [^\n]*plugins\/grok\/valency/,
  );

  assert.match(development, /grok plugin validate plugins\/grok\/valency/);
  assert.match(
    development,
    /does not\s+prove that Grok Build can install the plugin,\s+complete OAuth, or invoke a\s+remote tool/,
  );
  assert.match(layout, /`\.grok-plugin\/` \| Grok Build/);
  assert.match(layout, /`plugins\/grok\/valency`/);
});
