import { describe, it, expect } from "vitest";
import { runLeagueSimulation } from "./leagueSimulation";
import { formations } from "@/data/formations";
import { getMatchup } from "@/data/matchups";
import type { Formation, MatchSimulationResult, Matchup } from "@/types/formation";

const EXPECTED_MATCH_COUNT = (formations.length * (formations.length - 1)) / 2;

describe("runLeagueSimulation（実データ: 8フォーメーション総当たり）", () => {
  const result = runLeagueSimulation(formations, getMatchup);

  it("全フォーメーションの試合数が (n-1) になる", () => {
    for (const standing of result.standings) {
      expect(standing.played).toBe(formations.length - 1);
    }
  });

  it("全組み合わせ分（n(n-1)/2）の試合結果が生成され、同一フォーメーション同士が含まれない", () => {
    expect(result.matches).toHaveLength(EXPECTED_MATCH_COUNT);
    for (const match of result.matches) {
      expect(match.formationAId).not.toBe(match.formationBId);
    }
  });

  it("各行の勝+分+敗が試合数と一致する", () => {
    for (const standing of result.standings) {
      expect(standing.win + standing.draw + standing.lose).toBe(standing.played);
    }
  });

  it("得失点差は得点-失点と一致する", () => {
    for (const standing of result.standings) {
      expect(standing.goalDifference).toBe(standing.goalsFor - standing.goalsAgainst);
    }
  });

  it("勝ち点はサッカー標準ルール（勝ち3・分け1・負け0）と一致する", () => {
    for (const standing of result.standings) {
      expect(standing.points).toBe(standing.win * 3 + standing.draw);
    }
  });

  it("決定性: 同一の静的データで複数回実行しても完全に同じ結果になる", () => {
    const second = runLeagueSimulation(formations, getMatchup);
    const third = runLeagueSimulation(formations, getMatchup);
    expect(second).toEqual(result);
    expect(third).toEqual(result);
  });

  it("順位は勝ち点→得失点差→総得点の辞書式降順に並んでいる", () => {
    for (let i = 1; i < result.standings.length; i += 1) {
      const prev = result.standings[i - 1];
      const curr = result.standings[i];
      if (curr.points !== prev.points) {
        expect(curr.points).toBeLessThan(prev.points);
      } else if (curr.goalDifference !== prev.goalDifference) {
        expect(curr.goalDifference).toBeLessThan(prev.goalDifference);
      } else {
        expect(curr.goalsFor).toBeLessThanOrEqual(prev.goalsFor);
      }
    }
  });
});

// フェイクデータでタイブレーク・同着順位・エラーハンドリングを検証する。
// 実データでは狙って同点を作れないため、スコアを固定するスタブを注入する
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

describe("runLeagueSimulation（フェイクデータ: 同着順位・エラーハンドリング）", () => {
  const teamX = buildFakeFormation("X");
  const teamY = buildFakeFormation("Y");
  const teamZ = buildFakeFormation("Z");
  const fakeFormations = [teamX, teamY, teamZ];

  function fakeGetMatchup(aId: string, bId: string): Matchup | undefined {
    const pair = [aId, bId].sort().join("_vs_");
    const [sortedA, sortedB] = pair.split("_vs_");
    return buildFakeMatchup(sortedA, sortedB);
  }

  it("勝ち点・得失点差・総得点が完全に同じチームは同順位になる（同着順位方式）", () => {
    // X,Y,Zは全試合1-1で引き分ける設定にし、3チームとも全指標が同値になるようにする
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

    const result = runLeagueSimulation(fakeFormations, fakeGetMatchup, drawSimulateMatch);

    expect(result.standings).toHaveLength(3);
    for (const standing of result.standings) {
      expect(standing.rank).toBe(1);
      expect(standing.win).toBe(0);
      expect(standing.draw).toBe(2);
      expect(standing.points).toBe(2);
    }
  });

  it("同着順位方式（1,2,2,4,...）: 2位が同着の場合、次のチームは3位ではなく4位相当の順位を飛ばさず、正しい方式で採番される", () => {
    // Wを追加した4チームで、X:3連勝, Y/Z:1勝1敗1分でタイ, W:3連敗、という結果を固定スコアで再現する
    const teamW = buildFakeFormation("W");
    const four = [teamX, teamY, teamZ, teamW];

    function fixedSimulateMatch(a: Formation, b: Formation): MatchSimulationResult {
      const winner: Record<string, string> = {
        "X_vs_Y": "X",
        "X_vs_Z": "X",
        "X_vs_W": "X",
        "Y_vs_Z": "draw",
        "Y_vs_W": "Y",
        "Z_vs_W": "Z",
      };
      const key = [a.id, b.id].sort().join("_vs_");
      const outcome = winner[key];
      if (outcome === "draw") {
        return {
          possession: { a: 50, b: 50 },
          shots: { a: 1, b: 1 },
          shotsOnTarget: { a: 1, b: 1 },
          score: { a: 1, b: 1 },
          timeline: [],
          summary: "",
        };
      }
      const [sortedA] = key.split("_vs_");
      const sortedAWins = outcome === sortedA;
      const aScore = a.id === sortedA ? (sortedAWins ? 1 : 0) : sortedAWins ? 0 : 1;
      const bScore = aScore === 1 ? 0 : 1;
      return {
        possession: { a: 50, b: 50 },
        shots: { a: 1, b: 1 },
        shotsOnTarget: { a: 1, b: 1 },
        score: { a: aScore, b: bScore },
        timeline: [],
        summary: "",
      };
    }

    const result = runLeagueSimulation(four, fakeGetMatchup, fixedSimulateMatch);
    const byId = new Map(result.standings.map((s) => [s.formationId, s]));

    expect(byId.get("X")!.rank).toBe(1);
    expect(byId.get("Y")!.rank).toBe(2);
    expect(byId.get("Z")!.rank).toBe(2);
    expect(byId.get("W")!.rank).toBe(4);
  });

  it("マッチアップが見つからない組み合わせがある場合はErrorを投げる", () => {
    const missingMatchup = (): Matchup | undefined => undefined;
    expect(() => runLeagueSimulation(fakeFormations, missingMatchup)).toThrow(
      /マッチアップが見つかりません/,
    );
  });
});
