import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import type { SoccerTerm } from "@/types/formation";

const state = vi.hoisted(() => ({ soccerTerms: [] as SoccerTerm[] }));
vi.mock("@/data/soccerTerms", () => ({
  get soccerTerms() {
    return state.soccerTerms;
  },
}));

const { soccerTerms: realTerms } =
  await vi.importActual<typeof import("@/data/soccerTerms")>("@/data/soccerTerms");

const { default: GlossaryPage } = await import("./GlossaryPage.vue");

const routerLinkStub = {
  props: ["to"],
  template: '<a :href="to"><slot /></a>',
};

describe("GlossaryPage", () => {
  it("soccerTermsの全件が描画される", () => {
    state.soccerTerms = realTerms;
    const wrapper = mount(GlossaryPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    for (const term of realTerms) {
      expect(wrapper.text()).toContain(term.term);
      expect(wrapper.text()).toContain(term.description);
    }
  });

  it("データが空配列でも描画が落ちない", () => {
    state.soccerTerms = [];
    const wrapper = mount(GlossaryPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    expect(wrapper.findAll("dt")).toHaveLength(0);
  });

  it("一覧画面へのリンクが'/'を指す", () => {
    state.soccerTerms = realTerms;
    const wrapper = mount(GlossaryPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const link = wrapper.find("a");
    expect(link.attributes("href")).toBe("/");
  });
});
