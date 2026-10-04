import { chromium } from "playwright";
import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import process from "node:process";
import { fileURLToPath } from "node:url";

const base = process.argv[2];
assert.ok(base, "Preview URL is required");
const output = new URL("./screenshots/", import.meta.url);
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ channel: "msedge", headless: true });
const results = [];
try {
  for (const width of [390, 768, 900, 901, 1280]) {
    const page = await browser.newPage({ viewport: { width, height: 900 }, reducedMotion: "reduce" });
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    const paths = ["", "learn", "matrix", "board", "quiz", "glossary", "compare/4-4-2/4-3-3"];
    for (const path of paths) {
      await page.goto(new URL(path, base).href);
      await page.locator("h1").waitFor();
      const dimensions = await page.evaluate(() => ({
        viewport: document.documentElement.clientWidth,
        content: document.documentElement.scrollWidth,
      }));
      assert.ok(dimensions.content <= dimensions.viewport, `${width}px ${path}: horizontal overflow ${JSON.stringify(dimensions)}`);
      await page.screenshot({ path: fileURLToPath(new URL(`${width}-${path.split("/")[0] || "home"}.png`, output)), fullPage: true });
      results.push({ width, page: path || "home", ...dimensions });
    }
    await page.goto(base);
    const first = page.locator('[data-formation-id="4-4-2"]');
    await first.click();
    const clear = page.getByRole("button", { name: "選択を解除", exact: true });
    await clear.click();
    assert.equal(await first.getAttribute("aria-pressed"), "false");
    assert.ok(await first.evaluate((element) => element === document.activeElement), "Selection clear restores focus");
    if (width <= 900) {
      const menu = page.getByRole("button", { name: "メニュー", exact: true });
      await menu.click();
      await page.screenshot({ path: fileURLToPath(new URL(`${width}-menu.png`, output)) });
      await page.keyboard.press("Escape");
      assert.equal(await menu.getAttribute("aria-expanded"), "false");
      assert.ok(await menu.evaluate((element) => element === document.activeElement));
    }
    await first.click();
    await page.locator('[data-formation-id="4-3-3"]').click();
    await page.waitForURL("**/compare/4-4-2/4-3-3");
    assert.deepEqual(errors, [], "No browser runtime errors");
    await page.close();
  }
  await writeFile(new URL("./display-results.json", import.meta.url), JSON.stringify(results, null, 2));
  process.stdout.write(`Verified ${results.length} page/viewport combinations, selection/clear/compare, Escape/focus, no runtime errors.\n`);
} finally {
  await browser.close();
}
