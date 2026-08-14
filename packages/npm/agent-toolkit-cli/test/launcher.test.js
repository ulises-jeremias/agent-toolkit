"use strict";

/**
 * npm trampoline tests (ADR-025) — mirror packages/pypi launcher coverage in
 * tests/test_launcher.py. No V compile required.
 */

const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const PKG_ROOT = path.join(__dirname, "..");
const LAUNCHER = path.join(PKG_ROOT, "bin", "agent-toolkit.js");
const {
  platformSpec,
  resolveNativeBin,
  missingBinaryMessage,
  EXIT_MISSING,
} = require(LAUNCHER);

function writeFakeBin(dir) {
  // Portable Node stub: shebang on posix; on Windows the launcher rewrites
  // AGENT_TOOLKIT_BIN=*.js → spawn(process.execPath, [script, ...argv]).
  const dest = path.join(dir, process.platform === "win32" ? "fake-bin.js" : "fake-bin");
  fs.writeFileSync(
    dest,
    [
      "#!/usr/bin/env node",
      '"use strict";',
      'const code = Number(process.env.FAKE_EXIT || "0");',
      'process.stdout.write(process.argv.slice(2).join(" ") + "\\n");',
      "process.exit(Number.isFinite(code) ? code : 0);",
      "",
    ].join("\n"),
    { mode: 0o755 },
  );
  return dest;
}

function writeNativeStub(filePath) {
  // Same portable stub used for AGENT_TOOLKIT_ROOT/build resolution tests.
  fs.writeFileSync(
    filePath,
    [
      "#!/usr/bin/env node",
      '"use strict";',
      "process.exit(0);",
      "",
    ].join("\n"),
    { mode: 0o755 },
  );
}

function runLauncher(args, env) {
  return spawnSync(process.execPath, [LAUNCHER, ...args], {
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
}

function withEnv(overrides, fn) {
  const keys = Object.keys(overrides);
  const prev = {};
  for (const key of keys) {
    prev[key] = process.env[key];
    const val = overrides[key];
    if (val === undefined || val === null) {
      delete process.env[key];
    } else {
      process.env[key] = val;
    }
  }
  try {
    return fn();
  } finally {
    for (const key of keys) {
      if (prev[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = prev[key];
      }
    }
  }
}

describe("spawn: missing / env binary", () => {
  test("missing binary exits 127", () => {
    const result = runLauncher(["version"], {
      AGENT_TOOLKIT_BIN: "",
      AGENT_TOOLKIT_ROOT: path.join(os.tmpdir(), "agent-toolkit-missing-root"),
    });
    assert.equal(result.status, EXIT_MISSING);
    assert.match(result.stderr, /native V binary not found/);
    assert.match(result.stderr, /AGENT_TOOLKIT_BIN|v run make.vsh build-cli|optionalDependencies/);
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

  test("AGENT_TOOLKIT_BIN pointing at a missing file exits 127", () => {
    const result = runLauncher([], {
      AGENT_TOOLKIT_BIN: path.join(os.tmpdir(), "no-such-agent-toolkit-bin"),
      AGENT_TOOLKIT_ROOT: path.join(os.tmpdir(), "agent-toolkit-missing-root"),
    });
    assert.equal(result.status, EXIT_MISSING);
  });
});

describe("resolveNativeBin (unit)", () => {
  test("prefers AGENT_TOOLKIT_BIN when the file exists", () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "atk-npm-"));
    const bin = writeFakeBin(tmp);
    withEnv({ AGENT_TOOLKIT_BIN: bin, AGENT_TOOLKIT_ROOT: undefined }, () => {
      assert.equal(resolveNativeBin(), bin);
    });
  });

  test("returns null when AGENT_TOOLKIT_BIN is set but missing", () => {
    withEnv(
      {
        AGENT_TOOLKIT_BIN: path.join(os.tmpdir(), "no-such-agent-toolkit-bin"),
        AGENT_TOOLKIT_ROOT: undefined,
      },
      () => {
        assert.equal(resolveNativeBin(), null);
      },
    );
  });

  test("resolves AGENT_TOOLKIT_ROOT/build native stub", () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "atk-npm-root-"));
    const build = path.join(tmp, "build");
    fs.mkdirSync(build);
    const names =
      process.platform === "win32"
        ? ["agent-toolkit.exe", "agent-toolkit"]
        : ["agent-toolkit", "agent-toolkit-v"];
    const native = path.join(build, names[0]);
    writeNativeStub(native);
    withEnv({ AGENT_TOOLKIT_BIN: undefined, AGENT_TOOLKIT_ROOT: tmp }, () => {
      assert.equal(resolveNativeBin(), native);
    });
  });

  test("resolves AGENT_TOOLKIT_ROOT/build/agent-toolkit-v on posix", { skip: process.platform === "win32" }, () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "atk-npm-v-"));
    const build = path.join(tmp, "build");
    fs.mkdirSync(build);
    const native = path.join(build, "agent-toolkit-v");
    writeNativeStub(native);
    withEnv({ AGENT_TOOLKIT_BIN: undefined, AGENT_TOOLKIT_ROOT: tmp }, () => {
      assert.equal(resolveNativeBin(), native);
    });
  });
});

describe("platformSpec + package metadata", () => {
  test("platformSpec matches platforms.json for this host", () => {
    const specs = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "platforms.json"), "utf8"));
    const cpu = process.arch === "ia32" ? "ia32" : process.arch;
    const expected = specs.find((p) => p.os === process.platform && p.cpu === cpu) || null;
    assert.deepEqual(platformSpec(), expected);
  });

  test("platforms.json covers release triples (no musl)", () => {
    const specs = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "platforms.json"), "utf8"));
    assert.equal(specs.length, 5);
    const npmNames = specs.map((s) => s.npm).sort();
    assert.deepEqual(npmNames, [
      "agent-toolkit-cli-darwin-arm64",
      "agent-toolkit-cli-darwin-x64",
      "agent-toolkit-cli-linux-arm64",
      "agent-toolkit-cli-linux-x64",
      "agent-toolkit-cli-win32-x64",
    ]);
    for (const spec of specs) {
      assert.ok(spec.bin);
      assert.ok(spec.floating);
      if (spec.os === "linux") {
        assert.equal(spec.libc, "glibc");
      }
    }
  });

  test("package.json bin entries and optionalDependencies stay in sync", () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "package.json"), "utf8"));
    assert.equal(pkg.bin["agent-toolkit"], "bin/agent-toolkit.js");
    assert.equal(pkg.bin["agent-toolkit-cli"], "bin/agent-toolkit.js");
    assert.match(pkg.engines.node, />=18/);
    const specs = JSON.parse(fs.readFileSync(path.join(PKG_ROOT, "platforms.json"), "utf8"));
    for (const spec of specs) {
      assert.equal(pkg.optionalDependencies[spec.npm], pkg.version);
    }
  });

  test("missingBinaryMessage mentions ADR-025 and recovery paths", () => {
    const msg = missingBinaryMessage();
    assert.match(msg, /ADR-025/);
    assert.match(msg, /optionalDependencies|AGENT_TOOLKIT_BIN|v run make.vsh build-cli/);
  });
});

describe("spawn: AGENT_TOOLKIT_ROOT", () => {
  test("forwards through root-resolved stub", { skip: process.platform === "win32" }, () => {
    // Windows Release binaries are PE (.exe); shebang stubs cannot be CreateProcess'd.
    // Windows spawn forwarding is covered by AGENT_TOOLKIT_BIN=*.js tests above.
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "atk-npm-spawn-root-"));
    const build = path.join(tmp, "build");
    fs.mkdirSync(build);
    const stub = path.join(build, "agent-toolkit");
    const echo = writeFakeBin(tmp);
    fs.copyFileSync(echo, stub);
    fs.chmodSync(stub, 0o755);
    const result = runLauncher(["skills", "list"], {
      AGENT_TOOLKIT_BIN: "",
      AGENT_TOOLKIT_ROOT: tmp,
      FAKE_EXIT: "0",
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /skills/);
    assert.match(result.stdout, /list/);
  });
});
