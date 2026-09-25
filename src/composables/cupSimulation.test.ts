import { describe, it, expect } from "vitest";
import { runCupSimulation } from "./cupSimulation";
import { formations } from "@/data/formations";
import { getMatchup } from "@/data/matchups";
import type { Formation, MatchSimulationResult, Matchup } from "@/types/formation";

describe("runCupSimulation（実データ: 8フォーメーション ノックアウト方式）", () => {
  const result = runCupSimulation(formations, getMatchup);

  it("準々決勝4試合・準決勝2試合・決勝1試合が生成される", () => {
    expect(result.quarterfinals).toHaveLength(4);
    expect(result.semifinals).toHaveLength(2);
    expect(result.final).toBeDefined();
  });

  it("準々決勝の対戦カードはformationsの並び順どおり([0]vs[1], [2]vs[3], ...)", () => {
    for (let i = 0; i < 4; i += 1) {
      expect(result.quarterfinals[i].formationAId).toBe(formations[i * 2].id);
      expect(result.quarterfinals[i].formationBId).toBe(formations[i * 2 + 1].id);
    }
  });

  it("準決勝の対戦カードは対応する準々決勝の勝者同士になる", () => {
    expect([result.semifinals[0].formationAId, result.semifinals[0].formationBId]).toContain(
      result.quarterfinals[0].winnerId,
    );
    expect([result.semifinals[0].formationAId, result.semifinals[0].formationBId]).toContain(
      result.quarterfinals[1].winnerId,
    );
    expect([result.semifinals[1].formationAId, result.semifinals[1].formationBId]).toContain(
      result.quarterfinals[2].winnerId,
    );
    expect([result.semifinals[1].formationAId, result.semifinals[1].formationBId]).toContain(
      result.quarterfinals[3].winnerId,
    );
  });

  it("決勝の対戦カードは準決勝の勝者同士になり、championIdは決勝の勝者と一致する", () => {
    expect([result.final.formationAId, result.final.formationBId]).toContain(
      result.semifinals[0].winnerId,
    );
    expect([result.final.formationAId, result.final.formationBId]).toContain(
      result.semifinals[1].winnerId,
    );
    expect(result.championId).toBe(result.final.winnerId);
    expect(result.championName).toBe(result.final.winnerName);
  });

  it("全試合で勝者がフォーメーションA・Bのいずれかと一致する", () => {
    const allMatches = [...result.quarterfinals, ...result.semifinals, result.final];
    for (const match of allMatches) {
      expect([match.formationAId, match.formationBId]).toContain(match.winnerId);
    }
  });

  it("決定性: 同一の静的データで複数回実行しても完全に同じ結果になる", () => {
    const second = runCupSimulation(formations, getMatchup);
    expect(second).toEqual(result);
  });
});

function buildFakeFormation(id: string): Formation {
  return {
    id,
    name: id,
    description: "",
    positions: [],
    stats: { attack: 50, defense: 50, balance: 50, spaceControl: 50, pressIntensity: 50 },
  };
}

function buildFakeMatchup(aId: string, bId: string): Matchup {
  return {
    id: `${aId}_vs_${bId}`,
    formationAId: aId,
    formationBId: bId,
    advantagesForA: [],
    advantagesForB: [],
    overallEdge: "even",
    overallReason: "",
  };
}

function fakeGetMatchup(aId: string, bId: string): Matchup | undefined {
  const pair = [aId, bId].sort().join("_vs_");
  const [sortedA, sortedB] = pair.split("_vs_");
  return buildFakeMatchup(sortedA, sortedB);
}

const eightFakeFormations = Array.from({ length: 8 }, (_, i) => buildFakeFormation(`T${i}`));

function drawSimulateMatch(): MatchSimulationResult {
  return {
    possession: { a: 50, b: 50 },
    shots: { a: 1, b: 1 },
    shotsOnTarget: { a: 1, b: 1 },
    score: { a: 1, b: 1 },
    timeline: [],
    summary: "",
  };
}

describe("runCupSimulation（フェイクデータ: PK戦・異常系）", () => {
  it("90分で同点のスタブなら、全試合がPK戦になり必ず勝者が1人決まる", () => {
    const result = runCupSimulation(eightFakeFormations, fakeGetMatchup, drawSimulateMatch);
    const allMatches = [...result.quarterfinals, ...result.semifinals, result.final];
    for (const match of allMatches) {
      expect(match.wentToPenalties).toBe(true);
      expect(match.penaltyScoreA).not.toBe(match.penaltyScoreB);
      expect([match.formationAId, match.formationBId]).toContain(match.winnerId);
    }
  });

  it("PK戦の決定性: 同一の組み合わせなら常に同じPK結果になる", () => {
    const first = runCupSimulation(eightFakeFormations, fakeGetMatchup, drawSimulateMatch);
    const second = runCupSimulation(eightFakeFormations, fakeGetMatchup, drawSimulateMatch);
    expect(second).toEqual(first);
  });

  it("PK戦の勝者は対戦カードの呼び出し順（配列内の並び）に依存しない", () => {
    // T0とT1を入れ替えたformations配列を用意する。1回戦のカード自体は同じ
    // (T0 vs T1)だが、内部でsimulateMatchFn/PK戦に渡されるa/bの順序が逆になる
    const swapped = [
      eightFakeFormations[1],
      eightFakeFormations[0],
      ...eightFakeFormations.slice(2),
    ];
    const original = runCupSimulation(eightFakeFormations, fakeGetMatchup, drawSimulateMatch);
    const withSwappedOrder = runCupSimulation(swapped, fakeGetMatchup, drawSimulateMatch);
    expect(withSwappedOrder.quarterfinals[0].winnerId).toBe(original.quarterfinals[0].winnerId);
  });

  it("スコアに差がある場合はPK戦にならない", () => {
    function decisiveSimulateMatch(a: Formation): MatchSimulationResult {
      // a.idの文字コード合計の偶奇で勝敗を決め、常にどちらかがはっきり勝つようにする
      const aWins = a.id.charCodeAt(1) % 2 === 0;
      return {
        possession: { a: 50, b: 50 },
        shots: { a: 2, b: 1 },
        shotsOnTarget: { a: 2, b: 1 },
        score: { a: aWins ? 1 : 0, b: aWins ? 0 : 1 },
        timeline: [],
        summary: "",
      };
    }
    const result = runCupSimulation(eightFakeFormations, fakeGetMatchup, decisiveSimulateMatch);
    expect(result.quarterfinals.every((m) => !m.wentToPenalties)).toBe(true);
  });

  it("formationsが8件以外の場合はErrorを投げる", () => {
    expect(() => runCupSimulation(eightFakeFormations.slice(0, 7), fakeGetMatchup)).toThrow(
      /8フォーメーション限定/,
    );
  });

  it("マッチアップが見つからない組み合わせがある場合はErrorを投げる", () => {
    const missingMatchup = (): Matchup | undefined => undefined;
    expect(() => runCupSimulation(eightFakeFormations, missingMatchup)).toThrow(
      /マッチアップが見つかりません/,
    );
  });
});
