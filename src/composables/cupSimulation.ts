import { fnv1aHash, mulberry32, simulateMatch } from "@/composables/matchSimulation";
import type { CupMatch, CupSimulationResult, Formation, MatchSimulationResult, Matchup } from "@/types/formation";

// PK戦のキッカー1人あたりの成功確率。実際のPK成功率の目安値として固定する。
// フォーメーションのstats（戦術的特性）はPK戦の確率に反映しない。現実のPKも
// 技術・メンタルの要素が大きく、陣形の戦術的特性とは独立した事象として扱う方が
// 単純で、実装コストに見合う
const PK_SUCCESS_PROBABILITY = 0.75;
const PK_REGULAR_ROUNDS = 5;

/**
 * PK戦を決定的にシミュレーションする。5人ずつのキッカーが順に成功確率一定でシュートし、
 * 5人終了時点で同点ならサドンデス（1人ずつ交互に、どちらか一方だけが決めた時点で打ち切り）
 * で必ず決着させる。無限ループにはならない（各ラウンドで「片方だけ決める」事象が
 * 確率的に必ずいずれか発生するため）。
 */
function simulatePenaltyShootout(seed: number): { scoreA: number; scoreB: number } {
  const random = mulberry32(seed);
  let scoreA = 0;
  let scoreB = 0;

  for (let round = 1; round <= PK_REGULAR_ROUNDS; round += 1) {
    if (random() < PK_SUCCESS_PROBABILITY) scoreA += 1;
    if (random() < PK_SUCCESS_PROBABILITY) scoreB += 1;
  }

  while (scoreA === scoreB) {
    const aScored = random() < PK_SUCCESS_PROBABILITY;
    const bScored = random() < PK_SUCCESS_PROBABILITY;
    if (aScored) scoreA += 1;
    if (bScored) scoreB += 1;
  }

  return { scoreA, scoreB };
}

function playMatch(
  round: CupMatch["round"],
  a: Formation,
  b: Formation,
  getMatchupFn: (formationAId: string, formationBId: string) => Matchup | undefined,
  simulateMatchFn: (a: Formation, b: Formation, matchup: Matchup) => MatchSimulationResult,
): CupMatch {
  const matchup = getMatchupFn(a.id, b.id);
  if (!matchup) {
    throw new Error(`カップ戦の対戦に必要なマッチアップが見つかりません: ${a.id} vs ${b.id}`);
  }

  const result = simulateMatchFn(a, b, matchup);
  const { score } = result;

  if (score.a !== score.b) {
    const winner = score.a > score.b ? a : b;
    return {
      round,
      formationAId: a.id,
      formationAName: a.name,
      formationBId: b.id,
      formationBName: b.name,
      scoreA: score.a,
      scoreB: score.b,
      wentToPenalties: false,
      winnerId: winner.id,
      winnerName: winner.name,
    };
  }

  // 90分の試合本体（matchup.idそのものをシードにする runCanonicalSimulation）とは
  // 独立した乱数列にするため、別の文字列をハッシュしたシードを使う。
  //
  // matchup.idは常に「レコードに格納された正準順」（呼び出し時のa/bの順序では反転しない。
  // data/matchups.tsのgetMatchupのコメント参照）のため、シード自体はa/bの呼び出し順に
  // 依存しない。しかしPK戦の結果（scoreA/scoreB）をそのままa/bへ割り当てると、
  // 同じ対戦カードでも呼び出し順が逆なら勝者が入れ替わってしまう
  // （simulateMatchが mirrorResult で保証している「呼び出し順に依存しない」という
  // 既存の不変条件から外れる）。正準順で解いてから、呼び出し順が逆なら結果を入れ替える
  const reversed = !matchup.id.startsWith(`${a.id}_vs_`);
  const pkSeed = fnv1aHash(`${matchup.id}_pk`);
  const canonicalPk = simulatePenaltyShootout(pkSeed);
  const pk = reversed
    ? { scoreA: canonicalPk.scoreB, scoreB: canonicalPk.scoreA }
    : canonicalPk;
  const winner = pk.scoreA > pk.scoreB ? a : b;

  return {
    round,
    formationAId: a.id,
    formationAName: a.name,
    formationBId: b.id,
    formationBName: b.name,
    scoreA: score.a,
    scoreB: score.b,
    wentToPenalties: true,
    penaltyScoreA: pk.scoreA,
    penaltyScoreB: pk.scoreB,
    winnerId: winner.id,
    winnerName: winner.name,
  };
}

/**
 * 8フォーメーション固定のノックアウト方式トーナメント（準々決勝4試合→準決勝2試合→決勝1試合）を
 * 既存の simulateMatch を使って決定的に実行する。
 *
 * composables/ は data/ に依存しない設計方針（matchSimulation.ts 冒頭コメント）のため、
 * マッチアップの導出は runLeagueSimulation と同じくDIで呼び出し側から関数として注入する。
 *
 * 対戦カードは「渡された formations の並び順」を固定シードとする
 * （[0]vs[1], [2]vs[3], [4]vs[5], [6]vs[7] が準々決勝、勝者を配列順のまま
 * 準決勝・決勝へ進める）。フォーメーション数が8以外の場合はカップ戦として
 * 成立しないため Error を投げる（9種類以上への拡張時の不戦勝対応は将来課題）。
 */
export function runCupSimulation(
  formations: Formation[],
  getMatchupFn: (formationAId: string, formationBId: string) => Matchup | undefined,
  simulateMatchFn: (a: Formation, b: Formation, matchup: Matchup) => MatchSimulationResult = simulateMatch,
): CupSimulationResult {
  if (formations.length !== 8) {
    throw new Error(`カップ戦は8フォーメーション限定です（受け取った数: ${formations.length}）`);
  }

  const byId = new Map(formations.map((formation) => [formation.id, formation]));
  const winnerFormation = (match: CupMatch): Formation => byId.get(match.winnerId)!;

  const quarterfinals: CupMatch[] = [];
  for (let i = 0; i < 8; i += 2) {
    quarterfinals.push(playMatch(1, formations[i], formations[i + 1], getMatchupFn, simulateMatchFn));
  }

  const semifinals: CupMatch[] = [
    playMatch(2, winnerFormation(quarterfinals[0]), winnerFormation(quarterfinals[1]), getMatchupFn, simulateMatchFn),
    playMatch(2, winnerFormation(quarterfinals[2]), winnerFormation(quarterfinals[3]), getMatchupFn, simulateMatchFn),
  ];

  const final = playMatch(
    3,
    winnerFormation(semifinals[0]),
    winnerFormation(semifinals[1]),
    getMatchupFn,
    simulateMatchFn,
  );

  return {
    quarterfinals,
    semifinals,
    final,
    championId: final.winnerId,
    championName: final.winnerName,
  };
}
