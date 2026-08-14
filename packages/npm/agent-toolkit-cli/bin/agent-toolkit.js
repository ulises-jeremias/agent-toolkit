#!/usr/bin/env node
"use strict";

/**
 * Thin npm launcher — spawn the bundled V binary (ADR-025 / #536).
 * No JS business logic. Product commands agent-toolkit and agent-toolkit-cli
 * hand off to the native binary (same product as PyPI).
 */

const { spawn } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

const PLATFORMS = require("../platforms.json");
const EXIT_MISSING = 127;

function platformSpec() {
  const osName = process.platform;
  const cpu = process.arch === "ia32" ? "ia32" : process.arch;
  return PLATFORMS.find((p) => p.os === osName && p.cpu === cpu) || null;
}

function resolveNativeBin() {
  const env = (process.env.AGENT_TOOLKIT_BIN || "").trim();
  if (env) {
    return fs.existsSync(env) ? env : null;
  }
  const spec = platformSpec();
  if (spec) {
    try {
      const pkgDir = path.dirname(require.resolve(`${spec.npm}/package.json`));
      const cand = path.join(pkgDir, "bin", spec.bin);
      if (fs.existsSync(cand)) {
        return cand;
      }
    } catch {
      // optionalDependency not installed for this platform
    }
  }
  const root = (process.env.AGENT_TOOLKIT_ROOT || "").trim();
  if (root) {
    const names =
      process.platform === "win32"
        ? ["build/agent-toolkit.exe", "build/agent-toolkit"]
        : ["build/agent-toolkit", "build/agent-toolkit-v"];
    for (const rel of names) {
      const cand = path.join(root, rel);
      if (fs.existsSync(cand)) {
        return cand;
      }
    }
  }
  return null;
}

function missingBinaryMessage() {
  return [
    "agent-toolkit: native V binary not found (ADR-025).",
    "  npm optionalDependencies should install agent-toolkit-cli-<os>-<cpu>.",
    "  Dev: v run make.vsh build-cli, or set AGENT_TOOLKIT_BIN to that executable.",
    "",
  ].join("\n");
}

function runNative(binPath, argv) {
  // Native Release binaries are .exe / ELF / Mach-O. For Windows tests (and rare
  // AGENT_TOOLKIT_BIN=.js helpers), invoke via node so spawn does not need shell.
  let command = binPath;
  let args = argv;
  if (process.platform === "win32" && /\.js$/i.test(binPath)) {
    command = process.execPath;
    args = [binPath, ...argv];
  }
  const child = spawn(command, args, {
    stdio: "inherit",
    windowsHide: true,
  });
  const forward = (signal) => {
    if (child.killed) {
      return;
    }
    try {
      child.kill(signal);
    } catch {
      /* child already gone */
    }
  };
  process.on("SIGINT", () => forward("SIGINT"));
  process.on("SIGTERM", () => forward("SIGTERM"));
  child.on("error", (err) => {
    process.stderr.write(`agent-toolkit: failed to spawn native binary: ${err.message}\n`);
    process.exit(EXIT_MISSING);
  });
  child.on("exit", (code, signal) => {
    if (signal) {
      process.exit(1);
    }
    process.exit(code == null ? 1 : code);
  });
}

function main(argv) {
  const rest = argv.slice(2);
  const binPath = resolveNativeBin();
  if (!binPath) {
    process.stderr.write(missingBinaryMessage());
    process.exit(EXIT_MISSING);
  }
  runNative(binPath, rest);
}

module.exports = { platformSpec, resolveNativeBin, missingBinaryMessage, EXIT_MISSING };

if (require.main === module) {
  main(process.argv);
}
