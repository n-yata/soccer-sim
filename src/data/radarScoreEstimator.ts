import type { FormationTag, FormationStats, RadarAxisId } from "@/types/formation";

// --- タグ→軸の加減算テーブル ---------------------------------------------------
// 自由配置モードでドラッグにより新たに立った/消えたタグの差分だけに適用する暫定値。
// 「タグが立つと素点として何点変動するか」の定性的な目安であり、厳密な戦術理論の
// 数値化ではない（開発者本人によるレビュー前提の未決事項。functional-overview.md参照）。
// 1つのタグが複数軸に影響してよいが、二重計上を避けるため estimateStats 側で
// 軸ごとに合計してから一度だけクランプする。
const TAG_SCORE_DELTA: Partial<Record<FormationTag, Partial<Record<RadarAxisId, number>>>> = {
  "3バック": { defense: -5, attack: 5 },
  "4バック": { defense: 0, attack: 0 },
  "5バック": { defense: 10, attack: -10 },
  "1トップ": { attack: -5, balance: 5 },
  "2トップ": { attack: 0, balance: 0 },
  "3トップ": { attack: 10, defense: -5 },
  "ウイング有": { attack: 5, spaceControl: 5 },
  "ウイングバック有": { spaceControl: 10, pressIntensity: -5 },
  "守備的MF2枚": { defense: 5, pressIntensity: 5 },
  "アンカー1枚": { defense: -5, balance: -5 },
  "攻撃的MF3枚": { attack: 5, balance: -5 },
  "中盤3枚": { balance: 0 },
  "中盤フラット4枚": { balance: 5, pressIntensity: -5 },
  "中盤ダイヤ": { spaceControl: -5, pressIntensity: 10 },
  "中盤実質5枚": { balance: 10, spaceControl: -5 },
  "ライン間が空く": { spaceControl: -10 },
};

const RADAR_AXIS_IDS: readonly RadarAxisId[] = [
  "attack",
  "defense",
  "balance",
  "spaceControl",
  "pressIntensity",
];

function clamp(value: number): number {
  return Math.min(100, Math.max(0, value));
}

/**
 * タグの差分（元のタグ構成には無かった/あったタグ）から、baseStats を基準に
 * 5軸のスコアを概算する純粋関数。
 *
 * positions・Formation は直接見ない（formationTags.ts の deriveTags と同じ設計方針。
 * 呼び出し側が algorithm と同じ getTags で算出したタグ配列のみを渡す）。
 * 差分ベースにすることで、タグ構成が変わらない限り baseStats と完全に一致することを保証する
 * （配置未変更時に自由配置モードのスコアが静かにズレるのを防ぐ）。
 */
export function estimateStats(
  currentTags: readonly FormationTag[],
  originalTags: readonly FormationTag[],
  baseStats: FormationStats,
): FormationStats {
  const added = currentTags.filter((tag) => !originalTags.includes(tag));
  const removed = originalTags.filter((tag) => !currentTags.includes(tag));

  const totalDelta: Partial<Record<RadarAxisId, number>> = {};
  const applyDelta = (tag: FormationTag, sign: 1 | -1): void => {
    const deltas = TAG_SCORE_DELTA[tag];
    if (!deltas) return;
    for (const axis of RADAR_AXIS_IDS) {
      const delta = deltas[axis];
      if (delta === undefined) continue;
      totalDelta[axis] = (totalDelta[axis] ?? 0) + delta * sign;
    }
  };

  for (const tag of added) applyDelta(tag, 1);
  for (const tag of removed) applyDelta(tag, -1);

  const result = {} as FormationStats;
  for (const axis of RADAR_AXIS_IDS) {
    result[axis] = clamp(baseStats[axis] + (totalDelta[axis] ?? 0));
  }
  return result;
}
