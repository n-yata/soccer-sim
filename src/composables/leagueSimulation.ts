import { simulateMatch } from "@/composables/matchSimulation";
import type {
  Formation,
  LeagueMatchResult,
  LeagueSimulationResult,
  LeagueStanding,
  MatchSimulationResult,
  Matchup,
} from "@/types/formation";

interface Accumulator {
  formation: Formation;
  played: number;
  win: number;
  draw: number;
  lose: number;
  goalsFor: number;
  goalsAgainst: number;
}

function createAccumulator(formation: Formation): Accumulator {
  return {
    formation,
    played: 0,
    win: 0,
    draw: 0,
    lose: 0,
    goalsFor: 0,
    goalsAgainst: 0,
  };
}

function applyResult(acc: Accumulator, goalsFor: number, goalsAgainst: number): void {
  acc.played += 1;
  acc.goalsFor += goalsFor;
  acc.goalsAgainst += goalsAgainst;
  if (goalsFor > goalsAgainst) {
    acc.win += 1;
  } else if (goalsFor < goalsAgainst) {
    acc.lose += 1;
  } else {
    acc.draw += 1;
  }
}

function toStanding(acc: Accumulator): Omit<LeagueStanding, "rank"> {
  return {
    formationId: acc.formation.id,
    formationName: acc.formation.name,
    played: acc.played,
    win: acc.win,
    draw: acc.draw,
    lose: acc.lose,
    goalsFor: acc.goalsFor,
    goalsAgainst: acc.goalsAgainst,
    goalDifference: acc.goalsFor - acc.goalsAgainst,
    points: acc.win * 3 + acc.draw,
  };
}

// 比較キー: [勝ち点, 得失点差, 総得点] の降順。すべて0であれば同値（同順位）とみなす
function compareStandings(a: Omit<LeagueStanding, "rank">, b: Omit<LeagueStanding, "rank">): number {
  if (a.points !== b.points) return b.points - a.points;
  if (a.goalDifference !== b.goalDifference) return b.goalDifference - a.goalDifference;
  return b.goalsFor - a.goalsFor;
}

// 標準的な同着順位方式（1, 2, 2, 4, ...）。直前と全指標が同値なら同じ順位を引き継ぐ
function assignRanks(sorted: Omit<LeagueStanding, "rank">[]): LeagueStanding[] {
  const result: LeagueStanding[] = [];
  let currentRank = 0;
  for (let index = 0; index < sorted.length; index += 1) {
    const entry = sorted[index];
    const previous = sorted[index - 1];
    if (index === 0 || compareStandings(entry, previous) !== 0) {
      currentRank = index + 1;
    }
    result.push({ ...entry, rank: currentRank });
  }
  return result;
}

/**
 * 8フォーメーション総当たり1回戦（n(n-1)/2試合）のリーグ戦を決定的に実行し、
 * 勝ち点表と全試合結果を返す。
 *
 * composables/ は data/ に依存しない設計方針（matchSimulation.ts 冒頭コメント）のため、
 * マッチアップの導出（本来 data/matchups.ts の getMatchup）は呼び出し側から関数として
 * 注入する。simulateMatch は同じ composables/ 層なので既定値として直接利用しつつ、
 * テストでは固定スコアを返すスタブに差し替えられるよう引数化する
 * （types/formation.ts の Shuffle と同じ DI パターン）。
 *
 * マッチアップが見つからない組み合わせ（getMatchupFn が undefined を返す）は、
 * 開発時に用意する静的データが完全である前提（functional-overview.md「確定事項」）が
 * 崩れているデータ不整合として扱い、握りつぶさずに Error を投げる。
 */
export function runLeagueSimulation(
  formations: Formation[],
  getMatchupFn: (formationAId: string, formationBId: string) => Matchup | undefined,
  simulateMatchFn: (a: Formation, b: Formation, matchup: Matchup) => MatchSimulationResult = simulateMatch,
): LeagueSimulationResult {
  const accumulators = new Map<string, Accumulator>(
    formations.map((formation) => [formation.id, createAccumulator(formation)]),
  );
  const matches: LeagueMatchResult[] = [];

  for (let i = 0; i < formations.length; i += 1) {
    for (let j = i + 1; j < formations.length; j += 1) {
      const a = formations[i];
      const b = formations[j];
      const matchup = getMatchupFn(a.id, b.id);
      if (!matchup) {
        throw new Error(`リーグ戦の集計に必要なマッチアップが見つかりません: ${a.id} vs ${b.id}`);
      }

      const result = simulateMatchFn(a, b, matchup);
      applyResult(accumulators.get(a.id)!, result.score.a, result.score.b);
      applyResult(accumulators.get(b.id)!, result.score.b, result.score.a);
      matches.push({
        formationAId: a.id,
        formationAName: a.name,
        formationBId: b.id,
        formationBName: b.name,
        scoreA: result.score.a,
        scoreB: result.score.b,
      });
    }
  }

  const sorted = formations.map((formation) => toStanding(accumulators.get(formation.id)!));
  sorted.sort(compareStandings);

  return {
    standings: assignRanks(sorted),
    matches,
  };
}
