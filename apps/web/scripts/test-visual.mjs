import { spawn } from "node:child_process";
import process from "node:process";

const port = Number.parseInt(process.env["WEB_TEST_PORT"] ?? "4333", 10);
const baseURL = `http://127.0.0.1:${port}`;
const packageManager = process.platform === "win32" ? "pnpm.cmd" : "pnpm";
let launched = false;

function run(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: "inherit", ...options });
    child.once("error", reject);
    child.once("exit", (code, signal) => {
      if (signal) reject(new Error(`${command} ended with ${signal}`));
      else resolve(code ?? 1);
    });
  });
}

async function isListening() {
  try {
    return (await fetch(baseURL, { signal: AbortSignal.timeout(500) })).ok;
  } catch {
    return false;
  }
}

try {
  if (await isListening()) {
    throw new Error(
      `${baseURL} is already in use; stop that server before the visual suite.`,
    );
  }
  const started = await run(packageManager, [
    "exec",
    "astro",
    "preview",
    "--background",
    "--host",
    "127.0.0.1",
    "--port",
    String(port),
  ]);
  if (started !== 0) throw new Error("Astro preview failed to start.");
  launched = true;

  const deadline = Date.now() + 15_000;
  while (!(await isListening())) {
    if (Date.now() >= deadline)
      throw new Error("Astro preview did not become ready.");
    await new Promise((resolve) => setTimeout(resolve, 200));
  }

  const result = await run(packageManager, ["exec", "playwright", "test"], {
    env: { ...process.env, WEB_TEST_PORT: String(port) },
  });
  if (result !== 0) process.exitCode = result;
} catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
} finally {
  if (launched) {
    const stopped = await run(packageManager, [
      "exec",
      "astro",
      "preview",
      "stop",
    ]);
    if (stopped !== 0) process.exitCode = 1;
  }
}
