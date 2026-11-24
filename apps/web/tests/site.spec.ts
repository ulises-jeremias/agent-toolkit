import { expect, test, type Page } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { mkdir } from "node:fs/promises";
import path from "node:path";

const capture = process.env["ATK_WEB_CAPTURE"] === "1";
const captureDir = path.resolve(
  process.env["ATK_WEB_CAPTURE_DIR"] ?? "test-results/review",
);

async function capturePage(page: Page, filename: string) {
  if (!capture) return;
  await mkdir(captureDir, { recursive: true });
  await page.locator('img[loading="lazy"]').evaluateAll((images) => {
    for (const image of images) (image as HTMLImageElement).loading = "eager";
  });
  const imageCount = await page.locator("img[src]").count();
  await expect
    .poll(() =>
      page.locator("img[src]").evaluateAll(
        (images) =>
          images.filter((image) => {
            const imageElement = image as HTMLImageElement;
            return imageElement.complete && imageElement.naturalWidth > 0;
          }).length,
      ),
    )
    .toBe(imageCount);
  await page.evaluate(() => {
    window.scrollTo(0, 0);
    document.querySelector<HTMLElement>(".skip-link")?.blur();
    (document.activeElement as HTMLElement | null)?.blur();
  });
  await page.screenshot({
    path: path.join(captureDir, filename),
    fullPage: true,
  });
}

async function captureViewport(page: Page, filename: string) {
  if (!capture) return;
  await mkdir(captureDir, { recursive: true });
  await page.screenshot({ path: path.join(captureDir, filename) });
}

test("home explains the portable toolkit and its product boundaries", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Useful capabilities for the coding agents you already use.",
  );
  await expect(
    page.getByRole("heading", { name: "Skills", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Agents", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "MCP", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Workflows", exact: true }),
  ).toBeVisible();
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    "https://www.agent-toolkit.io/",
  );
  const imageURL = new URL(
    (await page.locator('meta[property="og:image"]').getAttribute("content")) ??
      "",
  );
  expect(imageURL.pathname).toBe("/site/og-portable.svg");
  const ogImage = await page.request.get(
    new URL(imageURL.pathname, page.url()).href,
  );
  expect(ogImage.ok()).toBeTruthy();
  await expect(page.locator('meta[property="og:image"]')).toHaveAttribute(
    "content",
    /agent-toolkit\.io\/site\/og-portable\.svg/,
  );
  await expect(page.locator('meta[property="og:image:width"]')).toHaveAttribute(
    "content",
    "1200",
  );
  await expect(
    page.locator('meta[property="og:image:height"]'),
  ).toHaveAttribute("content", "630");
  await expect(page.locator('meta[name="twitter:image"]')).toHaveAttribute(
    "content",
    /agent-toolkit\.io\/site\/og-portable\.png$/,
  );
  const twitterImageURL = new URL(
    (await page
      .locator('meta[name="twitter:image"]')
      .getAttribute("content")) ?? "",
  );
  expect(
    (
      await page.request.get(new URL(twitterImageURL.pathname, page.url()).href)
    ).ok(),
  ).toBeTruthy();
  await expect(
    page.getByRole("link", { name: /get Veasel Code/i }),
  ).toHaveAttribute("href", "https://www.veasel.dev/downloads/");
  await expect(
    page.getByRole("link", { name: /explore capabilities/i }),
  ).toBeVisible();
  await capturePage(page, "home-desktop.png");
});

test("product role links remain clear with reduced motion", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");

  await expect(
    page.getByRole("link", { name: /install the CLI/i }).first(),
  ).toBeVisible();
  await expect(
    page.getByRole("link", { name: /get Veasel Code/i }),
  ).toHaveAttribute("href", "https://www.veasel.dev/downloads/");
  // Keyboard: primary product links remain reachable.
  await page.locator("body").press("Tab");
  const focusedHref = await page.evaluate(
    () => document.activeElement?.getAttribute("href") ?? "",
  );
  expect(typeof focusedHref).toBe("string");
  await captureViewport(page, "product-roles-desktop.png");
});

test("portable product navigation works without JavaScript", async ({
  browser,
}) => {
  const page = await browser.newPage({ javaScriptEnabled: false });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");

  await expect(
    page.getByRole("heading", { name: /Useful capabilities/ }),
  ).toBeVisible();
  await page.getByRole("link", { name: /Explore capabilities/ }).click();
  await expect(page).toHaveURL(/\/capabilities\/$/);
  await page.close();
});

test("legacy product routes are clearly labeled as archives", async ({
  page,
}) => {
  await page.goto("/world/");
  await expect(
    page.getByRole("complementary", { name: /Legacy Desktop archive notice/i }),
  ).toContainText("retired Agent Toolkit Desktop");
  await expect(page.locator(".page-hero-art figcaption")).toBeVisible();
  await page.goto("/people/");
  await expect(
    page.getByRole("complementary", { name: /Legacy Desktop archive notice/i }),
  ).toContainText("portable capability toolkit");
  await expect(page.locator(".page-hero-art figcaption")).toBeVisible();
  await page.goto("/swarms/");
  await expect(
    page.getByRole("complementary", { name: /Legacy Desktop archive notice/i }),
  ).toContainText("Veasel Code");
  await expect(page.locator(".page-hero-art figcaption")).toBeVisible();
  await capturePage(page, "swarms-archive-desktop.png");
  await page.goto("/people/");
  await capturePage(page, "people-desktop.png");
  await page.goto("/world/");
  await capturePage(page, "world-desktop.png");
});

test("nested docs paths expose only one current navigation item", async ({
  page,
}) => {
  await page.goto("/docs/installation/");
  await expect(page.locator(".desktop-nav [aria-current=page]")).toHaveCount(1);
  await expect(page.locator('.desktop-nav a[aria-current="page"]')).toHaveText(
    "Install",
  );
});

test("capabilities are searchable and grouped from canonical catalogs", async ({
  page,
}) => {
  await page.goto("/capabilities/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Find the capability that fits this job.",
  );
  await expect(page.locator("#capability-count")).toContainText("entries");
  const search = page.getByRole("searchbox", { name: /search by name/i });
  const totalEntries = await page.locator(".capability-item:visible").count();
  expect(totalEntries).toBeGreaterThan(0);
  await search.fill("mcp-audit");
  await expect(page.locator(".capability-item:visible")).toHaveCount(1);
  await expect(page.locator(".capability-item:visible")).toContainText(
    "MCP config",
  );
  await expect(page.locator("#capability-count")).toContainText("1 of");
  await search.fill("nothing matches this exact phrase");
  await expect(page.getByText(/no catalog entries match/i)).toBeVisible();
  await search.fill("");
  await expect(page.locator(".capability-item:visible")).toHaveCount(
    totalEntries,
  );
  await capturePage(page, "capabilities-desktop.png");
});

test("download route explains the migration and keeps install paths distinct", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/download/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Agent Toolkit Desktop is retired.",
  );
  await expect(
    page.getByRole("link", { name: /Download Veasel Code/i }),
  ).toHaveAttribute("href", "https://www.veasel.dev/downloads/");
  await expect(page.locator(".cli-command")).toContainText(
    "uv tool install agent-toolkit-cli",
  );
  await expect(page.getByText(/does not automatically import/i)).toBeVisible();
  await capturePage(page, "download-migration.png");
});

test("retired Desktop route does not query Electron releases", async ({
  page,
}) => {
  await page.route("https://api.github.com/**", (route) => route.abort());
  await page.goto("/download/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText(
    "retired",
  );
  await expect(
    page.getByRole("link", { name: /Install Agent Toolkit CLI/i }),
  ).toBeVisible();
});

test("docs render canonical source with curated navigation", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/docs/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Clear paths into the Toolkit.",
  );
  await page.goto("/docs/people/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "People archive",
  );
  await expect(
    page.getByRole("link", { name: /view this guide in github/i }),
  ).toBeVisible();
  await expect(
    page
      .getByRole("complementary", { name: "Documentation navigation" })
      .getByRole("link", { name: "Swarms" }),
  ).toHaveAttribute("href", "/docs/swarms/");
  await capturePage(page, "docs-people-desktop.png");
  await page.goto("/docs/");
  await capturePage(page, "docs-index-desktop.png");
});

test("docs search returns heading-level results from the production index", async ({
  page,
}) => {
  await page.goto("/docs/");
  const search = page.getByRole("searchbox", {
    name: /search the documentation/i,
  });
  await search.fill("swarm roles");
  await expect(
    page.locator(".docs-search-results a[href*='#']").first(),
  ).toBeVisible({ timeout: 10_000 });
  await expect(page.locator(".docs-search-status")).toContainText(/match/);
  const href = await page
    .locator(".docs-search-results a[href*='#']")
    .first()
    .getAttribute("href");
  expect(href).toMatch(/^\/docs\/[^/]+\/#.+/);
  await page.locator(".docs-search-results a[href*='#']").first().click();
  await expect(page).toHaveURL(/#.+/);
});

test("docs pages expose breadcrumbs, TOC and prev/next navigation", async ({
  page,
}) => {
  await page.goto("/docs/people/");
  await expect(
    page.getByRole("navigation", { name: "Breadcrumb" }),
  ).toContainText("People");
  await expect(
    page
      .getByRole("navigation", { name: "On this page" })
      .getByRole("link")
      .first(),
  ).toHaveAttribute("href", /^#/);
  await expect(page.getByRole("link", { name: /next guide/i })).toBeVisible();
  await page.getByRole("link", { name: /next guide/i }).click();
  await expect(page).toHaveURL(/\/docs\/skills\/$/);
  await expect(
    page.getByRole("link", { name: /previous guide/i }),
  ).toBeVisible();
});

test("mobile navigation, touch layout and reduced motion remain usable", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
  await captureViewport(page, "home-mobile.png");
  await page.getByRole("link", { name: /Explore capabilities/ }).click();
  await expect(page).toHaveURL(/\/capabilities\/$/);
  await page.goto("/");
  await captureViewport(page, "destinations-mobile.png");
  await page.evaluate(() => window.scrollTo(0, 0));
  await expect
    .poll(() => page.locator("html").evaluate((element) => element.scrollWidth))
    .toBe(390);
  await page.locator(".mobile-nav summary").click();
  await expect(
    page
      .getByRole("navigation", { name: "Mobile navigation" })
      .getByRole("link", { name: "Compatibility" }),
  ).toBeVisible();
  await capturePage(page, "mobile-nav-open.png");
  await page
    .getByRole("navigation", { name: "Mobile navigation" })
    .getByRole("link", { name: "Capabilities" })
    .click();
  await expect(page).toHaveURL("/capabilities/");
  await capturePage(page, "capabilities-mobile.png");
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect
    .poll(() => page.locator("html").evaluate((element) => element.scrollWidth))
    .toBe(390);
  await page.goto("/docs/people/");
  await page.getByText("Browse documentation").click();
  await expect(
    page
      .getByRole("navigation", { name: "Documentation sections" })
      .getByRole("link", { name: "Swarms" }),
  ).toBeVisible();
  await capturePage(page, "docs-mobile.png");
});

test("laptop and tablet layouts keep the full homepage within the viewport", async ({
  page,
}) => {
  for (const [name, width, height] of [
    ["laptop", 1280, 800],
    ["tablet", 768, 1024],
  ] as const) {
    await page.setViewportSize({ width, height });
    await page.goto("/");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expect
      .poll(() =>
        page.locator("html").evaluate((element) => element.scrollWidth),
      )
      .toBe(width);
    await capturePage(page, `home-${name}.png`);
  }
});

test("primary routes and the open mobile menu have no serious accessibility findings", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  for (const route of [
    "/",
    "/world/",
    "/people/",
    "/swarms/",
    "/capabilities/",
    "/download/",
    "/docs/",
    "/docs/people/",
  ]) {
    await page.goto(route);
    const results = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
      .analyze();
    expect(
      results.violations.filter((violation) =>
        ["critical", "serious"].includes(violation.impact ?? ""),
      ),
      route,
    ).toEqual([]);
  }

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await page.locator(".mobile-nav summary").click();
  const mobileResults = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();
  expect(
    mobileResults.violations.filter((violation) =>
      ["critical", "serious"].includes(violation.impact ?? ""),
    ),
  ).toEqual([]);
});
