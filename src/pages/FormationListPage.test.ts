import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { nextTick } from "vue";
import type { Formation } from "@/types/formation";

const pushMock = vi.fn();
vi.mock("vue-router", () => ({
  useRouter: () => ({ push: pushMock }),
}));

const state = vi.hoisted(() => ({ formations: [] as Formation[] }));
vi.mock("@/data/formations", () => ({
  get formations() {
    return state.formations;
  },
}));

const { formations: realFormations } =
  await vi.importActual<typeof import("@/data/formations")>("@/data/formations");

const { default: FormationListPage } = await import("./FormationListPage.vue");
const { default: FormationCard } = await import("@/components/FormationCard.vue");

const routerLinkStub = {
  props: ["to"],
  template: '<a :href="to" @click.prevent><slot /></a>',
};

function mountPage() {
  return mount(FormationListPage, {
    global: { stubs: { RouterLink: routerLinkStub } },
  });
}

function findCard(wrapper: ReturnType<typeof mount>, id: string) {
  return wrapper.findAllComponents(FormationCard).find((card) => card.props("formation").id === id);
}

describe("FormationListPage", () => {
  beforeEach(() => {
    vi.stubEnv("VITE_JLEAGUE_URL", "https://example.com/fixtures/");
    pushMock.mockClear();
    state.formations = realFormations;
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });
  it("比較一覧に教材リンクを混在させない", () => {
    const wrapper = mountPage();
    expect(wrapper.findAll(".formation-list-page__learn")).toHaveLength(0);
    expect(wrapper.findAllComponents(FormationCard)).toHaveLength(realFormations.length);
    wrapper.unmount();
  });

  it("マウント時にformationsと同数のFormationCardが描画され、すべてselected=falseである", () => {
    const wrapper = mountPage();
    const cards = wrapper.findAllComponents(FormationCard);
    expect(cards).toHaveLength(realFormations.length);
    expect(cards.every((card) => card.props("selected") === false)).toBe(true);
  });

  it("1件目を選択すると、そのカードのみselected=trueになる", async () => {
    const wrapper = mountPage();
    await findCard(wrapper, "4-4-2")?.vm.$emit("select", "4-4-2");
    await nextTick();
    expect(findCard(wrapper, "4-4-2")?.props("selected")).toBe(true);
    expect(findCard(wrapper, "4-3-3")?.props("selected")).toBe(false);
  });

  it("選択した名前と残りの選択数を操作場所で知らせ、解除すると初期案内へ戻る", async () => {
    const wrapper = mountPage();
    expect(wrapper.find(".formation-list-page__selection-status").text()).toContain("あと2つ");
    await findCard(wrapper, "4-4-2")?.vm.$emit("select", "4-4-2");
    await nextTick();
    expect(wrapper.find(".formation-list-page__selection-status").text()).toContain("4-4-2");
    expect(wrapper.find(".formation-list-page__selection-status").text()).toContain("あと1つ");
    await findCard(wrapper, "4-4-2")?.vm.$emit("select", "4-4-2");
    await nextTick();
    expect(wrapper.find(".formation-list-page__selection-status").text()).toContain("あと2つ");
  });

  it("2件目を選択すると、選択順どおりrouter.pushが1回呼ばれる", async () => {
    const wrapper = mountPage();
    await findCard(wrapper, "4-4-2")?.vm.$emit("select", "4-4-2");
    await findCard(wrapper, "4-3-3")?.vm.$emit("select", "4-3-3");
    await nextTick();
    expect(pushMock).toHaveBeenCalledTimes(1);
    expect(pushMock).toHaveBeenCalledWith("/compare/4-4-2/4-3-3");
  });

  it("既に2件選択済みの状態で3件目を選択すると、最も古い選択が解除され新しい組み合わせで遷移する", async () => {
    const wrapper = mountPage();
    await findCard(wrapper, "4-4-2")?.vm.$emit("select", "4-4-2");
    await findCard(wrapper, "4-3-3")?.vm.$emit("select", "4-3-3");
    pushMock.mockClear();
    await findCard(wrapper, "4-2-3-1")?.vm.$emit("select", "4-2-3-1");
    await nextTick();
    expect(findCard(wrapper, "4-4-2")?.props("selected")).toBe(false);
    expect(findCard(wrapper, "4-3-3")?.props("selected")).toBe(true);
    expect(findCard(wrapper, "4-2-3-1")?.props("selected")).toBe(true);
    expect(pushMock).toHaveBeenCalledWith("/compare/4-3-3/4-2-3-1");
  });

  it("選択済みカードを再度選択すると選択解除され、router.pushは呼ばれない", async () => {
    const wrapper = mountPage();
    await findCard(wrapper, "4-4-2")?.vm.$emit("select", "4-4-2");
    await findCard(wrapper, "4-4-2")?.vm.$emit("select", "4-4-2");
    await nextTick();
    expect(findCard(wrapper, "4-4-2")?.props("selected")).toBe(false);
    expect(pushMock).not.toHaveBeenCalled();
  });

  it("formationsが空配列のとき、FormationCardは1件も描画されずエラーにならない", () => {
    state.formations = [];
    const wrapper = mountPage();
    expect(wrapper.findAllComponents(FormationCard)).toHaveLength(0);
  });

  it("Jリーグ外部リンクが新規タブでtarget=_blank・rel=noopener noreferrerを持つ", () => {
    const wrapper = mountPage();
    const link = wrapper.find("a.formation-list-page__jleague-link");
    expect(link.attributes("href")).toBe("https://example.com/fixtures/");
    expect(link.attributes("target")).toBe("_blank");
    expect(link.attributes("rel")).toBe("noopener noreferrer");
  });

  it.each([
    undefined,
    "",
    "   ",
    "not-a-url",
    "http://example.com/",
    "javascript:alert(1)",
    "https://user:password@example.com/",
  ])("外部リンクの設定が未設定・不正・安全でない場合は表示しない（%s）", (value) => {
    vi.stubEnv("VITE_JLEAGUE_URL", value);
    const wrapper = mountPage();
    expect(wrapper.find("a.formation-list-page__jleague-link").exists()).toBe(false);
    expect(wrapper.findAllComponents(FormationCard)).toHaveLength(realFormations.length);
    wrapper.unmount();
  });

  it("外部リンクの設定の前後空白を除いて利用する", () => {
    vi.stubEnv("VITE_JLEAGUE_URL", "  https://example.com/fixtures/  ");
    const wrapper = mountPage();
    expect(wrapper.find("a.formation-list-page__jleague-link").attributes("href")).toBe(
      "https://example.com/fixtures/",
    );
    wrapper.unmount();
  });

  // 一覧画面下部（フッター注記の近く）に置くと、カード枚数が多い環境でスクロールしないと
  // 気づけない配置になるため、ヘッダー内の他ナビゲーションと同列に固定する（2026-09-27修正）
  it("Jリーグ外部リンクがヘッダー内（page-header__actions配下）に配置され、本文下部には無い", () => {
    const wrapper = mountPage();
    const linkInHeader = wrapper.find(".page-header__actions a.formation-list-page__jleague-link");
    expect(linkInHeader.exists()).toBe(true);
    const linkInBody = wrapper.find(
      ".formation-list-page__body a.formation-list-page__jleague-link",
    );
    expect(linkInBody.exists()).toBe(false);
  });

  it("本文コンテナが広い画面幅を活かせるmax-widthを持つ（最大3列固定を廃止）", () => {
    const wrapper = mount(FormationListPage, {
      attachTo: document.body,
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    // UI/UXモダナイゼーションPhase3（レイアウトコンテナの統一）により、max-widthは
    // grid要素から親の.formation-list-page__bodyへ移動した（AppHeader/PageHeaderと
    // 左端を揃えるため、ヘッダー同様「外側で中央寄せ」する構造へ統一）。
    // 640px（旧上限。auto-fill+minmax(160px,1fr)では最大3列相当）のままだと
    // 広い画面でも列数が増えず、8種類のカードが縦に伸び続けてスクロールが増える、という
    // 元のテスト意図は、検証対象をbody要素に変えても同じ条件で検証できる。
    // jsdomはCSSカスタムプロパティを解決しないため、期待値は「正しいトークン参照を
    // 使っているか」で検証する（design.md「jsdomのCSS変数非解決によるテスト期待値の更新」参照）
    const body = wrapper.find(".formation-list-page__body");
    expect(getComputedStyle(body.element).maxWidth).toBe("var(--width-wide)");
    wrapper.unmount();
  });
});
