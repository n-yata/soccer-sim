import { describe, it, expect } from "vitest";
import { applySquadVariance } from "./squadCondition";
import type { FormationStats } from "@/types/formation";

const BASE_STATS: FormationStats = {
  attack: 50,
  defense: 50,
  balance: 50,
  spaceControl: 50,
  pressIntensity: 50,
};

describe("applySquadVariance", () => {
  it("全軸が元の値の90%〜110%の範囲（0-100にクランプ）に収まる", () => {
    for (let seed = 0; seed < 50; seed += 1) {
      const result = applySquadVariance(BASE_STATS, seed);
      for (const axis of Object.keys(BASE_STATS) as (keyof FormationStats)[]) {
        expect(result[axis]).toBeGreaterThanOrEqual(45);
        expect(result[axis]).toBeLessThanOrEqual(55);
      }
    }
  });

  it("0-100の範囲にクランプされる（極端な入力値でも超過しない）", () => {
    const extreme: FormationStats = { attack: 100, defense: 0, balance: 100, spaceControl: 0, pressIntensity: 100 };
    for (let seed = 0; seed < 20; seed += 1) {
      const result = applySquadVariance(extreme, seed);
      for (const axis of Object.keys(extreme) as (keyof FormationStats)[]) {
        expect(result[axis]).toBeGreaterThanOrEqual(0);
        expect(result[axis]).toBeLessThanOrEqual(100);
      }
    }
  });

  it("決定性: 同じstats・同じseedなら常に同じ結果になる", () => {
    const first = applySquadVariance(BASE_STATS, 12345);
    const second = applySquadVariance(BASE_STATS, 12345);
    expect(second).toEqual(first);
  });

  it("異なるseedでは異なる結果になりうる（複数シードの結果が全て同一にはならない）", () => {
    const results = Array.from({ length: 10 }, (_, seed) => applySquadVariance(BASE_STATS, seed));
    const unique = new Set(results.map((r) => JSON.stringify(r)));
    expect(unique.size).toBeGreaterThan(1);
  });

  it("元のstatsオブジェクトを変更しない（イミュータブル）", () => {
    const original = { ...BASE_STATS };
    applySquadVariance(BASE_STATS, 999);
    expect(BASE_STATS).toEqual(original);
  });
});
