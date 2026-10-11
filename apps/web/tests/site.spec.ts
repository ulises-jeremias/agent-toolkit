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
  const imageCount = await page.locator("img").count();
  await expect
    .poll(() =>
      page.locator("img").evaluateAll(
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

test("home explains the product and uses the real world capture", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Your AI agents finally have a place to work.",
  );
  await expect(page.getByAltText(/actual pixel valley/i)).toBeVisible();
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute(
    "href",
    "https://agent-toolkit.io/",
  );
  await expect(page.locator('meta[property="og:image"]')).toHaveAttribute(
    "content",
    /agent-toolkit\.io\/screenshots\/world\.png/,
  );
  await expect(page.locator('img[fetchpriority="high"]')).toHaveJSProperty(
    "naturalWidth",
    1920,
  );
  await capturePage(page, "home-desktop.png");
});

test("the world, People and Swarms show semantic product evidence", async ({
  page,
}) => {
  await page.goto("/world/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "The world is the workspace.",
  );
  await expect(page.getByText("Memory", { exact: true })).toBeVisible();
  await page.goto("/people/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText(
    "Configure a collaborator once",
  );
  await expect(
    page.getByAltText(/only while their real PTY session is running/i),
  ).toBeVisible();
  await page.goto("/swarms/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText(
    "Give a team one task",
  );
  await expect(page.getByAltText(/Swarm start review/i)).toBeVisible();
  await capturePage(page, "swarms-desktop.png");
  await page.goto("/people/");
  await capturePage(page, "people-desktop.png");
  await page.goto("/world/");
  await capturePage(page, "world-desktop.png");
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
  await search.fill("mcp-audit");
  await expect(page.locator(".capability-item:visible")).toHaveCount(1);
  await expect(page.locator(".capability-item:visible")).toContainText(
    "MCP config",
  );
  await expect(page.locator("#capability-count")).toContainText("1 of");
  await search.fill("nothing matches this exact phrase");
  await expect(page.getByText(/no catalog entries match/i)).toBeVisible();
  await capturePage(page, "capabilities-desktop.png");
});

test("download page reflects real release assets and keeps a no-script fallback", async ({
  page,
}) => {
  await page.route(
    "https://api.github.com/repos/ulises-jeremias/agent-toolkit/releases/latest",
    async (route) => {
      await route.fulfill({
        json: {
          tag_name: "v1.44.0",
          html_url:
            "https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.44.0",
          assets: [
            {
              name: "agent-toolkit-desktop-1.44.0-linux-x86_64.AppImage",
              browser_download_url: "https://github.com/example/linux.AppImage",
            },
            {
              name: "agent-toolkit-desktop-1.44.0-linux-x86_64.deb",
              browser_download_url: "https://github.com/example/linux.deb",
            },
            {
              name: "agent-toolkit-desktop-1.44.0-linux-arm64.AppImage",
              browser_download_url: "https://github.com/example/arm.AppImage",
            },
            {
              name: "agent-toolkit-desktop-1.44.0-mac-arm64.dmg",
              browser_download_url: "https://github.com/example/mac-arm.dmg",
            },
            {
              name: "agent-toolkit-desktop-1.44.0-mac-x64.dmg",
              browser_download_url: "https://github.com/example/mac-x64.dmg",
            },
            {
              name: "agent-toolkit-desktop-1.44.0-win-x64.exe",
              browser_download_url: "https://github.com/example/win.exe",
            },
          ],
        },
      });
    },
  );
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/download/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText(
    "Bring the valley",
  );
  await expect(page.locator("#release-status")).toContainText("v1.44.0");
  await expect(page.locator(".release-assets .download-option")).toHaveCount(5);
  await page.getByRole("link", { name: "macOS", exact: true }).click();
  await expect(
    page.locator(".release-assets .download-option:visible"),
  ).toHaveCount(2);
  await expect(page.locator(".cli-command")).toContainText(
    "uv tool install agent-toolkit-cli",
  );
  await page.goto("/download/");
  await expect(page.locator("#release-status")).toContainText("v1.44.0");
  await capturePage(page, "download-desktop.png");
});

test("download page keeps its official release link when GitHub is unavailable", async ({
  page,
}) => {
  await page.route(
    "https://api.github.com/repos/ulises-jeremias/agent-toolkit/releases/latest",
    (route) => route.abort(),
  );
  await page.goto("/download/");
  await expect(page.locator("#release-status")).toContainText("could not load");
  await expect(
    page.getByRole("link", { name: /open latest release/i }),
  ).toHaveAttribute(
    "href",
    "https://github.com/ulises-jeremias/agent-toolkit/releases/latest",
  );
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
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("People");
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

test("mobile navigation, touch layout and reduced motion remain usable", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
  await expect
    .poll(() => page.locator("html").evaluate((element) => element.scrollWidth))
    .toBe(390);
  await page.locator(".mobile-nav summary").click();
  await expect(
    page
      .getByRole("navigation", { name: "Mobile navigation" })
      .getByRole("link", { name: "The World" }),
  ).toBeVisible();
  await capturePage(page, "mobile-nav-open.png");
  await page
    .getByRole("navigation", { name: "Mobile navigation" })
    .getByRole("link", { name: "People" })
    .click();
  await expect(page).toHaveURL("/people/");
  await capturePage(page, "people-mobile.png");
  await page.emulateMedia({ reducedMotion: "reduce" });
  await expect
    .poll(() => page.locator("html").evaluate((element) => element.scrollWidth))
    .toBe(390);
  await page.goto("/docs/people/");
  await expect(page.locator(".docs-sidebar a").first()).toBeVisible();
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
