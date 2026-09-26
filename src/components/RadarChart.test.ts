import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import RadarChart from "./RadarChart.vue";
import type { RadarAxisMeta } from "@/data/radarAxes";
import type { FormationStats } from "@/types/formation";

const axes: RadarAxisMeta[] = [
  { id: "attack", label: "攻撃力", description: "" },
  { id: "defense", label: "守備力", description: "" },
  { id: "balance", label: "バランス", description: "" },
  { id: "spaceControl", label: "スペース支配力", description: "" },
  { id: "pressIntensity", label: "プレッシング強度", description: "" },
];

function makeStats(overrides: Partial<FormationStats> = {}): FormationStats {
  return {
    attack: 0,
    defense: 0,
    balance: 0,
    spaceControl: 0,
    pressIntensity: 0,
    ...overrides,
  };
}

describe("RadarChart", () => {
  // WCAG: 選手個体差・自由配置モードでの動的な値変化を、role="img"のaria-labelだけでなく
  // 別要素のrole="status"（aria-live="polite"）でスクリーンリーダーへ伝える。
  // role="img"のsvg自体にaria-liveを付けても、aria-label属性の変化が再通知される保証が
  // AT依存で信頼できないため、通知専用の別要素に分離している
  describe("動的な値変化のスクリーンリーダー通知（aria-live）", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("通知用のrole=status要素がaria-live=politeで設置される", () => {
      const wrapper = mount(RadarChart, {
        props: {
          axes,
          maxValue: 100,
          series: [{ label: "A", colorVar: "--color-team-a", values: makeStats() }],
        },
      });
      const status = wrapper.find('[role="status"]');
      expect(status.exists()).toBe(true);
      expect(status.attributes("aria-live")).toBe("polite");
    });

    it("svg(role=img)自体にはaria-liveを付けない（AT依存で再通知が信頼できないため）", () => {
      const wrapper = mount(RadarChart, {
        props: {
          axes,
          maxValue: 100,
          series: [{ label: "A", colorVar: "--color-team-a", values: makeStats() }],
        },
      });
      expect(wrapper.find("svg").attributes("aria-live")).toBeUndefined();
    });

    it("値の変化は即座に通知されず、一定時間変化が止まってから最新値が反映される（連続変更の読み上げ洪水を防ぐ）", async () => {
      const wrapper = mount(RadarChart, {
        props: {
          axes,
          maxValue: 100,
          series: [{ label: "A", colorVar: "--color-team-a", values: makeStats({ attack: 10 }) }],
        },
      });
      const statusBefore = wrapper.find('[role="status"]').text();
      expect(statusBefore).toContain("攻撃力10");

      await wrapper.setProps({
        series: [{ label: "A", colorVar: "--color-team-a", values: makeStats({ attack: 90 }) }],
      });
      // debounce時間が経過するまでは、まだ古い値のまま
      expect(wrapper.find('[role="status"]').text()).toContain("攻撃力10");

      vi.advanceTimersByTime(600);
      await wrapper.vm.$nextTick();

      expect(wrapper.find('[role="status"]').text()).toContain("攻撃力90");
    });

    it("debounce時間内に連続して値が変わっても、最終的な値だけが1回通知される", async () => {
      const wrapper = mount(RadarChart, {
        props: {
          axes,
          maxValue: 100,
          series: [{ label: "A", colorVar: "--color-team-a", values: makeStats({ attack: 10 }) }],
        },
      });

      for (const value of [20, 30, 40, 50]) {
        await wrapper.setProps({
          series: [{ label: "A", colorVar: "--color-team-a", values: makeStats({ attack: value }) }],
        });
        vi.advanceTimersByTime(100); // debounce(500ms)未満なので確定しない
      }
      expect(wrapper.find('[role="status"]').text()).toContain("攻撃力10");

      vi.advanceTimersByTime(500);
      await wrapper.vm.$nextTick();

      expect(wrapper.find('[role="status"]').text()).toContain("攻撃力50");
    });
  });

  it("軸数分のラベルが描画される", () => {
    const wrapper = mount(RadarChart, {
      props: {
        axes,
        maxValue: 100,
        series: [{ label: "A", colorVar: "--color-team-a", values: makeStats() }],
      },
    });
    const labels = wrapper.findAll(".radar-chart__axis-label").map((el) => el.text());
    expect(labels).toEqual(axes.map((axis) => axis.label));
  });

  it("系列数分のpolygonが描画される（A/Bの2系列）", () => {
    const wrapper = mount(RadarChart, {
      props: {
        axes,
        maxValue: 100,
        series: [
          { label: "A", colorVar: "--color-team-a", values: makeStats() },
          { label: "B", colorVar: "--color-team-b", values: makeStats() },
        ],
      },
    });
    expect(wrapper.findAll(".radar-chart__series")).toHaveLength(2);
    expect(wrapper.findAll(".radar-chart__vertex")).toHaveLength(axes.length * 2);
  });

  it("先頭軸(attack)でvalue=maxValueのとき、頂点は中心の真上distance=radius(70)の位置になる", () => {
    const wrapper = mount(RadarChart, {
      props: {
        axes,
        maxValue: 100,
        series: [
          { label: "A", colorVar: "--color-team-a", values: makeStats({ attack: 100 }) },
        ],
      },
    });
    const firstVertex = wrapper.findAll(".radar-chart__vertex")[0];
    expect(Number(firstVertex.attributes("cx"))).toBeCloseTo(100);
    expect(Number(firstVertex.attributes("cy"))).toBeCloseTo(30);
  });

  it("value=0のとき、頂点は中心(100,100)に一致する", () => {
    const wrapper = mount(RadarChart, {
      props: {
        axes,
        maxValue: 100,
        series: [{ label: "A", colorVar: "--color-team-a", values: makeStats() }],
      },
    });
    for (const vertex of wrapper.findAll(".radar-chart__vertex")) {
      expect(Number(vertex.attributes("cx"))).toBeCloseTo(100);
      expect(Number(vertex.attributes("cy"))).toBeCloseTo(100);
    }
  });

  it("maxValueが0のとき、頂点は全て中心(100,100)に一致する（0除算によるNaN・誤表示の防止）", () => {
    const wrapper = mount(RadarChart, {
      props: {
        axes,
        maxValue: 0,
        series: [{ label: "A", colorVar: "--color-team-a", values: makeStats({ attack: 50 }) }],
      },
    });
    for (const vertex of wrapper.findAll(".radar-chart__vertex")) {
      expect(Number(vertex.attributes("cx"))).toBeCloseTo(100);
      expect(Number(vertex.attributes("cy"))).toBeCloseTo(100);
    }
  });

  it("maxValueを超える値が渡されても、頂点はグリッド範囲内(半径70以内)に収まる", () => {
    const wrapper = mount(RadarChart, {
      props: {
        axes,
        maxValue: 100,
        series: [
          { label: "A", colorVar: "--color-team-a", values: makeStats({ attack: 999 }) },
        ],
      },
    });
    const firstVertex = wrapper.findAll(".radar-chart__vertex")[0];
    const distance = Math.hypot(
      Number(firstVertex.attributes("cx")) - 100,
      Number(firstVertex.attributes("cy")) - 100,
    );
    expect(distance).toBeLessThanOrEqual(70 + 0.01);
  });
});
