import path from "node:path";
import { fileURLToPath } from "node:url";
import { publicDocBySource } from "../data/docs-nav.mjs";

const REPOSITORY = "https://github.com/ulises-jeremias/agent-toolkit";

export function rewriteSourceUrl(url, sourceUrl, repoRoot, isImage = false) {
  if (typeof url !== "string" || /^(?:[a-z][a-z\d+.-]*:|\/|#)/i.test(url))
    return url;

  const source =
    sourceUrl instanceof URL ? fileURLToPath(sourceUrl) : sourceUrl;
  const sourceRelative = path
    .relative(repoRoot, source)
    .split(path.sep)
    .join("/");
  const [filePart, ...hashParts] = url.split("#");
  const fragment = hashParts.length ? `#${hashParts.join("#")}` : "";
  const target = path.posix.normalize(
    path.posix.join(path.posix.dirname(sourceRelative), filePart),
  );
  const encodedTarget = target.split("/").map(encodeURIComponent).join("/");

  if (target.startsWith("static/")) {
    return `/${target.slice("static/".length)}${fragment}`;
  }

  if (target.startsWith("docs/") && !isImage) {
    const publicDocument = publicDocBySource.get(target.slice("docs/".length));
    if (publicDocument) return `/docs/${publicDocument.slug}/${fragment}`;
  }

  const host = isImage ? "https://raw.githubusercontent.com" : REPOSITORY;
  const route = isImage
    ? `/main/${encodedTarget}`
    : `/blob/main/${encodedTarget}`;
  const repository = isImage ? `${host}/ulises-jeremias/agent-toolkit` : host;
  return `${repository}${route}${fragment}`;
}

export function sourceLinks({ repoRoot }) {
  const rewrite = (node, context, isImage) => {
    if (!context.fileURL) return;
    const url = rewriteSourceUrl(node.url, context.fileURL, repoRoot, isImage);
    if (url !== node.url) context.setProperty(node, "url", url);
  };

  return {
    name: "agent-toolkit-source-links",
    link(node, context) {
      rewrite(node, context, false);
    },
    image(node, context) {
      rewrite(node, context, true);
    },
    html(node, context) {
      if (!context.fileURL) return;
      const value = node.value.replace(
        /\b(src|href)=(['"])([^'"]+)\2/g,
        (_attribute, key, quote, url) => {
          const rewritten = rewriteSourceUrl(
            url,
            context.fileURL,
            repoRoot,
            key === "src",
          );
          return `${key}=${quote}${rewritten}${quote}`;
        },
      );
      if (value !== node.value) context.setProperty(node, "value", value);
    },
  };
}
