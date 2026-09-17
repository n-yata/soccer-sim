import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import FormationCard from "./FormationCard.vue";
import type { Formation } from "@/types/formation";

const formation: Formation = {
  id: "4-4-2",
  name: "4-4-2",
  description: "DF4人・MF4人・FW2人の伝統的なバランス型フォーメーション。",
  positions: [
    { id: "gk", type: "GK", label: "GK", x: 50, y: 5 },
    { id: "cb1", type: "DF", label: "CB", x: 35, y: 18 },
  ],
  stats: { attack: 0, defense: 0, balance: 0, spaceControl: 0, pressIntensity: 0 },
};

describe("FormationCard", () => {
  it("selected=falseのとき、名称・説明文が表示され強調表示クラスが付与されない", () => {
    const wrapper = mount(FormationCard, {
      props: { formation, selected: false },
    });
    expect(wrapper.text()).toContain("4-4-2");
    expect(wrapper.text()).toContain("伝統的なバランス型フォーメーション");
    expect(wrapper.classes()).not.toContain("selected");
  });

  it("selected=falseのとき、ミニピッチ図に全ポジション分の円が描画される", () => {
    const wrapper = mount(FormationCard, {
      props: { formation, selected: false },
    });
    expect(wrapper.findAll(".formation-mini-pitch__player")).toHaveLength(
      formation.positions.length,
    );
  });

  it("selected=trueのとき、強調表示クラスが付与され選択中バッジが表示される", () => {
    const wrapper = mount(FormationCard, {
      props: { formation, selected: true },
    });
    expect(wrapper.classes()).toContain("selected");
    expect(wrapper.text()).toContain("選択中");
  });

  it("selected=falseのとき、選択中バッジは表示されない", () => {
    const wrapper = mount(FormationCard, {
      props: { formation, selected: false },
    });
    expect(wrapper.text()).not.toContain("選択中");
  });

  it("クリックするとformation.idを引数にselectイベントが1回emitされる", async () => {
    const wrapper = mount(FormationCard, {
      props: { formation, selected: false },
    });
    await wrapper.trigger("click");
    expect(wrapper.emitted("select")).toHaveLength(1);
    expect(wrapper.emitted("select")?.[0]).toEqual(["4-4-2"]);
  });
});
