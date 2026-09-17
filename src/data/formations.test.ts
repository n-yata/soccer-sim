import { describe, it, expect } from "vitest";
import { formations, getFormationById } from "./formations";
import { radarAxes } from "./radarAxes";

// functional-overview.md「ドメイン上の制約」: ポジション数の合計はGKを含め11人、
// フォーメーション名の数字合計とフィールドプレイヤー数が一致すること。
// 対象データ（全フォーメーション）を全走査する（testing.md「不変条件のテストは
// 対象データを全走査する」）。
describe("formations（ドメイン制約）", () => {
  it.each(formations)("$id: ポジション数の合計が11人である", (formation) => {
    expect(formation.positions).toHaveLength(11);
  });

  it.each(formations)(
    "$id: 名称の数字合計とフィールドプレイヤー数（GK除く）が一致する",
    (formation) => {
      const expectedFieldPlayers = formation.name
        .split("-")
        .map(Number)
        .reduce((sum, count) => sum + count, 0);
      const actualFieldPlayers = formation.positions.filter(
        (position) => position.type !== "GK",
      ).length;
      expect(actualFieldPlayers).toBe(expectedFieldPlayers);
    },
  );
});

// レーダーチャート用stats（functional-overview.md「データモデル」確定事項）の不変条件を
// 全フォーメーション走査で検証する
describe("formations（statsの不変条件）", () => {
  it.each(formations)("$id: 全軸のスコアが0〜100の範囲内である", (formation) => {
    for (const axis of radarAxes) {
      const value = formation.stats[axis.id];
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThanOrEqual(100);
    }
  });

  it("全フォーメーションのstatsベクトルが互いに完全一致しない（重ね描画で差が出ないデータ不備の検知）", () => {
    const vectors = formations.map((formation) =>
      radarAxes.map((axis) => formation.stats[axis.id]).join(","),
    );
    const uniqueVectors = new Set(vectors);
    expect(uniqueVectors.size).toBe(formations.length);
  });
});

describe("getFormationById", () => {
  it("存在するIDを渡すと該当するFormationを返す", () => {
    const result = getFormationById("4-4-2");
    expect(result?.id).toBe("4-4-2");
    expect(result?.name).toBe("4-4-2");
  });

  it("存在しないIDを渡すとundefinedを返す", () => {
    expect(getFormationById("存在しないID")).toBeUndefined();
  });

  it("空文字を渡すとundefinedを返す", () => {
    expect(getFormationById("")).toBeUndefined();
  });
});
