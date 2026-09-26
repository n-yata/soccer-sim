import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import CupPage from "./CupPage.vue";
import { runCupSimulation } from "@/composables/cupSimulation";
import { formations } from "@/data/formations";
import { getMatchup } from "@/data/matchups";

const pushMock = vi.fn();
const backMock = vi.fn();
vi.mock("vue-router", () => ({
  useRouter: () => ({ push: pushMock, back: backMock }),
}));

const routerLinkStub = {
  props: ["to"],
  template: '<a :href="typeof to === \'string\' ? to : \'#\'"><slot /></a>',
};

describe("CupPage", () => {
  it("準々決勝・準決勝・決勝の見出しと、実データによる優勝フォーメーションが表示される", () => {
    const wrapper = mount(CupPage, { global: { stubs: { RouterLink: routerLinkStub } } });

    const titles = wrapper.findAll(".cup-page__round-title").map((el) => el.text());
    expect(titles).toEqual(["準々決勝", "準決勝", "決勝"]);

    const expected = runCupSimulation(formations, getMatchup);
    expect(wrapper.find(".cup-page__champion").text()).toContain(expected.championName);
  });

  it("各ラウンドの試合数が4/2/1件になる", () => {
    const wrapper = mount(CupPage, { global: { stubs: { RouterLink: routerLinkStub } } });
    const rounds = wrapper.findAll(".cup-page__round");
    expect(rounds[0].findAll("li")).toHaveLength(4); // 準々決勝
    expect(rounds[1].findAll("li")).toHaveLength(2); // 準決勝
    expect(rounds[2].findAll("li")).toHaveLength(1); // 決勝
  });

  // WCAG 1.4.1: 勝者の強調が色だけに依存しない
  it("勝者側にだけcup-page__winnerクラス・アイコン・「（勝者）」テキストが付与され、敗者側には付かない", () => {
    const wrapper = mount(CupPage, { global: { stubs: { RouterLink: routerLinkStub } } });
    const expected = runCupSimulation(formations, getMatchup);
    const firstMatch = expected.quarterfinals[0];

    const link = wrapper.findAllComponents(routerLinkStub)[0];
    // linkの直下のspan(A名・スコア・B名)のうち、A/Bチーム名を表示するのは1番目と3番目
    const linkElement = link.element as HTMLElement;
    const topLevelSpans = Array.from(linkElement.children).filter(
      (el): el is HTMLElement => el.tagName === "SPAN",
    );
    const spanA = topLevelSpans[0];
    const spanB = topLevelSpans[2];

    const aIsWinner = firstMatch.winnerId === firstMatch.formationAId;
    const [winnerEl, loserEl] = aIsWinner ? [spanA, spanB] : [spanB, spanA];

    expect(winnerEl.classList.contains("cup-page__winner")).toBe(true);
    expect(loserEl.classList.contains("cup-page__winner")).toBe(false);
    expect(winnerEl.textContent).toContain(
      aIsWinner ? firstMatch.formationAName : firstMatch.formationBName,
    );
    expect(winnerEl.querySelector(".cup-page__sr-only")?.textContent).toBe("（勝者）");
    expect(loserEl.querySelector(".cup-page__sr-only")).toBeNull();
  });

  it("各対戦カードから対応する比較画面へのリンクが張られる", () => {
    const wrapper = mount(CupPage, { global: { stubs: { RouterLink: routerLinkStub } } });
    const expected = runCupSimulation(formations, getMatchup);
    const firstMatch = expected.quarterfinals[0];

    const firstLink = wrapper.findAllComponents(routerLinkStub)[0];
    expect(firstLink.props("to")).toEqual({
      name: "comparison",
      params: { formationAId: firstMatch.formationAId, formationBId: firstMatch.formationBId },
    });
  });

  it("「← 戻る」をクリックするとrouter.pushが'/'で呼ばれる（履歴が無い場合）", async () => {
    const wrapper = mount(CupPage, { global: { stubs: { RouterLink: routerLinkStub } } });
    await wrapper.find(".cup-page__back-button").trigger("click");
    expect(pushMock).toHaveBeenCalledWith("/");
  });
});
