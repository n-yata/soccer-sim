import { clamp, mulberry32 } from "@/composables/matchSimulation";
import type { FormationStats, RadarAxisId } from "@/types/formation";

const AXES: readonly RadarAxisId[] = ["attack", "defense", "balance", "spaceControl", "pressIntensity"];
const VARIANCE_RATIO = 0.1; // ±10%
const STAT_MIN = 0;
const STAT_MAX = 100;

/**
 * 選手個体差（スカッドコンディション）: フォーメーションの5軸statsに、シードから
 * 決定的に導出した小さな乱数変動（±10%）を加えた実効statsを返す純粋関数。
 *
 * 影響範囲は呼び出し側（ComparisonPage.vue）が simulateMatch に渡すFormationのstatsに
 * 限定する設計とする。この関数自体はマッチアップ判定・タグ導出を一切呼ばない
 * （レーダーチャート・優位ポイントの表示には使わないこと。design.md「実装対象の機能」参照）。
 *
 * 同じstats・同じseedを渡せば常に同じ結果になる（決定性）。シードの生成方法（乱数を
 * 引くタイミング）はUI層の責務であり、この関数は「シード→実効stats」に専念する。
 */
export function applySquadVariance(stats: FormationStats, seed: number): FormationStats {
  const random = mulberry32(seed);
  const result = {} as FormationStats;
  for (const axis of AXES) {
    const factor = 1 + (random() * 2 - 1) * VARIANCE_RATIO;
    result[axis] = clamp(Math.round(stats[axis] * factor), STAT_MIN, STAT_MAX);
  }
  return result;
}
