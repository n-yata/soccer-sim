import { describe, it, expect, vi, beforeEach } from "vitest";
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
  template: '<a :href="to"><slot /></a>',
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
    pushMock.mockClear();
    state.formations = realFormations;
  });

  it("マウント時にformationsと同数のFormationCardが描画され、すべてselected=falseである", () => {
    const wrapper = mountPage();
    const cards = wrapper.findAllComponents(FormationCard);
    expect(cards).toHaveLength(realFormations.length);
    expect(cards.every((card) => card.props("selected") === false)).toBe(true);
  });

  // 先頭の <a> を掴むとヘッダーにリンクが増えたとき別要素を検証したまま緑になるため、
  // クラスで名指しする
  it("用語集画面へのリンクが'/glossary'を指す", () => {
    const wrapper = mountPage();
    const link = wrapper.find("a.formation-list-page__glossary-link");
    expect(link.attributes("href")).toBe("/glossary");
  });

  it("理解度チェック画面へのリンクが'/quiz'を指す", () => {
    const wrapper = mountPage();
    const link = wrapper.find("a.formation-list-page__quiz-link");
    expect(link.attributes("href")).toBe("/quiz");
  });

  it("1件目を選択すると、そのカードのみselected=trueになる", async () => {
    const wrapper = mountPage();
    await findCard(wrapper, "4-4-2")?.vm.$emit("select", "4-4-2");
    await nextTick();
    expect(findCard(wrapper, "4-4-2")?.props("selected")).toBe(true);
    expect(findCard(wrapper, "4-3-3")?.props("selected")).toBe(false);
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
    expect(link.attributes("href")).toBe("https://www.jleague.jp/j1/special/");
    expect(link.attributes("target")).toBe("_blank");
    expect(link.attributes("rel")).toBe("noopener noreferrer");
  });

  it("「相性表を見る」ボタンをクリックするとrouter.pushが'/matrix'で1回呼ばれる", async () => {
    const wrapper = mountPage();
    const button = wrapper
      .findAll("button")
      .find((b) => b.text() === "相性表を見る");
    expect(button).toBeDefined();
    await button?.trigger("click");
    expect(pushMock).toHaveBeenCalledTimes(1);
    expect(pushMock).toHaveBeenCalledWith("/matrix");
  });
});
