import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { test } from "node:test";

const readJson = (path) => JSON.parse(readFileSync(path, "utf8"));

const extensionRoot = "vscode";
const manifest = readJson(`${extensionRoot}/package.json`);
const extensionSource = readFileSync(`${extensionRoot}/src/extension.ts`, "utf8");

const expectedSkills = [
  "valency-fresh-collaborators",
  "valency-landscape",
  "valency-network",
  "valency-profile",
  "valency-reading-list",
  "valency-similar",
  "valency-trends",
];

// The union of every MCP tool the seven vendored skills reference — the
// complete surface the registered endpoint must expose. More than double the
// 8-tool /mcp/authoring allowlist, which is why the extension points at the
// full https://mcp.valency.io/ surface.
const pinnedTools = [
  "analyze_corpus_metrics",
  "batch_author_categories",
  "compare_authors",
  "find_coauthors",
  "find_similar_papers",
  "get_author_profile",
  "get_keyword_trends",
  "get_paper_by_id",
  "get_publication_trends",
  "get_publication_trends_batch",
  "identify_prolific_authors",
  "identify_research_domains",
  "search_by_abstract",
  "search_by_author",
  "search_by_category",
  "search_by_title",
  "semantic_search_papers",
];

// The Marketplace's fixed category enum (17 values; no AI or Chat category
// exists). https://code.visualstudio.com/api/references/extension-manifest
const marketplaceCategories = [
  "Programming Languages",
  "Snippets",
  "Linters",
  "Themes",
  "Debuggers",
  "Formatters",
  "Keymaps",
  "SCM Providers",
  "Other",
  "Extension Packs",
  "Language Packs",
  "Data Science",
  "Machine Learning",
  "Visualization",
  "Notebooks",
  "Education",
  "Testing",
];

test("extension identity matches the Marketplace plan", () => {
  assert.equal(manifest.name, "valency");
  assert.equal(manifest.displayName, "Valency");
  assert.equal(manifest.publisher, "valencyio");
  assert.equal(manifest.main, "./dist/extension.js");
  assert.match(manifest.version, /^\d+\.\d+\.\d+$/);
  assert.equal(
    manifest.galleryBanner,
    undefined,
    "no gallery banner: the cyan icon needs the default listing background",
  );
  assert.deepEqual(manifest.capabilities, {
    untrustedWorkspaces: { supported: true },
    virtualWorkspaces: true,
  });
});

test("the extension registers exactly one MCP definition provider", () => {
  assert.deepEqual(manifest.contributes.mcpServerDefinitionProviders, [
    { id: "valency.mcp", label: "Valency" },
  ]);
  assert.match(
    extensionSource,
    /registerMcpServerDefinitionProvider\("valency\.mcp"/,
  );
});

test("the MCP definition points at the bare hosted endpoint", () => {
  assert.match(
    extensionSource,
    /new vscode\.McpHttpServerDefinition\(\s*"Valency",\s*vscode\.Uri\.parse\("https:\/\/mcp\.valency\.io\/"\),?\s*\)/,
  );
  assert.doesNotMatch(
    extensionSource,
    /headers|bearer|secret|authorization|resolveMcpServerDefinition|[?]/i,
    "the definition must carry no headers, tokens, or query params",
  );
});

test("chatSkills contributes exactly the seven prefixed skill files", () => {
  assert.deepEqual(
    manifest.contributes.chatSkills,
    expectedSkills.map((skill) => ({ path: `./skills/${skill}/SKILL.md` })),
  );
  for (const { path } of manifest.contributes.chatSkills) {
    assert.match(path, /\/SKILL\.md$/);
    assert.equal(
      existsSync(`${extensionRoot}/${path.slice(2)}`),
      true,
      `${path} must exist inside ${extensionRoot}/`,
    );
  }
});

test("every vendored skill's frontmatter name equals its directory", () => {
  assert.deepEqual(
    readdirSync(`${extensionRoot}/skills`, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
      .sort(),
    expectedSkills,
  );

  for (const skill of expectedSkills) {
    const contents = readFileSync(
      `${extensionRoot}/skills/${skill}/SKILL.md`,
      "utf8",
    );
    const frontmatter = contents.match(/^---\n([\s\S]*?)\n---/);
    assert.ok(frontmatter, `${skill}/SKILL.md must start with YAML frontmatter`);
    assert.match(
      frontmatter[1],
      new RegExp(`^name: ${skill}$`, "m"),
      `${skill}/SKILL.md frontmatter name must equal its directory name`,
    );
  }
});

test("vendored skill directories contain only SKILL.md", () => {
  for (const skill of expectedSkills) {
    assert.deepEqual(
      readdirSync(`${extensionRoot}/skills/${skill}`),
      ["SKILL.md"],
      `${skill} must ship a single SKILL.md and nothing else`,
    );
  }
});

test("skills only call tools from the pinned Valency Bond surface", () => {
  const combined = expectedSkills
    .map((skill) =>
      readFileSync(`${extensionRoot}/skills/${skill}/SKILL.md`, "utf8"),
    )
    .join("\n");

  const calledTools = new Set(
    [...combined.matchAll(/Call `([a-z_]+)`/g)].map((match) => match[1]),
  );
  assert.ok(calledTools.size > 0, "skills must call at least one tool");
  for (const tool of calledTools) {
    assert.ok(
      pinnedTools.includes(tool),
      `${tool} is called by a skill but missing from the pinned tool fixture`,
    );
  }
  for (const tool of pinnedTools) {
    assert.ok(
      combined.includes(`\`${tool}\``),
      `${tool} is pinned but no vendored skill references it`,
    );
  }
});

test("Marketplace presentation obeys icon, category, and keyword rules", () => {
  const icon = readFileSync(`${extensionRoot}/${manifest.icon}`);
  assert.deepEqual(
    [...icon.subarray(0, 8)],
    [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    "the icon must be a PNG — the Marketplace rejects SVG icons",
  );
  assert.ok(icon.readUInt32BE(16) >= 128, "icon width must be >= 128px");
  assert.ok(icon.readUInt32BE(20) >= 128, "icon height must be >= 128px");

  for (const category of manifest.categories) {
    assert.ok(
      marketplaceCategories.includes(category),
      `${category} is not in the Marketplace's fixed category enum`,
    );
  }
  assert.ok(manifest.keywords.length <= 30, "the Marketplace caps keywords at 30");
});

test("the README uses only absolute, non-SVG images", () => {
  const readme = readFileSync(`${extensionRoot}/README.md`, "utf8");
  const sources = [
    ...[...readme.matchAll(/!\[[^\]]*\]\(([^)\s]+)[^)]*\)/g)].map((m) => m[1]),
    ...[...readme.matchAll(/<img[^>]*\ssrc="([^"]+)"/g)].map((m) => m[1]),
  ];
  for (const source of sources) {
    assert.match(
      source,
      /^https:\/\//,
      `${source} must be an absolute HTTPS URL — the Marketplace rewrites relative paths against the repo root`,
    );
    assert.doesNotMatch(
      source,
      /\.svg($|[?#])/i,
      `${source} must not be an SVG — the Marketplace rejects SVG images`,
    );
  }
});

test("the manifest pins a concrete VS Code engine range", () => {
  assert.match(manifest.engines.vscode, /^\^\d+\.\d+\.\d+$/);
  assert.equal(manifest.engines.vscode, "^1.109.0");
});

test("the walkthrough contributes three steps with packaged media", () => {
  assert.equal(manifest.contributes.walkthroughs.length, 1);
  const [walkthrough] = manifest.contributes.walkthroughs;
  assert.equal(walkthrough.id, "valency.gettingStarted");
  assert.equal(walkthrough.title, "Get started with Valency");
  assert.equal(walkthrough.steps.length, 3);
  for (const step of walkthrough.steps) {
    assert.equal(
      existsSync(`${extensionRoot}/${step.media.markdown}`),
      true,
      `${step.id} media must be packaged inside ${extensionRoot}/`,
    );
  }
});
