import { describe, it, expect } from "vitest";
import { deriveTags, getTags, type FormationTag } from "./formationTags";
import { formations } from "./formations";
import type { Formation } from "@/types/formation";

function findFormation(id: string): Formation {
  const formation = formations.find((f) => f.id === id);
  if (!formation) throw new Error(`テストの前提が崩れている: フォーメーション ${id} が無い`);
  return formation;
}

// design.md の導出表そのもの。タグはマッチアップ解説の語彙であり、ここが1つずれると
// 当たるルールが変わって全組み合わせの解説文と総合判定が静かに変化するため、
// 「含む」ではなく集合一致で固定する
const EXPECTED_DERIVED_TAGS: Record<string, FormationTag[]> = {
  "4-4-2": ["4バック", "2トップ", "中盤フラット4枚"],
  "4-3-3": ["4バック", "3トップ", "ウイング有", "中盤3枚"],
  "4-2-3-1": ["4バック", "1トップ", "守備的MF2枚", "攻撃的MF3枚", "中盤実質5枚"],
  "3-5-2": ["3バック", "2トップ", "ウイングバック有", "中盤実質5枚"],
  "5-3-2": ["5バック", "2トップ", "中盤3枚"],
  "4-1-4-1": ["4バック", "1トップ", "中盤実質5枚", "アンカー1枚"],
  "3-4-3": ["3バック", "3トップ", "ウイング有", "ウイングバック有", "中盤フラット4枚"],
  "4-1-2-1-2": ["4バック", "2トップ", "中盤ダイヤ", "アンカー1枚"],
};

describe("deriveTags", () => {
  it("現行の全フォーメーションについて、positionsから期待どおりのタグが導出される", () => {
    // データ追加時に期待表の更新漏れで素通りしないよう、対象データを全走査する
    expect(formations.length).toBe(Object.keys(EXPECTED_DERIVED_TAGS).length);
    for (const formation of formations) {
      const expected = EXPECTED_DERIVED_TAGS[formation.id];
      expect(expected, `期待表に ${formation.id} が無い`).toBeDefined();
      expect([...deriveTags(formation)].sort()).toEqual([...expected].sort());
    }
  });

  it("4-4-2のサイドMF（x=15/85, y=55）はウイングバックとみなさない（高さの境界値）", () => {
    // 幅（x<=15 || x>=85）だけを見ると 4-4-2 がウイングバック扱いになり、
    // 「相手のウイングバックの背後を突く」系のルールが誤って当たる
    const flatFour = findFormation("4-4-2");
    expect(deriveTags(flatFour)).not.toContain("ウイングバック有");

    // 同じ幅のまま高さだけを境界値（y=50）へ下げるとウイングバックとみなされる
    const lowered: Formation = {
      ...flatFour,
      positions: flatFour.positions.map((position) =>
        position.type === "MF" && (position.x <= 15 || position.x >= 85)
          ? { ...position, y: 50 }
          : position,
      ),
    };
    expect(deriveTags(lowered)).toContain("ウイングバック有");

    // 境界の外側（y=51）では再びみなされない
    const justAbove: Formation = {
      ...flatFour,
      positions: flatFour.positions.map((position) =>
        position.type === "MF" && (position.x <= 15 || position.x >= 85)
          ? { ...position, y: 51 }
          : position,
      ),
    };
    expect(deriveTags(justAbove)).not.toContain("ウイングバック有");
  });

  it("低い位置に開いたFWはウイングとみなさない（高さの境界値 y=80）", () => {
    const wide = findFormation("4-3-3");
    expect(deriveTags(wide)).toContain("ウイング有");

    const loweredWings: Formation = {
      ...wide,
      positions: wide.positions.map((position) =>
        position.type === "FW" && (position.x <= 25 || position.x >= 75)
          ? { ...position, y: 79 }
          : position,
      ),
    };
    expect(deriveTags(loweredWings)).not.toContain("ウイング有");
  });

  it("中盤4枚でもyのばらつきが大きければ「中盤フラット4枚」にならない（境界値 spread=10）", () => {
    const flatFour = findFormation("4-4-2");
    const spreadOut: Formation = {
      ...flatFour,
      // 既存の中盤は y=50/55（差5）。サイドMFを y=61 にすると差11で境界の外側
      positions: flatFour.positions.map((position) =>
        position.type === "MF" && (position.x <= 15 || position.x >= 85)
          ? { ...position, y: 61 }
          : position,
      ),
    };
    expect(deriveTags(spreadOut)).not.toContain("中盤フラット4枚");

    const atBoundary: Formation = {
      ...flatFour,
      positions: flatFour.positions.map((position) =>
        position.type === "MF" && (position.x <= 15 || position.x >= 85)
          ? { ...position, y: 60 }
          : position,
      ),
    };
    expect(deriveTags(atBoundary)).toContain("中盤フラット4枚");
  });

  it("「ライン間が空く」はpositionsからは導出されない（extraTags専用のタグ）", () => {
    for (const formation of formations) {
      expect(deriveTags(formation)).not.toContain("ライン間が空く");
    }
  });

  // 「中盤ダイヤ」は「中盤フラット4枚」の排他的補集合（MFが4人のとき、フラットで
  // なければダイヤ）。design.mdの不変条件。全形を走査して両方が同時に付かないことを固定する
  it("「中盤ダイヤ」と「中盤フラット4枚」が同時に付かない（全フォーメーション走査）", () => {
    for (const formation of formations) {
      const tags = deriveTags(formation);
      const hasBoth = tags.includes("中盤ダイヤ") && tags.includes("中盤フラット4枚");
      expect(hasBoth, `${formation.id} が両方のタグを同時に持っている`).toBe(false);
    }
  });

  // 「アンカー1枚」は「守備的MF2枚」の1人版。守備的MFの人数は1か2のどちらかにしか
  // ならないため、同時には付かない。design.mdの不変条件
  it("「アンカー1枚」と「守備的MF2枚」が同時に付かない（全フォーメーション走査）", () => {
    for (const formation of formations) {
      const tags = deriveTags(formation);
      const hasBoth = tags.includes("アンカー1枚") && tags.includes("守備的MF2枚");
      expect(hasBoth, `${formation.id} が両方のタグを同時に持っている`).toBe(false);
    }
  });

  it("中盤4人のyのばらつきが10ならフラット、11ならダイヤになる（境界値）", () => {
    const flatFour = findFormation("4-4-2");
    // 既存の中盤は y=50/55（差5）。サイドMFの片方だけをずらし、CM2枚(y=50)を挟んで
    // 最小値1人・最大値1人の真の菱形（底1・中2・頂点1）を作る。両側とも同じ値にずらすと
    // 「2人が低い・2人が高い」箱型になり、`中盤ダイヤ`が要求する「頂点は1人」を満たさない
    const atBoundary: Formation = {
      ...flatFour,
      positions: flatFour.positions.map((position) => {
        if (position.type !== "MF") return position;
        if (position.x <= 15) return { ...position, y: 45 }; // 底（最小、1人）
        if (position.x >= 85) return { ...position, y: 55 }; // 頂点（最大、1人）。CM2枚がy=50で挟む
        return position;
      }),
    };
    expect(deriveTags(atBoundary)).toContain("中盤フラット4枚");
    expect(deriveTags(atBoundary)).not.toContain("中盤ダイヤ");

    // 差11（境界の外側）では真の菱形としてダイヤになる
    const overBoundary: Formation = {
      ...flatFour,
      positions: flatFour.positions.map((position) => {
        if (position.type !== "MF") return position;
        if (position.x <= 15) return { ...position, y: 44 }; // 底（最小、1人）
        if (position.x >= 85) return { ...position, y: 55 }; // 頂点（最大、1人）
        return position;
      }),
    };
    expect(deriveTags(overBoundary)).toContain("中盤ダイヤ");
    expect(deriveTags(overBoundary)).not.toContain("中盤フラット4枚");
  });

  it("最小値・最大値がそれぞれ複数人いる「箱型」の中盤4人には中盤ダイヤが付かない", () => {
    // 2人が低い・2人が高い（頂点が1人に定まらない）配置。`中盤ダイヤ`が保証する
    // 「菱形の頂点」という性質を満たさないため、フラットでもダイヤでもタグなしになる
    const flatFour = findFormation("4-4-2");
    const boxShaped: Formation = {
      ...flatFour,
      positions: flatFour.positions.map((position) =>
        position.type === "MF" && (position.x <= 15 || position.x >= 85)
          ? { ...position, y: 61 }
          : position,
      ),
    };
    expect(deriveTags(boxShaped)).not.toContain("中盤ダイヤ");
    expect(deriveTags(boxShaped)).not.toContain("中盤フラット4枚");
  });

  it("DFが3人/4人/5人でそれぞれ正しいバックラインのタグになる（境界値）", () => {
    const flatFour = findFormation("4-4-2");
    expect(deriveTags(flatFour)).toContain("4バック");
    expect(deriveTags(flatFour)).not.toContain("3バック");
    expect(deriveTags(flatFour)).not.toContain("5バック");

    const threeAtBack: Formation = {
      ...flatFour,
      positions: flatFour.positions.filter((position) => position.id !== "4-4-2-rb"),
    };
    expect(deriveTags(threeAtBack)).toContain("3バック");
    expect(deriveTags(threeAtBack)).not.toContain("4バック");
    expect(deriveTags(threeAtBack)).not.toContain("5バック");

    const fiveAtBack: Formation = {
      ...flatFour,
      positions: [
        ...flatFour.positions,
        { id: "4-4-2-extra-cb", type: "DF" as const, label: "CB", x: 50, y: 16 },
      ],
    };
    expect(deriveTags(fiveAtBack)).toContain("5バック");
    expect(deriveTags(fiveAtBack)).not.toContain("4バック");
  });
});

describe("getTags", () => {
  it("extraTagsが導出結果にマージされる", () => {
    const flatFour = findFormation("4-4-2");
    expect(flatFour.extraTags).toContain("ライン間が空く");
    expect(getTags(flatFour)).toContain("ライン間が空く");
    // 導出タグも失われない
    for (const tag of deriveTags(flatFour)) {
      expect(getTags(flatFour)).toContain(tag);
    }
  });

  it("extraTagsが導出タグと重複しても、結果に重複が残らない", () => {
    const wide = findFormation("4-3-3");
    const duplicated: Formation = { ...wide, extraTags: ["4バック", "ウイング有"] };
    const tags = getTags(duplicated);
    expect(new Set(tags).size).toBe(tags.length);
  });

  it("extraTagsが未指定でも導出タグだけを返す（例外を投げない）", () => {
    const wide = findFormation("4-3-3");
    expect(wide.extraTags).toBeUndefined();
    expect(getTags(wide)).toEqual(deriveTags(wide));
  });
});
