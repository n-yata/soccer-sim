import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import FormationMiniPitch from "./FormationMiniPitch.vue";
import type { Formation } from "@/types/formation";

const formation: Formation = {
  id: "4-4-2",
  name: "4-4-2",
  description: "",
  stats: { attack: 0, defense: 0, balance: 0, spaceControl: 0, pressIntensity: 0 },
  positions: [
    { id: "gk", type: "GK", label: "GK", x: 50, y: 5 },
    { id: "cb1", type: "DF", label: "CB", x: 35, y: 18 },
    { id: "cb2", type: "DF", label: "CB", x: 65, y: 18 },
    { id: "lb", type: "DF", label: "LB", x: 15, y: 20 },
    { id: "rb", type: "DF", label: "RB", x: 85, y: 20 },
    { id: "cm1", type: "MF", label: "CM", x: 35, y: 50 },
    { id: "cm2", type: "MF", label: "CM", x: 65, y: 50 },
    { id: "lm", type: "MF", label: "LM", x: 15, y: 55 },
    { id: "rm", type: "MF", label: "RM", x: 85, y: 55 },
    { id: "st1", type: "FW", label: "ST", x: 40, y: 85 },
    { id: "st2", type: "FW", label: "ST", x: 60, y: 85 },
  ],
};

describe("FormationMiniPitch", () => {
  it("全ポジション数分の円が描画される", () => {
    const wrapper = mount(FormationMiniPitch, { props: { formation } });
    expect(wrapper.findAll(".formation-mini-pitch__player")).toHaveLength(
      formation.positions.length,
    );
  });

  it("yが大きいポジションほどcyが小さい（攻撃方向が上になる）", () => {
    const wrapper = mount(FormationMiniPitch, { props: { formation } });
    const players = wrapper.findAll(".formation-mini-pitch__player");
    const gk = players[0];
    const striker = players[players.length - 1];
    expect(Number(gk.attributes("cy"))).toBeGreaterThan(Number(striker.attributes("cy")));
  });

  it("装飾専用のためaria-hidden=trueが付与される（アクセシブルネームはFormationCard側が担う）", () => {
    const wrapper = mount(FormationMiniPitch, { props: { formation } });
    expect(wrapper.attributes("aria-hidden")).toBe("true");
  });
});
