// Copies the canonical skills in skills/ to every provider that needs its own
// copy. Edit skills/<name>/SKILL.md only, then run `npm run sync:skills`.
//
//   node scripts/sync-skills.mjs           write the committed provider copies
//   node scripts/sync-skills.mjs --check   fail if a committed copy has drifted
//   node scripts/sync-skills.mjs --vscode  write the VS Code build copies only
//
// The VS Code copies (vscode/skills/valency-<name>/) are build output: VS Code
// requires each folder name to match the skill's `name`, so they carry a
// `valency-` prefix the shared skills don't. They are gitignored and written
// by the extension's prepublish step.
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

export const providers = ["claude", "copilot", "cursor", "grok", "openai"];

export const skillNames = () =>
  readdirSync(join(root, "skills"), { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();

export const canonicalSkill = (name) =>
  readFileSync(join(root, "skills", name, "SKILL.md"), "utf8");

export const vscodeSkill = (name, contents) => {
  const frontmatter = contents.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n/);
  if (!frontmatter || !/^name: .+$/m.test(frontmatter[0])) {
    throw new Error(`skills/${name}/SKILL.md has no name: line in its frontmatter`);
  }
  const renamed = frontmatter[0].replace(/^name: .+$/m, `name: valency-${name}`);
  return renamed + contents.slice(frontmatter[0].length);
};

// Committed copies, as [path relative to the repo root, contents].
export const committedCopies = () =>
  skillNames().flatMap((name) => {
    const contents = canonicalSkill(name);
    return [
      ...providers.map((provider) => [
        `plugins/${provider}/valency/skills/${name}/SKILL.md`,
        contents,
      ]),
      [`steering/${name}.md`, contents],
    ];
  });

// Folders or files in a copy location that no canonical skill produces.
// OpenAI's skill folders also hold its own agents/ and assets/; every other
// provider's hold SKILL.md alone.
const strayCopies = () => {
  const names = new Set(skillNames());
  const stray = providers.flatMap((provider) => {
    const dir = `plugins/${provider}/valency/skills`;
    if (!existsSync(join(root, dir))) return [];
    return readdirSync(join(root, dir), { withFileTypes: true }).flatMap((entry) => {
      if (entry.name.startsWith(".")) return [];
      if (!names.has(entry.name) || !entry.isDirectory()) return [`${dir}/${entry.name}`];
      if (provider === "openai") return [];
      return readdirSync(join(root, dir, entry.name))
        .filter((file) => file !== "SKILL.md" && !file.startsWith("."))
        .map((file) => `${dir}/${entry.name}/${file}`);
    });
  });
  if (existsSync(join(root, "steering"))) {
    stray.push(
      ...readdirSync(join(root, "steering"), { withFileTypes: true })
        .filter(
          (entry) =>
            !entry.name.startsWith(".") &&
            !(entry.isFile() && entry.name.endsWith(".md") && names.has(entry.name.slice(0, -3))),
        )
        .map((entry) => `steering/${entry.name}`),
    );
  }
  return stray;
};

const write = (path, contents) => {
  mkdirSync(dirname(join(root, path)), { recursive: true });
  writeFileSync(join(root, path), contents);
};

export const writeVscodeCopies = () => {
  const dir = join(root, "vscode", "skills");
  rmSync(dir, { recursive: true, force: true });
  for (const name of skillNames()) {
    write(`vscode/skills/valency-${name}/SKILL.md`, vscodeSkill(name, canonicalSkill(name)));
  }
};

const main = (args) => {
  if (args.includes("--vscode")) {
    writeVscodeCopies();
    return 0;
  }

  if (args.includes("--check")) {
    const drifted = committedCopies()
      .filter(
        ([path, contents]) =>
          !existsSync(join(root, path)) || readFileSync(join(root, path), "utf8") !== contents,
      )
      .map(([path]) => path);
    const problems = [...drifted, ...strayCopies()];
    if (problems.length > 0) {
      console.error("Skill copies are out of date. Edit skills/ only, then run `npm run sync:skills`:");
      for (const path of problems) console.error(`  ${path}`);
      return 1;
    }
    return 0;
  }

  let status = 0;
  for (const path of strayCopies()) {
    // OpenAI's hand-maintained metadata would be lost; leave it for a person to move.
    const handMade =
      path.startsWith("plugins/openai/") &&
      statSync(join(root, path)).isDirectory() &&
      readdirSync(join(root, path)).some((file) => file !== "SKILL.md" && !file.startsWith("."));
    if (handMade) {
      console.error(`Keeping ${path}: move its agents/ and assets/ to the renamed skill, then delete it.`);
      status = 1;
      continue;
    }
    console.log(`Removing ${path}`);
    rmSync(join(root, path), { recursive: true, force: true });
  }
  for (const [path, contents] of committedCopies()) write(path, contents);
  return status;
};

if (process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url))) {
  process.exit(main(process.argv.slice(2)));
}
