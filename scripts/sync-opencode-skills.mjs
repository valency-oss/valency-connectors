import {
  cpSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const canonicalRoot = join(repositoryRoot, "skills");
const targetRoot = join(repositoryRoot, "plugins", "opencode", "valency", "skills");
const skillNames = readdirSync(canonicalRoot, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort();

rmSync(targetRoot, { recursive: true, force: true });
mkdirSync(targetRoot, { recursive: true });

for (const skillName of skillNames) {
  const source = join(canonicalRoot, skillName);
  const projectedName = `valency-${skillName}`;
  const target = join(targetRoot, projectedName);
  const sourceSkill = join(source, "SKILL.md");
  const contents = readFileSync(sourceSkill, "utf8");
  const nameLine = new RegExp(`^name: ${skillName}$`, "m");

  if (!nameLine.test(contents)) {
    throw new Error(`${sourceSkill} must declare name: ${skillName}`);
  }

  cpSync(source, target, { recursive: true });
  writeFileSync(
    join(target, "SKILL.md"),
    contents.replace(nameLine, `name: ${projectedName}`),
  );
}

console.log(`Projected ${skillNames.length} OpenCode skills.`);
