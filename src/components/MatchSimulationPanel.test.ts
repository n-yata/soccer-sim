import { describe, expect, it } from "vitest";
import { mount } from "@vue/test-utils";
import MatchSimulationPanel from "@/components/MatchSimulationPanel.vue";
import type { MatchSimulationResult } from "@/types/formation";

const sampleResult: MatchSimulationResult = {
  possession: { a: 59, b: 41 },
  shots: { a: 12, b: 4 },
  shotsOnTarget: { a: 5, b: 2 },
  score: { a: 3, b: 1 },
  timeline: [
    { minute: 16, team: "A", kind: "goal", text: "4-2-3-1が先制点を奪う" },
    { minute: 38, team: "B", kind: "goal", text: "4-4-2が同点に追いつく" },
    { minute: 56, team: "A", kind: "goal", text: "4-2-3-1が勝ち越しゴールを決める" },
  ],
  summary: "4-2-3-1が3-1で4-4-2を下した。ボール保持率59%で試合を支配しきった試合だった。",
};

function mountPanel(result: MatchSimulationResult = sampleResult) {
  return mount(MatchSimulationPanel, {
    props: { result, formationAName: "4-2-3-1", formationBName: "4-4-2" },
  });
}

describe("MatchSimulationPanel", () => {
  it("スコアボードにチーム名とスコアを表示する", () => {
    const wrapper = mountPanel();
    expect(wrapper.find(".match-simulation-panel__score").text()).toBe("3 - 1");
    expect(wrapper.text()).toContain("4-2-3-1");
    expect(wrapper.text()).toContain("4-4-2");
  });

  it("ポゼッションバーの幅がpropsの値に応じて設定される", () => {
    const wrapper = mountPanel();
    const segments = wrapper.findAll(".match-simulation-panel__possession-segment");
    expect(segments).toHaveLength(2);
    expect((segments[0].element as HTMLElement).style.width).toBe("59%");
    expect((segments[1].element as HTMLElement).style.width).toBe("41%");
  });

  it("シュート・枠内シュートの数値を表示する", () => {
    const wrapper = mountPanel();
    const rows = wrapper.findAll(".match-simulation-panel__shot-row");
    expect(rows[0].text()).toContain("12");
    expect(rows[0].text()).toContain("4");
    expect(rows[1].text()).toContain("5");
    expect(rows[1].text()).toContain("2");
  });

  it("タイムラインの全イベントを分昇順のまま表示する", () => {
    const wrapper = mountPanel();
    const events = wrapper.findAll(".match-simulation-panel__event");
    expect(events).toHaveLength(3);
    expect(events[0].text()).toContain("16分");
    expect(events[0].text()).toContain("先制点");
    expect(events[2].text()).toContain("56分");
  });

  it("タイムラインが空の場合は代替メッセージを表示する", () => {
    const wrapper = mountPanel({ ...sampleResult, timeline: [] });
    expect(wrapper.find(".match-simulation-panel__event-empty").exists()).toBe(true);
  });

  it("サマリー文を表示する", () => {
    const wrapper = mountPanel();
    expect(wrapper.find(".match-simulation-panel__summary").text()).toContain(
      "4-2-3-1が3-1で4-4-2を下した",
    );
  });
});
