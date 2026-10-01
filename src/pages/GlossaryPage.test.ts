import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import type { SoccerTerm } from "@/types/formation";

const state = vi.hoisted(() => ({ soccerTerms: [] as SoccerTerm[] }));
vi.mock("@/data/soccerTerms", () => ({
  get soccerTerms() {
    return state.soccerTerms;
  },
}));

// GlossaryPageはPageHeader経由でBackButtonを描画する。BackButtonがuseRouter()を呼ぶため、
// vue-routerをモックする（QuizPage.test.ts等と同じパターン）
const pushMock = vi.fn();
const backMock = vi.fn();

vi.mock("vue-router", () => ({
  useRouter: () => ({ push: pushMock, back: backMock }),
}));

const { soccerTerms: realTerms } =
  await vi.importActual<typeof import("@/data/soccerTerms")>("@/data/soccerTerms");

const { default: GlossaryPage } = await import("./GlossaryPage.vue");

describe("GlossaryPage", () => {
  beforeEach(() => {
    pushMock.mockClear();
    backMock.mockClear();
  });

  it("soccerTermsの全件が描画される", () => {
    state.soccerTerms = realTerms;
    const wrapper = mount(GlossaryPage);
    for (const term of realTerms) {
      expect(wrapper.text()).toContain(term.term);
      expect(wrapper.text()).toContain(term.description);
    }
  });

  it("データが空配列でも描画が落ちない", () => {
    state.soccerTerms = [];
    const wrapper = mount(GlossaryPage);
    expect(wrapper.findAll("dt")).toHaveLength(0);
  });

  it("用語名で検索して対象だけを表示し、検索を消すと全件に戻る", async () => {
    state.soccerTerms = realTerms;
    const wrapper = mount(GlossaryPage);
    const term = realTerms[0];
    const search = wrapper.find<HTMLInputElement>(".glossary-page__search-input");
    await search.setValue(term.term);
    const expectedTerms = realTerms.filter((entry) =>
      `${entry.term} ${entry.description}`.includes(term.term),
    );
    expect(wrapper.findAll("dt").map((entry) => entry.text())).toEqual(
      expectedTerms.map((entry) => entry.term),
    );
    await wrapper.find(".glossary-page__clear-search").trigger("click");
    expect(wrapper.findAll("dt")).toHaveLength(realTerms.length);
  });

  it("用語名に含まれない説明の語句でも検索できる", async () => {
    state.soccerTerms = realTerms;
    const wrapper = mount(GlossaryPage);
    await wrapper.find(".glossary-page__search-input").setValue("体を張って止める");
    expect(wrapper.findAll("dt").map((entry) => entry.text())).toEqual(["センターバック"]);
    wrapper.unmount();
  });

  it("検索語の前後空白と英字の大小を無視し、空白だけなら全件を表示する", async () => {
    state.soccerTerms = realTerms;
    const wrapper = mount(GlossaryPage);
    await wrapper.find(".glossary-page__search-input").setValue("  mf  ");
    expect(wrapper.findAll("dt").map((entry) => entry.text())).toEqual(["守備的MF", "攻撃的MF"]);
    await wrapper.find(".glossary-page__search-input").setValue("   ");
    expect(wrapper.findAll("dt")).toHaveLength(realTerms.length);
    wrapper.unmount();
  });

  it("一致しない検索語では空状態を示し、検索解除で復帰できる", async () => {
    state.soccerTerms = realTerms;
    const wrapper = mount(GlossaryPage);
    await wrapper.find(".glossary-page__search-input").setValue("該当しない用語XYZ");
    expect(wrapper.findAll("dt")).toHaveLength(0);
    expect(wrapper.find(".glossary-page__empty").text()).toContain("見つかりません");
    await wrapper.find(".glossary-page__clear-search").trigger("click");
    expect(wrapper.findAll("dt")).toHaveLength(realTerms.length);
  });

  it("検索解除後に入力欄へフォーカスを戻し、続けて検索できる", async () => {
    state.soccerTerms = realTerms;
    const wrapper = mount(GlossaryPage, { attachTo: document.body });
    try {
      await wrapper.find(".glossary-page__search-input").setValue("存在しない用語");
      await wrapper.find(".glossary-page__clear-search").trigger("click");
      expect(document.activeElement).toBe(wrapper.find(".glossary-page__search-input").element);
      expect(wrapper.findAll("dt")).toHaveLength(realTerms.length);
    } finally {
      wrapper.unmount();
    }
  });

  it("「← 戻る」をクリックするとrouter.pushが'/'で1回呼ばれる（履歴が無い場合）", async () => {
    window.history.replaceState({}, "");
    state.soccerTerms = realTerms;
    const wrapper = mount(GlossaryPage);
    await wrapper.find(".back-button").trigger("click");
    expect(pushMock).toHaveBeenCalledTimes(1);
    expect(pushMock).toHaveBeenCalledWith("/");
    expect(backMock).not.toHaveBeenCalled();
  });

  it("アプリ内遷移の履歴がある場合、「← 戻る」は履歴を1つ戻る", async () => {
    window.history.replaceState({ back: "/" }, "");
    state.soccerTerms = realTerms;
    const wrapper = mount(GlossaryPage);
    await wrapper.find(".back-button").trigger("click");
    expect(backMock).toHaveBeenCalledTimes(1);
    expect(pushMock).not.toHaveBeenCalled();
  });

  it("広い画面幅では用語リストが2カラムに段組みされる", () => {
    // このテストはCSSOM（スタイルシートに登録されたルール）だけを検査するため、
    // コンポーネントをDOMへマウントする必要はない（GlossaryPage.vueは冒頭で
    // 静的importされておりstyleは既に読み込み時点で登録済み。vite.config.tsの
    // test.css:trueにより実CSSがjsdomへ適用される）
    //
    // jsdomは@mediaをgetComputedStyleへ反映しないため、スタイルシートに登録された
    // 実際のCSSOMルールを直接検査する（ComparisonPage.test.tsのflex-wrap検証とは異なり、
    // 本ケースはメディアクエリ配下のためgetComputedStyle経由では検証できない）
    const normalize = (text: string) => text.replace(/\s+/g, " ").trim();
    const hasTwoColumnRule = Array.from(document.styleSheets).some((sheet) => {
      let rules: CSSRuleList;
      try {
        rules = sheet.cssRules;
      } catch {
        return false;
      }
      return Array.from(rules).some(
        (rule) =>
          rule instanceof CSSMediaRule &&
          // UI/UXモダナイゼーションPhase3（ブレークポイントの統一）により、769pxから
          // 901px（mobile640px/tablet900pxの2値に統一したうえでの「tablet超」の意）へ変更
          normalize(rule.conditionText).includes("min-width: 901px") &&
          Array.from(rule.cssRules).some((inner) => {
            if (!(inner instanceof CSSStyleRule)) return false;
            if (!inner.selectorText.includes("glossary-page__list")) return false;
            // `columns`はショートハンド（column-width + column-count）のため、
            // ブラウザによって "2" / "auto 2" 等シリアライズが異なりうる。
            // column-count・columnsのいずれかに列数"2"が含まれるかで判定する
            const columns = inner.style.getPropertyValue("columns");
            const columnCount = inner.style.getPropertyValue("column-count");
            return columns.split(/\s+/).includes("2") || columnCount === "2";
          }),
      );
    });
    expect(hasTwoColumnRule).toBe(true);
  });
});
