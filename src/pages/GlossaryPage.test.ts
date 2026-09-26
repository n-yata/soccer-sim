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
});
