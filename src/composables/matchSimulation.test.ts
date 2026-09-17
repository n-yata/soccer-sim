import { describe, it, expect } from "vitest";
import { simulateMatch } from "./matchSimulation";
import { formations, getFormationById } from "@/data/formations";
import { buildAllMatchups, generateMatchup } from "@/data/matchupGenerator";
import { getMatchup } from "@/data/matchups";
import type { Formation, Matchup } from "@/types/formation";

function findFormation(id: string): Formation {
  const formation = getFormationById(id);
  if (!formation) throw new Error(`テストの前提が崩れている: フォーメーション ${id} が無い`);
  return formation;
}

function findMatchup(aId: string, bId: string): Matchup {
  const matchup = getMatchup(aId, bId);
  if (!matchup) throw new Error(`テストの前提が崩れている: マッチアップ ${aId} vs ${bId} が無い`);
  return matchup;
}

const formationA = findFormation("4-2-3-1");
const formationB = findFormation("4-4-2");
// data/matchups.ts（本番でComparisonPageが実際に使う経路）から取得する。
// generateMatchupを直接呼ぶと、formations.ts配列上の正準順（"4-4-2_vs_4-2-3-1"）とは
// 異なるid（"4-2-3-1_vs_4-4-2"）になり、本番では発生しないシード・結果を固定値化して
// しまう（review-implementationの指摘）
const matchupAB = findMatchup(formationA.id, formationB.id);

describe("simulateMatch", () => {
  it("決定性: 同一引数を複数回呼び出しても完全に同じ結果になる", () => {
    const first = simulateMatch(formationA, formationB, matchupAB);
    const second = simulateMatch(formationA, formationB, matchupAB);
    const third = simulateMatch(formationA, formationB, matchupAB);
    expect(second).toEqual(first);
    expect(third).toEqual(first);
  });

  it("シードはmatchup.idの値に基づく（オブジェクト参照ではない）: 深いクローンでも同じ結果になる", () => {
    // JSON経由で参照を切った別オブジェクトを渡し、結果が完全に一致することを確認する。
    // 一致すれば「シードはidの文字列値から決まり、オブジェクトの同一性や生成過程には
    // 依存しない」ことが保証される
    const clonedMatchup: Matchup = JSON.parse(JSON.stringify(matchupAB));
    expect(clonedMatchup).not.toBe(matchupAB);

    const original = simulateMatch(formationA, formationB, matchupAB);
    const fromClone = simulateMatch(formationA, formationB, clonedMatchup);
    expect(fromClone).toEqual(original);
  });

  it("A/Bを入れ替えて呼んでも、順序非依存の同じ90分間の鏡写しになる（勝敗が呼び出し順で変わらない）", () => {
    // 「組み合わせ」は呼び出し順に依存しない不変条件（FR-14の受け入れ条件。
    // getMatchup/buildPairKeyが順序非依存に扱う既存の設計と揃える）。
    // review-implementationの[必須]指摘: 修正前はここが鏡写しにならず、
    // 入れ替えボタン（FR-09）を押しただけで勝者が反転する不具合があった
    const swappedMatchup = findMatchup(formationB.id, formationA.id);
    const original = simulateMatch(formationA, formationB, matchupAB);
    const swapped = simulateMatch(formationB, formationA, swappedMatchup);

    expect(swapped.score).toEqual({ a: original.score.b, b: original.score.a });
    expect(swapped.possession).toEqual({ a: original.possession.b, b: original.possession.a });
    expect(swapped.shots).toEqual({ a: original.shots.b, b: original.shots.a });
    expect(swapped.shotsOnTarget).toEqual({
      a: original.shotsOnTarget.b,
      b: original.shotsOnTarget.a,
    });
    expect(swapped.summary).toBe(original.summary);
    expect(swapped.timeline).toEqual(
      original.timeline.map((event) => ({
        ...event,
        team: event.team === "A" ? "B" : "A",
      })),
    );
  });

  it("idが異なるmatchupでは異なる90分間になる（ハッシュが入力に応じて変化することの検証）", () => {
    const formationC = findFormation("3-5-2");
    const matchupAC = generateMatchup(formationA, formationC);
    expect(matchupAC.id).not.toBe(matchupAB.id);

    const resultAB = simulateMatch(formationA, formationB, matchupAB);
    const resultAC = simulateMatch(formationA, formationC, matchupAC);
    expect(resultAC.timeline).not.toEqual(resultAB.timeline);
  });

  it("固定フォーメーションペアで既知の結果になる（回帰検知用の固定値）", () => {
    const result = simulateMatch(formationA, formationB, matchupAB);
    // 初回実行結果をそのまま固定値化している。アルゴリズムを意図的に変更した場合は
    // このテストの期待値を更新すること（design.md「テスト戦略」参照）。
    // matchupABはdata/matchups.ts経由（本番でComparisonPageが使う経路と同じ）なので、
    // 実際にアプリを操作したときに表示されうる試合そのものである
    expect(result.score).toEqual({ a: 1, b: 0 });
    expect(result.possession).toEqual({ a: 48, b: 52 });
    expect(result.shots).toEqual({ a: 8, b: 9 });
    expect(result.shotsOnTarget).toEqual({ a: 1, b: 4 });
    expect(result.timeline[0]).toEqual({
      minute: 1,
      team: "B",
      kind: "chance",
      text: "4-4-2にチャンスがあったが枠を外れる",
    });
    expect(result.summary).toBe(
      "4-2-3-1が1-0で4-4-2を下した。内容面で上回れない時間帯もありながら、数少ない好機を確実に決めきった試合だった。",
    );
  });

  describe("不変条件（全フォーメーション組み合わせ）", () => {
    const allMatchups = buildAllMatchups(formations);
    const cases: [string, Formation, Formation, Matchup][] = allMatchups.map((matchup) => [
      matchup.id,
      findFormation(matchup.formationAId),
      findFormation(matchup.formationBId),
      matchup,
    ]);

    // 検証機構自体が空振りしていないことの確認（review-implementationの[提案]対応）。
    // buildAllMatchupsが空を返すと下のit.eachが0件実行のまま「全件パス」に見えてしまう
    it("検証対象の組み合わせが1件以上ある", () => {
      expect(cases.length).toBeGreaterThan(0);
    });

    it.each(cases)("%s", (_id, a, b, matchup) => {
      const result = simulateMatch(a, b, matchup);

      expect(result.possession.a + result.possession.b).toBe(100);
      expect(result.shots.a).toBeGreaterThanOrEqual(result.score.a);
      expect(result.shots.b).toBeGreaterThanOrEqual(result.score.b);
      expect(result.shotsOnTarget.a).toBeLessThanOrEqual(result.shots.a);
      expect(result.shotsOnTarget.b).toBeLessThanOrEqual(result.shots.b);
      expect(result.score.a).toBeLessThanOrEqual(result.shotsOnTarget.a);
      expect(result.score.b).toBeLessThanOrEqual(result.shotsOnTarget.b);

      // タイムラインと集計値の食い違いが最も起こりやすい静かな不具合
      // （review-implementationの[提案]対応）
      const goalEventsInTimeline = result.timeline.filter((event) => event.kind === "goal").length;
      expect(goalEventsInTimeline).toBe(result.score.a + result.score.b);
      const onTargetEventsInTimeline = result.timeline.filter(
        (event) => event.kind === "goal" || event.kind === "shot",
      ).length;
      expect(onTargetEventsInTimeline).toBe(result.shotsOnTarget.a + result.shotsOnTarget.b);

      // review-pre-commitの指摘(M-2)対応の回帰防止: 2点以上のビハインドから得点しても
      // 「追加点」と誤表示されないことを、実装をなぞらずビハインド状況だけから検証する。
      // ゴール前の状態（自分が相手より少ない）を、タイムラインを辿りながら再構築する
      const runningScore: Record<"A" | "B", number> = { A: 0, B: 0 };
      let previousMinute = 0;
      for (const event of result.timeline) {
        expect(event.minute).toBeGreaterThanOrEqual(1);
        expect(event.minute).toBeLessThanOrEqual(90);
        expect(event.minute).toBeGreaterThanOrEqual(previousMinute);
        previousMinute = event.minute;

        if (event.kind === "goal") {
          const opponent: "A" | "B" = event.team === "A" ? "B" : "A";
          const isBehind = runningScore[event.team] < runningScore[opponent];
          if (isBehind) {
            expect(event.text).not.toContain("追加点");
          }
          runningScore[event.team] += 1;
        }
      }
    });
  });

  it("極端ケース: 全stats軸が同一の2フォーメームでも例外を投げず有効な結果を返す", () => {
    const flat: Formation = {
      id: "flat-test",
      name: "フラット",
      description: "テスト用。全軸のstatsが同一",
      stats: { attack: 50, defense: 50, balance: 50, spaceControl: 50, pressIntensity: 50 },
      positions: [{ id: "flat-gk", type: "GK", label: "GK", x: 50, y: 5 }],
    };
    const flatMatchup = generateMatchup(flat, flat);

    let result: ReturnType<typeof simulateMatch> | undefined;
    expect(() => {
      result = simulateMatch(flat, flat, flatMatchup);
    }).not.toThrow();

    expect(result).toBeDefined();
    expect(Number.isFinite(result!.possession.a)).toBe(true);
    expect(result!.possession.a + result!.possession.b).toBe(100);
    // 全stats同一（重みの合計が0にならない通常ケース）では、90分のうちどこかで
    // 攻撃機会が生まれるはずで、タイムラインが恒常的に空にはならない
    expect(result!.timeline.length).toBeGreaterThan(0);
  });

  it("極端ケース: 全stats軸が0のフォーメームでも0除算にならない", () => {
    const zero: Formation = {
      id: "zero-test",
      name: "ゼロ",
      description: "テスト用。全軸のstatsが0",
      stats: { attack: 0, defense: 0, balance: 0, spaceControl: 0, pressIntensity: 0 },
      positions: [{ id: "zero-gk", type: "GK", label: "GK", x: 50, y: 5 }],
    };
    const zeroMatchup = generateMatchup(zero, zero);

    const result = simulateMatch(zero, zero, zeroMatchup);
    expect(Number.isNaN(result.possession.a)).toBe(false);
    expect(result.possession.a + result.possession.b).toBe(100);
  });

  it("極端ケース: statsにNaNが混入していても、確率がNaNを素通ししない（review-pre-commit M-3対応）", () => {
    // NaN >= 確率 は常にfalseになるため、ガードが無いと「毎分ゴール」という
    // 静かな誤りになる（90-0のような不自然なスコアで顕在化する）
    const nanStats: Formation = {
      id: "nan-test",
      name: "NaN",
      description: "テスト用。attackがNaN",
      stats: { attack: NaN, defense: 50, balance: 50, spaceControl: 50, pressIntensity: 50 },
      positions: [{ id: "nan-gk", type: "GK", label: "GK", x: 50, y: 5 }],
    };
    const normal = findFormation("4-4-2");
    const matchup = generateMatchup(nanStats, normal);

    const result = simulateMatch(nanStats, normal, matchup);

    expect(Number.isFinite(result.score.a)).toBe(true);
    expect(Number.isFinite(result.score.b)).toBe(true);
    // ガードがあれば確率はBASE値相当（0.4未満）に収まり、90分間90ゴールにはならない
    expect(result.score.a).toBeLessThan(90);
    expect(result.score.b).toBeLessThan(90);
  });
});
