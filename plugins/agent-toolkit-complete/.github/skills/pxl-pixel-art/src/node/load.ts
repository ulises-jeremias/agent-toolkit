// Loads art files (.js or .ts) into a Project by running them in a vm
// context whose globals are the DSL. Each load gets a fresh context, so
// reloading after an edit is clean.
//
// SECURITY: Node's `vm` is NOT a security sandbox. The DSL functions are
// host-realm objects, so reviewed art must be treated as trusted code that
// runs with the caller's privileges (see DOWNSTREAM.md). The limits below
// are defense-in-depth against accidents and runaway work — a wall-clock
// timeout for the load script, no string/WASM code generation inside the
// art context, and source size/count caps — not hostile-code isolation.
import { readFileSync } from "node:fs";
import { dirname, isAbsolute, resolve } from "node:path";
import * as vm from "node:vm";
import { stripTypeScriptTypes } from "node:module";
import { PxError, wrap } from "../core/errors.ts";
import { Project, type ProjectOptions } from "../core/project.ts";

export interface LoadOptions extends ProjectOptions {
  /** Wall-clock limit for executing art code while loading (ms). Default 5000, max 60000. */
  timeoutMs?: number;
  /** Total UTF-8 bytes accepted across the entry file and its includes. Default 16 MiB. */
  maxBytes?: number;
  /** Maximum number of files loaded through include(). Default 128. */
  maxFiles?: number;
}

const DEFAULT_TIMEOUT_MS = 5000;
const MAX_TIMEOUT_MS = 60_000;
const DEFAULT_MAX_BYTES = 16 * 1024 * 1024;
const DEFAULT_MAX_FILES = 128;

function limits(opts: LoadOptions): Required<Omit<LoadOptions, keyof ProjectOptions>> {
  const timeoutMs = opts.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const maxBytes = opts.maxBytes ?? DEFAULT_MAX_BYTES;
  const maxFiles = opts.maxFiles ?? DEFAULT_MAX_FILES;
  if (!Number.isFinite(timeoutMs) || timeoutMs < 1 || timeoutMs > MAX_TIMEOUT_MS)
    throw new PxError(`timeoutMs must be between 1 and ${MAX_TIMEOUT_MS}, got ${timeoutMs}`);
  if (!Number.isFinite(maxBytes) || maxBytes < 1) throw new PxError(`maxBytes must be positive, got ${maxBytes}`);
  if (!Number.isFinite(maxFiles) || maxFiles < 1) throw new PxError(`maxFiles must be positive, got ${maxFiles}`);
  return { timeoutMs: Math.floor(timeoutMs), maxBytes: Math.floor(maxBytes), maxFiles: Math.floor(maxFiles) };
}

function artContext(p: Project): vm.Context {
  return vm.createContext({ ...p.env(), console }, {
    codeGeneration: { strings: false, wasm: false },
    microtaskMode: "afterEvaluate",
  });
}

function compile(code: string, file: string): string {
  // Type stripping keeps every line and column in place, so error locations stay exact.
  return /\.[cm]?ts$/.test(file) ? stripTypeScriptTypes(code, { mode: "strip" }) : code;
}

/** Load an art file from disk. Throws PxError with a file:line:col location on failure. */
export function loadProject(file: string, opts: LoadOptions = {}): Project {
  const lim = limits(opts);
  const p = new Project(opts);
  const ctx = artContext(p);
  const stack: string[] = [];
  let totalBytes = 0;
  const run = (path: string) => {
    const abs = resolve(path);
    if (stack.includes(abs)) throw new PxError(`include cycle: ${[...stack, abs].join(" -> ")}`);
    if (p.files.length >= lim.maxFiles && !p.files.includes(abs))
      throw new PxError(`too many art files (limit ${lim.maxFiles})`, p.callerLoc());
    let code: string;
    try { code = readFileSync(abs, "utf8"); } catch {
      throw new PxError(`cannot read art file '${abs}'`, p.callerLoc());
    }
    totalBytes += Buffer.byteLength(code, "utf8");
    if (totalBytes > lim.maxBytes)
      throw new PxError(`art sources exceed ${lim.maxBytes} bytes`, p.callerLoc());
    p.addFile(abs);
    stack.push(abs);
    try {
      vm.runInContext(compile(code, abs), ctx, { filename: abs, timeout: lim.timeoutMs });
    } catch (e) {
      throw syntaxAware(e, abs, p);
    } finally {
      stack.pop();
    }
  };
  p.includeHook = (path) => run(isAbsolute(path) ? path : resolve(dirname(stack[stack.length - 1]), path));
  run(file);
  return p;
}

/** Load art source from a string (tests, embedding). `name` appears in error locations. */
export function loadSource(src: string, name = "art.px.js", opts: LoadOptions = {}): Project {
  const lim = limits(opts);
  if (Buffer.byteLength(src, "utf8") > lim.maxBytes)
    throw new PxError(`art source exceeds ${lim.maxBytes} bytes`);
  const p = new Project(opts);
  const ctx = artContext(p);
  p.addFile(name);
  try {
    vm.runInContext(compile(src, name), ctx, { filename: name, timeout: lim.timeoutMs });
  } catch (e) {
    throw syntaxAware(e, name, p);
  }
  return p;
}

function syntaxAware(e: unknown, file: string, p: Project): PxError {
  const err = wrap(e, (s) => p.locFromStack(s));
  // SyntaxErrors put the location in the first stack line ("file:line").
  if (!err.loc && typeof e === "object" && e && "stack" in e) {
    const m = new RegExp(escape(file) + ":(\\d+)").exec(String((e as Error).stack));
    if (m) err.loc = `${file.replace(/^.*[\\/]/, "")}:${m[1]}`;
    err.message = err.format();
  }
  return err;
}

function escape(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
