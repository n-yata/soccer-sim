import { describe, it, expect } from "vitest";
import { estimateStats } from "./radarScoreEstimator";
import type { FormationStats, FormationTag } from "@/types/formation";

const baseStats: FormationStats = {
  attack: 50,
  defense: 50,
  balance: 50,
  spaceControl: 50,
  pressIntensity: 50,
};

describe("estimateStats", () => {
  it("タグ構成に変化が無ければbaseStatsと完全一致する", () => {
    const tags = ["4バック", "2トップ", "中盤フラット4枚"] as const;
    expect(estimateStats([...tags], [...tags], baseStats)).toEqual(baseStats);
  });

  it("タグが新たに立つと、対応する軸が加減算テーブル通りに増減する", () => {
    // "5バック" は defense +10 / attack -10
    const original = ["4バック"] as const;
    const current = ["5バック"] as const;
    const result = estimateStats([...current], [...original], baseStats);
    expect(result.defense).toBe(60);
    expect(result.attack).toBe(40);
    // 関与しない軸は変化しない
    expect(result.balance).toBe(50);
    expect(result.spaceControl).toBe(50);
    expect(result.pressIntensity).toBe(50);
  });

  it("タグが消えると、加減算が逆方向に適用される", () => {
    // "5バック" が消える(=元は持っていた)場合は defense -10 / attack +10
    const original = ["5バック"] as const;
    const current: FormationTag[] = [];
    const result = estimateStats(current, [...original], baseStats);
    expect(result.defense).toBe(40);
    expect(result.attack).toBe(60);
  });

  it("上限を超える加算はクランプされる(100)", () => {
    const highBase: FormationStats = { ...baseStats, defense: 95 };
    // "5バック"追加(+10) + "守備的MF2枚"追加(+5) = +15 のはずが100でクランプ
    const current = ["5バック", "守備的MF2枚"] as const;
    const result = estimateStats([...current], [], highBase);
    expect(result.defense).toBe(100);
  });

  it("下限を下回る減算はクランプされる(0)", () => {
    const lowBase: FormationStats = { ...baseStats, attack: 5 };
    // "5バック"追加(-10) + "3トップ"が消える(-10) = -20のはずが0でクランプ
    const original = ["3トップ"] as const;
    const current = ["5バック"] as const;
    const result = estimateStats([...current], [...original], lowBase);
    expect(result.attack).toBe(0);
  });
});
