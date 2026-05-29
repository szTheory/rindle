// @ts-check
const { execFileSync } = require("node:child_process");
const path = require("node:path");

const projectRoot = path.resolve(__dirname, "..");

function runMix(args, extraEnv = {}) {
  const env = { ...process.env, MIX_ENV: "test", ...extraEnv };

  if (env.PHX_SERVER === "") {
    delete env.PHX_SERVER;
  }

  execFileSync("mix", args, {
    cwd: projectRoot,
    stdio: "inherit",
    env,
  });
}

function ensureDatabase() {
  try {
    runMix(["ecto.create", "--quiet"], { PHX_SERVER: "1" });
  } catch (error) {
    const output = `${error.stdout || ""}\n${error.stderr || ""}`;

    if (!output.includes("already exists")) {
      throw error;
    }
  }
}

module.exports = async () => {
  if (process.env.ADOPTION_DEMO_REUSE_SERVER === "1") {
    return;
  }

  ensureDatabase();
  runMix(["ecto.migrate", "--quiet"], { PHX_SERVER: "1" });
  runMix(["rindle.migrate"], { PHX_SERVER: "1" });
  runMix(["run", "priv/repo/seeds.exs"], { PHX_SERVER: "" });
};
