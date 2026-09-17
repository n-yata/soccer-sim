import { describe, it, expect } from "vitest";
import { getMatchup, matchups } from "./matchups";
import { formations } from "./formations";

describe("getMatchup", () => {
  // NFR-03「新しいフォーメーションをデータファイルへの追加のみで表示できる」の裏返しとして、
  // 優位ポイントの追加漏れは実行時に発見できない（ComparisonPage は matchup が undefined の
  // ときにエラー表示へ切り替えるが、matchup 自体は存在してadvantagesForA/Bが空配列だと
  // 無言で空欄になる。screen-02-comparison.md「実装時の作り込みで防ぐ」の担保をここに置く）。
  // 対象データ（全フォーメーションの2件組み合わせ）を全走査する（testing.md「不変条件のテストは
  // 対象データを全走査する」）。
  it("formationsに含まれる全てのフォーメーション2件組み合わせについて、Matchupが存在し、advantagesForA/Bともに1件以上を持つ", () => {
    const ids = formations.map((formation) => formation.id);
    expect(ids.length).toBeGreaterThanOrEqual(2);

    const missing: string[] = [];
    const empty: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      for (let j = i + 1; j < ids.length; j++) {
        const pairLabel = `${ids[i]} vs ${ids[j]}`;
        const matchup = getMatchup(ids[i], ids[j]);
        if (matchup === undefined) {
          missing.push(pairLabel);
          continue;
        }
        if (matchup.advantagesForA.length === 0 || matchup.advantagesForB.length === 0) {
          empty.push(pairLabel);
        }
      }
    }
    expect(missing).toEqual([]);
    expect(empty).toEqual([]);
  });

  // overallReasonは「どちらが有利か」を一目で示すために追加したフィールド。
  // 追加漏れがあると画面上部の総合判定理由が空欄になり、無言で機能不全になる（上と同じ理由で
  // 全走査する）。overallEdgeは型（"A"|"B"|"even"のunion）で網羅性が保証されているため、
  // ここでは検査しない（値の存在有無をチェックしても常に真になる恒真アサーションになるため）。
  it("formationsに含まれる全てのフォーメーション2件組み合わせについて、overallReasonが空文字でない", () => {
    const ids = formations.map((formation) => formation.id);
    const missing: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      for (let j = i + 1; j < ids.length; j++) {
        const matchup = getMatchup(ids[i], ids[j]);
        if (!matchup) continue;
        if (matchup.overallReason.trim() === "") {
          missing.push(`${ids[i]} vs ${ids[j]}`);
        }
      }
    }
    expect(missing).toEqual([]);
  });

  // types/formation.ts に明記した不変条件（overallReasonはA/B相対表現を使わない）の担保。
  // getMatchup は入れ替え時に overallEdge のみ反転し overallReason はそのまま返すため、
  // 「Aは」のような相対表現が混入すると、入れ替え後に逆側のフォーメーションを指す誤った
  // 文言として表示されてしまう（静かに誤る欠陥になるため、コンテンツレベルで機械的に防ぐ）。
  it("overallReasonに「Aは」「Bの」等のA/B相対表現が含まれていない", () => {
    const relativeExpressionPattern = /(^|[はがのを])[AB]([はがのを]|$)/;
    const offenders = matchups
      .filter((matchup) => relativeExpressionPattern.test(matchup.overallReason))
      .map((matchup) => matchup.id);
    expect(offenders).toEqual([]);
  });

  // 静的・並び替えなしのリストであっても、ComparisonPage.vue の <li v-for> は :key にindexを
  // 使う設計にしている。それでも「同一配列内に重複する文言があると、データ作成時の誤りに
  // 気づきにくい」という別の問題は残るため、コンテンツ品質としてここで検知する。
  it("各Matchupのadvantagesにおいて、同一配列内に重複する文言が無い", () => {
    const ids = formations.map((formation) => formation.id);
    const duplicated: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      for (let j = i + 1; j < ids.length; j++) {
        const matchup = getMatchup(ids[i], ids[j]);
        if (!matchup) continue;
        for (const [label, points] of [
          ["advantagesForA", matchup.advantagesForA],
          ["advantagesForB", matchup.advantagesForB],
        ] as const) {
          if (new Set(points).size !== points.length) {
            duplicated.push(`${matchup.id} (${label})`);
          }
        }
      }
    }
    expect(duplicated).toEqual([]);
  });

  it("レコードの格納順序どおりに渡すと、そのままのadvantagesForA/Bで返す", () => {
    // data/matchups.ts 上のレコードは formationAId="4-4-2", formationBId="4-2-3-1"
    const result = getMatchup("4-4-2", "4-2-3-1");
    expect(result?.id).toBe("4-4-2_vs_4-2-3-1");
    expect(result?.formationAId).toBe("4-4-2");
    expect(result?.formationBId).toBe("4-2-3-1");
    expect(result?.advantagesForA.length).toBeGreaterThan(0);
    expect(result?.advantagesForB.length).toBeGreaterThan(0);
  });

  it("引数の順序を逆にすると、advantagesForA/Bが入れ替わって返る（順序非依存の正規化）", () => {
    const forward = getMatchup("4-4-2", "4-2-3-1");
    const backward = getMatchup("4-2-3-1", "4-4-2");
    expect(backward?.id).toBe(forward?.id);
    // 呼び出し時のA/Bに合わせて formationAId/formationBId が入れ替わる
    expect(backward?.formationAId).toBe("4-2-3-1");
    expect(backward?.formationBId).toBe("4-4-2");
    // advantagesForA/Bの中身も入れ替わる（forwardのAdvantagesForAがbackwardのadvantagesForBになる）
    expect(backward?.advantagesForA).toEqual(forward?.advantagesForB);
    expect(backward?.advantagesForB).toEqual(forward?.advantagesForA);
  });

  it("引数の順序を逆にすると、overallEdgeがA/Bで反転する（evenはそのまま）", () => {
    // データ変更時にテストが壊れないよう、特定のマッチアップIDをハードコードせず、
    // overallEdgeが"B"のレコードと"even"のレコードをそれぞれ動的に1件ずつ選んで検証する
    const bMatchup = matchups.find((matchup) => matchup.overallEdge === "B");
    const evenMatchup = matchups.find((matchup) => matchup.overallEdge === "even");
    expect(bMatchup).toBeDefined();
    expect(evenMatchup).toBeDefined();

    const forward = getMatchup(bMatchup!.formationAId, bMatchup!.formationBId);
    const backward = getMatchup(bMatchup!.formationBId, bMatchup!.formationAId);
    expect(forward?.overallEdge).toBe("B");
    expect(backward?.overallEdge).toBe("A");
    expect(backward?.overallReason).toBe(forward?.overallReason);

    const evenForward = getMatchup(evenMatchup!.formationAId, evenMatchup!.formationBId);
    const evenBackward = getMatchup(evenMatchup!.formationBId, evenMatchup!.formationAId);
    expect(evenForward?.overallEdge).toBe("even");
    expect(evenBackward?.overallEdge).toBe("even");
  });

  it("同一フォーメーション同士を渡すとundefinedを返す", () => {
    expect(getMatchup("4-4-2", "4-4-2")).toBeUndefined();
  });

  it("存在しないフォーメーションIDを渡すとundefinedを返す", () => {
    expect(getMatchup("4-4-2", "存在しないID")).toBeUndefined();
  });
});
