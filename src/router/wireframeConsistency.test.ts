// ワイヤーフレーム（wireframes.drawio）が実装のルート・主ナビと食い違っていないかを検査する。
// 画面を変える PR で drawio の更新を漏らしたことを npm test で気づけるようにするためのテスト
// （同時更新ルールの正本は docs/specs/1_requirements/repository-structure.md「汎用規約からの差分」）。
// 検査するのはページとルートの対応・主ナビの項目と順序・現在地まで。主ナビの順序は drawio の
// セル id の番号で取るため、id は正しいまま見た目の位置（x 座標）だけを入れ替えた図は検出しない。
import { describe, expect, it, vi } from "vitest";
import { mount } from "@vue/test-utils";
import AppHeader from "@/components/AppHeader.vue";
import { router } from "./index";
// ?raw で文字列として読み込む（Node の fs に頼らず、相対パスもビルドツールが解決する）。
import wireframeXml from "../../docs/specs/2_basic-design/wireframes.drawio?raw";

const routeState = vi.hoisted(() => ({ name: undefined as string | undefined }));
vi.mock("vue-router", async (importOriginal) => ({
  ...(await importOriginal<typeof import("vue-router")>()),
  useRoute: () => ({ name: routeState.name }),
}));

const PAGE_PREFIX = "wireframe-";
// drawio 上で「現在地」を示す強調色（#15803D）。生成時の規約で、他の主ナビ項目はグレーで描く。
// 色コードの大文字・小文字の表記ゆれで強調を見落とさないよう、小文字にそろえて比べる。
const ACTIVE_NAV_COLOR = "fontcolor=#15803d";

interface WireframePage {
  slug: string;
  navLabels: string[];
  activeLabels: string[];
}

// drawio は主ナビのアイコンを絵文字で代替表現しているため、先頭の記号を除いて実装の文言と比べる。
function normalizeLabel(label: string): string {
  return label.replace(/^[^\p{L}\p{N}]+/u, "").trim();
}

// id 末尾の番号（app-header-nav-3 や ll-app-header-nav-3、app-header-nav-3-2 の 3）で並べる。
function navOrder(id: string): number {
  const match = /app-header-nav-(\d+)/.exec(id);
  if (!match) throw new Error(`主ナビの id に番号がありません: ${id}`);
  return Number(match[1]);
}

function loadWireframePages(): WireframePage[] {
  const doc = new DOMParser().parseFromString(wireframeXml, "application/xml");
  const parseError = doc.querySelector("parsererror");
  if (parseError)
    throw new Error(`wireframes.drawio を XML として解析できません: ${parseError.textContent}`);

  return Array.from(doc.querySelectorAll("diagram")).map((diagram) => {
    const name = diagram.getAttribute("name") ?? "";
    const navCells = Array.from(diagram.querySelectorAll("mxCell"))
      .filter((cell) => (cell.getAttribute("id") ?? "").includes("app-header-nav-"))
      .sort((a, b) => navOrder(a.getAttribute("id")!) - navOrder(b.getAttribute("id")!));
    return {
      slug: name.startsWith(PAGE_PREFIX)
        ? name.slice(PAGE_PREFIX.length)
        : `（命名規則違反: ${name}）`,
      navLabels: navCells.map((cell) => normalizeLabel(cell.getAttribute("value") ?? "")),
      activeLabels: navCells
        .filter((cell) =>
          (cell.getAttribute("style") ?? "").toLowerCase().includes(ACTIVE_NAV_COLOR),
        )
        .map((cell) => normalizeLabel(cell.getAttribute("value") ?? "")),
    };
  });
}

function renderAppHeaderNav(routeName: string): { navLabels: string[]; activeLabel?: string } {
  routeState.name = routeName;
  const wrapper = mount(AppHeader, {
    global: { stubs: { RouterLink: { template: "<a><slot /></a>" } } },
  });
  try {
    const links = wrapper.findAll("nav a");
    return {
      navLabels: links.map((link) => link.text().trim()),
      activeLabel: links
        .find((link) => link.attributes("aria-current"))
        ?.text()
        .trim(),
    };
  } finally {
    wrapper.unmount();
  }
}

const pages = loadWireframePages();
const routes = router.getRoutes();
const routeNames = routes
  .map((route) => route.name)
  .filter((name): name is string => typeof name === "string");
// 名前の無いルートは wireframe-[ルート名] と対応づけられず、黙って検査から外れてしまう。
const unnamedRoutePaths = routes
  .filter((route) => typeof route.name !== "string")
  .map((route) => route.path);

// it.each が0件だと各ページの検査が1件も実行されないまま緑になるため、収集の時点で止める。
if (routeNames.length === 0 || pages.length === 0) {
  throw new Error(
    `検査対象がありません（ルート ${routeNames.length} 件、ワイヤーフレーム ${pages.length} ページ）`,
  );
}

describe("wireframes.drawio と実装の整合", () => {
  it("すべてのルートに名前があり、ワイヤーフレームと対応づけられる", () => {
    expect(unnamedRoutePaths, "name の無いルートのパス").toEqual([]);
  });

  it("wireframe-[ルート名] のページがルートと一対一で対応する", () => {
    const slugs = pages.map((page) => page.slug);
    // 件数だけの比較だと失敗時にどのページが原因か読めないため、過不足を名指しで出す。
    expect({
      ページが無いルート: routeNames.filter((name) => !slugs.includes(name)),
      ルートが無いページ: slugs.filter((slug) => !routeNames.includes(slug)),
      重複したページ: slugs.filter((slug, index) => slugs.indexOf(slug) !== index),
    }).toEqual({ ページが無いルート: [], ルートが無いページ: [], 重複したページ: [] });
  });

  it.each(routeNames)("wireframe-%s の主ナビが AppHeader の項目・順序と一致する", (routeName) => {
    const page = pages.find((item) => item.slug === routeName);
    expect(page, `wireframe-${routeName} のページがありません`).toBeDefined();
    const expected = renderAppHeaderNav(routeName).navLabels;
    expect(expected.length).toBeGreaterThan(0);
    expect(page!.navLabels, `wireframe-${routeName} の主ナビ`).toEqual(expected);
  });

  it.each(routeNames)(
    "wireframe-%s の現在地が AppHeader の aria-current と一致する",
    (routeName) => {
      const page = pages.find((item) => item.slug === routeName);
      expect(page, `wireframe-${routeName} のページがありません`).toBeDefined();
      const { activeLabel } = renderAppHeaderNav(routeName);
      expect(activeLabel, `${routeName} で AppHeader が現在地を示していません`).toBeDefined();
      expect(
        page!.activeLabels,
        `wireframe-${routeName} の現在地の強調（強調色 #15803D の主ナビ項目）`,
      ).toEqual([activeLabel]);
    },
  );
});
