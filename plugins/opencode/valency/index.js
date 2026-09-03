import { fileURLToPath } from "node:url";

const skillsPath = fileURLToPath(new URL("./skills/", import.meta.url));

export const ValencyPlugin = async () => ({
  config: async (config) => {
    config.mcp ??= {};
    config.mcp.valency ??= {
      type: "remote",
      url: "https://mcp.valency.io/",
    };

    config.skills ??= {};
    config.skills.paths ??= [];
    if (!config.skills.paths.includes(skillsPath)) {
      config.skills.paths.push(skillsPath);
    }
  },
});
