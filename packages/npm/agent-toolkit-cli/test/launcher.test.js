"use strict";

const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { test } = require("node:test");
const assert = require("node:assert/strict");

const LAUNCHER = path.join(__dirname, "..", "bin", "agent-toolkit.js");

function writeFakeBin(dir) {
  const isWin = process.platform === "win32";
  const dest = path.join(dir, isWin ? "fake-bin.cmd" : "fake-bin");
  if (isWin) {
    fs.writeFileSync(
      dest,
      ["@echo off", "echo %*", "if not \"%FAKE_EXIT%\"==\"\" exit /b %FAKE_EXIT%", "exit /b 0"].join("\r\n"),
    );
  } else {
    fs.writeFileSync(
      dest,
      "#!/bin/sh\nprintf '%s\\n' \"$*\"\nexit \"${FAKE_EXIT:-0}\"\n",
      { mode: 0o755 },
    );
  }
  return dest;
}

function runLauncher(args, env) {
  return spawnSync(process.execPath, [LAUNCHER, ...args], {
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
}

test("missing binary exits 127", () => {
  const result = runLauncher(["version"], {
    AGENT_TOOLKIT_BIN: "",
    AGENT_TOOLKIT_ROOT: path.join(os.tmpdir(), "agent-toolkit-missing-root"),
  });
  assert.equal(result.status, 127);
  assert.match(result.stderr, /native V binary not found/);
});

test("AGENT_TOOLKIT_BIN forwards argv and exit code", () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "atk-npm-"));
  const bin = writeFakeBin(tmp);
  const result = runLauncher(["--flag", "value with spaces"], {
    AGENT_TOOLKIT_BIN: bin,
    FAKE_EXIT: "0",
  });
  assert.equal(result.status, 0);
  assert.match(result.stdout, /--flag/);
  assert.match(result.stdout, /value with spaces/);
});

test("AGENT_TOOLKIT_BIN forwards non-zero exit", () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "atk-npm-"));
  const bin = writeFakeBin(tmp);
  const result = runLauncher(["boom"], {
    AGENT_TOOLKIT_BIN: bin,
    FAKE_EXIT: "3",
  });
  assert.equal(result.status, 3);
});

test("unset AGENT_TOOLKIT_BIN that points at a missing file exits 127", () => {
  const result = runLauncher([], {
    AGENT_TOOLKIT_BIN: path.join(os.tmpdir(), "no-such-agent-toolkit-bin"),
  });
  assert.equal(result.status, 127);
});
