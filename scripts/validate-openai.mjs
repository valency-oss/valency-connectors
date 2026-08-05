import { spawnSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const codexHome = process.env.CODEX_HOME || join(homedir(), ".codex");
const validator = join(
  codexHome,
  "skills",
  ".system",
  "plugin-creator",
  "scripts",
  "validate_plugin.py",
);

const result = spawnSync(
  "uv",
  [
    "run",
    "--no-project",
    "--with",
    "PyYAML==6.0.3",
    "python",
    validator,
    "plugins/openai/valency",
  ],
  { stdio: "inherit" },
);

if (result.error) {
  console.error(`Unable to run the OpenAI plugin validator: ${result.error.message}`);
}

process.exit(result.status ?? 1);
