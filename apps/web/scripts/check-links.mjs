import { readdir, readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const outputDirectory = fileURLToPath(new URL("../dist/", import.meta.url));
const origin = "https://agent-toolkit.io";

async function htmlFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(
    entries.map(async (entry) => {
      const absolutePath = path.join(directory, entry.name);
      if (entry.isDirectory()) return htmlFiles(absolutePath);
      return entry.isFile() && entry.name.endsWith(".html")
        ? [absolutePath]
        : [];
    }),
  );
  return nested.flat();
}

async function exists(target) {
  try {
    return (await stat(target)).isFile();
  } catch {
    return false;
  }
}

const pages = await htmlFiles(outputDirectory);
const missing = [];
for (const page of pages) {
  const html = await readFile(page, "utf8");
  for (const [, rawUrl] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (!rawUrl || rawUrl.startsWith("#")) continue;
    const url = new URL(
      rawUrl,
      `${origin}/${path.relative(outputDirectory, page).split(path.sep).join("/")}`,
    );
    if (url.origin !== origin) continue;
    const decoded = decodeURIComponent(url.pathname);
    const candidates = decoded.endsWith("/")
      ? [path.join(outputDirectory, decoded.slice(1), "index.html")]
      : [
          path.join(outputDirectory, decoded.slice(1)),
          path.join(outputDirectory, `${decoded.slice(1)}.html`),
        ];
    let found = false;
    for (const candidate of candidates) {
      if (await exists(candidate)) {
        found = true;
        break;
      }
    }
    if (!found)
      missing.push(`${path.relative(outputDirectory, page)} → ${rawUrl}`);
  }
}

if (missing.length > 0) {
  console.error(
    `Found ${missing.length} broken local link(s):\n${missing.slice(0, 100).join("\n")}`,
  );
  process.exitCode = 1;
} else {
  console.log(
    `Checked ${pages.length} rendered pages; all local links and assets resolve.`,
  );
}
