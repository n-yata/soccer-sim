import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import ComparisonControls from "./ComparisonControls.vue";
import type { Formation } from "@/types/formation";

const formations: Formation[] = [
  {
    id: "4-4-2",
    name: "4-4-2",
    description: "",
    positions: [],
    stats: { attack: 0, defense: 0, balance: 0, spaceControl: 0, pressIntensity: 0 },
  },
  {
    id: "4-3-3",
    name: "4-3-3",
    description: "",
    positions: [],
    stats: { attack: 0, defense: 0, balance: 0, spaceControl: 0, pressIntensity: 0 },
  },
  {
    id: "4-2-3-1",
    name: "4-2-3-1",
    description: "",
    positions: [],
    stats: { attack: 0, defense: 0, balance: 0, spaceControl: 0, pressIntensity: 0 },
  },
];

describe("ComparisonControls", () => {
  it("入れ替えボタンをクリックするとswapイベントが1回emitされる", async () => {
    const wrapper = mount(ComparisonControls, {
      props: { formations, formationAId: "4-4-2", formationBId: "4-3-3" },
    });
    await wrapper.find(".comparison-controls__swap-button").trigger("click");
    expect(wrapper.emitted("swap")).toHaveLength(1);
  });

  it("青チームセレクトを変更すると、選択したidを引数にselect-aがemitされる", async () => {
    const wrapper = mount(ComparisonControls, {
      props: { formations, formationAId: "4-4-2", formationBId: "4-3-3" },
    });
    // "4-3-3"（formationBId側）はdisabledのため、選択可能な"4-2-3-1"を選ぶ
    await wrapper.find("#comparison-select-a").setValue("4-2-3-1");
    expect(wrapper.emitted("select-a")?.[0]).toEqual(["4-2-3-1"]);
  });

  it("赤チームセレクトを変更すると、選択したidを引数にselect-bがemitされる", async () => {
    const wrapper = mount(ComparisonControls, {
      props: { formations, formationAId: "4-4-2", formationBId: "4-3-3" },
    });
    // "4-4-2"（formationAId側）はdisabledのため、選択可能な"4-2-3-1"を選ぶ
    await wrapper.find("#comparison-select-b").setValue("4-2-3-1");
    expect(wrapper.emitted("select-b")?.[0]).toEqual(["4-2-3-1"]);
  });

  it("相手側に選択済みのフォーメーションのoptionがdisabledになる", () => {
    const wrapper = mount(ComparisonControls, {
      props: { formations, formationAId: "4-4-2", formationBId: "4-3-3" },
    });
    const optionsA = wrapper.find("#comparison-select-a").findAll("option");
    const disabledInA = optionsA.find((option) => option.attributes("value") === "4-3-3");
    expect(disabledInA?.attributes("disabled")).toBeDefined();

    const optionsB = wrapper.find("#comparison-select-b").findAll("option");
    const disabledInB = optionsB.find((option) => option.attributes("value") === "4-4-2");
    expect(disabledInB?.attributes("disabled")).toBeDefined();
  });
});
