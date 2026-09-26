import type { Formation, MatchEvent, MatchEventKind, Matchup, MatchSimulationResult } from "@/types/formation";

const MINUTES = 90;

/**
 * FNV-1a（32bit）。matchupGenerator.ts の hash() と同方式で自前実装している。
 *
 * composables/ は data/ に依存しない設計方針（design.md「アーキテクチャ概要」）のため、
 * matchupGenerator.ts から import せず重複させている。ロジックが薄く、2箇所が
 * 将来ズレても実害が無い（どちらも「文字列から決定的な32bit整数を得る」以上の
 * 意味を持たない）ため、依存を増やすより重複を許容する。
 */
// composables/内の他モジュール（cupSimulation.ts=PK戦、squadCondition.ts=選手個体差）が
// 同じ「シードから決定的な乱数列を作る」処理を必要とするためexportする。data/への依存を
// 避けるための重複（このファイル冒頭コメント参照）とは別の話で、同一レイヤー内の共通
// ユーティリティなので重複させない
export function fnv1aHash(input: string): number {
  let value = 0x811c9dc5;
  for (let i = 0; i < input.length; i += 1) {
    value ^= input.charCodeAt(i);
    value = Math.imul(value, 0x01000193) >>> 0;
  }
  return value;
}

/**
 * mulberry32。シードから [0, 1) の疑似乱数列を生成する。
 *
 * Math.random ではなくこれを使うのは、同じシードから常に同じ数列を再現するため
 * （FR-14の決定性要件）。暗号強度は不要（試合展開の見た目の自然さが目的）なので、
 * 実装が小さく高速なこの方式を選んでいる。
 */
export function mulberry32(seed: number): () => number {
  let state = seed;
  return function random(): number {
    state = (state + 0x6d2b79f5) | 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * review-pre-commitの指摘(M-3)対応: value が NaN だと `Math.max(min, NaN)` も
 * `Math.min(max, NaN)` も NaN を素通しする（NaN との比較は常にfalseになるため）。
 * 呼び出し側は `if (random() >= 確率) continue;` の形で使っており、確率がNaNだと
 * 比較が常にfalseになって毎分ゴールが決まるという「静かな誤り」になる。
 * 現状Formation.statsはdata/の静的リテラルのみに由来し有限だが（型では保証されない）、
 * simulateMatchは公開関数であり将来のカスタムフォーメーション入力にも備えて防御する
 */
export function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(max, Math.max(min, value));
}

type Team = "A" | "B";

// --- ポゼッション判定 ---------------------------------------------------------
// spaceControl・pressIntensity が高いほどボールを握りやすく、balance が高いほど
// 安定して保持できるとみなす（各stat 0-100。3項の合計が重みになる）
const POSSESSION_WEIGHT = { spaceControl: 0.4, pressIntensity: 0.35, balance: 0.25 };
// overallEdgeがついている側に加える基礎重み。stats由来の重みは概ね30-100のスケールに
// 収まるため、明確だが逆転しうる差として15を採用（matchupGenerator.tsのEDGE_THRESHOLDとは無関係）
const EDGE_POSSESSION_BONUS = 15;

function possessionWeight(formation: Formation): number {
  const { stats } = formation;
  return (
    stats.spaceControl * POSSESSION_WEIGHT.spaceControl +
    stats.pressIntensity * POSSESSION_WEIGHT.pressIntensity +
    stats.balance * POSSESSION_WEIGHT.balance
  );
}

function choosePossessor(
  a: Formation,
  b: Formation,
  overallEdge: Matchup["overallEdge"],
  random: () => number,
): Team {
  const weightA = possessionWeight(a) + (overallEdge === "A" ? EDGE_POSSESSION_BONUS : 0);
  const weightB = possessionWeight(b) + (overallEdge === "B" ? EDGE_POSSESSION_BONUS : 0);
  const total = weightA + weightB;
  // stats が両者とも全軸0という極端なケースでのみ発生しうる（0除算防止）。五分五分として扱う
  const probabilityA = total === 0 ? 0.5 : weightA / total;
  return random() < probabilityA ? "A" : "B";
}

// --- チャンス→枠内→ゴールの3段階確率判定 --------------------------------------
// 1分あたりチャンス発生の基礎確率。ポゼッション45分（五分五分想定）・diff=0で
// 約10本のチャンス（=シュート数。実際のサッカーの1チーム平均シュート数に近い水準）になり、
// attack-defense差の反映後は概ね6-18本の範囲に収まるよう調整した
const BASE_CHANCE_PROBABILITY = 0.22;
const CHANCE_ATTACK_FACTOR = 0.003;
const CHANCE_PROBABILITY_RANGE = { min: 0.08, max: 0.4 };

const BASE_ON_TARGET_PROBABILITY = 0.45;
const ON_TARGET_ATTACK_FACTOR = 0.002;
const ON_TARGET_PROBABILITY_RANGE = { min: 0.25, max: 0.75 };

const BASE_GOAL_PROBABILITY = 0.3;
const GOAL_ATTACK_FACTOR = 0.003;
const GOAL_PROBABILITY_RANGE = { min: 0.1, max: 0.6 };

function chanceProbability(attacker: Formation, defender: Formation): number {
  const diff = attacker.stats.attack - defender.stats.defense;
  return clamp(
    BASE_CHANCE_PROBABILITY + diff * CHANCE_ATTACK_FACTOR,
    CHANCE_PROBABILITY_RANGE.min,
    CHANCE_PROBABILITY_RANGE.max,
  );
}

function onTargetProbability(attacker: Formation, defender: Formation): number {
  const diff = attacker.stats.attack - defender.stats.defense;
  return clamp(
    BASE_ON_TARGET_PROBABILITY + diff * ON_TARGET_ATTACK_FACTOR,
    ON_TARGET_PROBABILITY_RANGE.min,
    ON_TARGET_PROBABILITY_RANGE.max,
  );
}

function goalProbability(attacker: Formation, defender: Formation): number {
  const diff = attacker.stats.attack - defender.stats.defense;
  return clamp(
    BASE_GOAL_PROBABILITY + diff * GOAL_ATTACK_FACTOR,
    GOAL_PROBABILITY_RANGE.min,
    GOAL_PROBABILITY_RANGE.max,
  );
}

// --- イベント文言 -------------------------------------------------------------

/**
 * ゴールの文言は、それまでのスコア推移に応じて言い回しを変える
 * （先制/同点/勝ち越し/追加点）。呼び出し時点ではまだ今回の得点を加算する前の
 * スコアを渡すこと（「加算前の状態」から見た意味づけのため）。
 */
function goalText(teamName: string, scoreBeforeSelf: number, scoreBeforeOpponent: number): string {
  if (scoreBeforeSelf === 0 && scoreBeforeOpponent === 0) {
    return `${teamName}が先制点を奪う`;
  }
  if (scoreBeforeSelf === scoreBeforeOpponent) {
    return `${teamName}が勝ち越しゴールを決める`;
  }
  if (scoreBeforeSelf + 1 === scoreBeforeOpponent) {
    return `${teamName}が同点に追いつく`;
  }
  // review-pre-commitの指摘(M-2)対応: 「同点に追いつく」は1点差のビハインドにしか
  // 一致しないため、2点以上のビハインド（例: 1-3から得点）を「追加点」と誤表示していた。
  // ビハインドの大きさに関わらず「差を詰める」意味の文言にする
  if (scoreBeforeSelf < scoreBeforeOpponent) {
    return `${teamName}が1点を返す`;
  }
  return `${teamName}が追加点を挙げる`;
}

function eventText(kind: MatchEventKind, teamName: string, goalLabel?: string): string {
  if (kind === "goal") return goalLabel ?? `${teamName}が得点を決める`;
  if (kind === "shot") return `${teamName}の枠内シュートをGKが防ぐ`;
  return `${teamName}にチャンスがあったが枠を外れる`;
}

// --- サマリー文 ----------------------------------------------------------------

function buildSummary(
  a: Formation,
  b: Formation,
  score: { a: number; b: number },
  possession: { a: number; b: number },
  shots: { a: number; b: number },
): string {
  if (score.a === score.b) {
    return `${a.name}と${b.name}は${score.a}-${score.b}の互角の展開で決着がつかなかった。`;
  }

  const aWins = score.a > score.b;
  const winner = aWins ? a : b;
  const loser = aWins ? b : a;
  const winnerScore = aWins ? score.a : score.b;
  const loserScore = aWins ? score.b : score.a;

  // 勝者側の優位性が最も大きかった指標を1つ選び、サマリーの根拠にする。
  // ポゼッション（%）とシュート数（本）は単位が違うため差分を直接比較できない。
  // それぞれ「勝者が優位だったか」だけを見て、両方とも優位なら差が大きい方を、
  // 両方とも劣勢（内容以上の結果で逃げ切った）なら専用の言い回しにする
  const possessionDiff = aWins ? possession.a - possession.b : possession.b - possession.a;
  const shotsDiff = aWins ? shots.a - shots.b : shots.b - shots.a;

  // review-pre-commitの指摘(L-2)対応: ポゼッション差が僅差（例: 51%対49%）でも
  // 「支配し」と言い切ると内容と文言が釣り合わない。明確な差がある場合だけ
  // 「支配」を使い、僅差なら控えめな表現にする
  const DOMINANCE_THRESHOLD = 10;

  let differentiator: string;
  if (possessionDiff <= 0 && shotsDiff <= 0) {
    differentiator = "内容面で上回れない時間帯もありながら、数少ない好機を確実に決め";
  } else if (possessionDiff >= shotsDiff) {
    const winnerPossession = aWins ? possession.a : possession.b;
    differentiator =
      possessionDiff >= DOMINANCE_THRESHOLD
        ? `ボール保持率${winnerPossession}%で試合を支配し`
        : `ボール保持率${winnerPossession}%でわずかに上回り`;
  } else {
    differentiator = `シュート${aWins ? shots.a : shots.b}本と積極的に攻め`;
  }

  return `${winner.name}が${winnerScore}-${loserScore}で${loser.name}を下した。${differentiator}きった試合だった。`;
}

/**
 * ハーフタイム時点（90分に満たない途中経過）の中立なサマリー文。
 * buildSummary と違い「下した」等の決着表現を使わない（まだ試合が終わっていないため）。
 */
function buildHalftimeSummary(a: Formation, b: Formation, score: { a: number; b: number }): string {
  if (score.a === score.b) {
    return `前半終了。${a.name}と${b.name}は${score.a}-${score.b}の互角の展開。`;
  }
  const aLeads = score.a > score.b;
  const leader = aLeads ? a : b;
  const leaderScore = aLeads ? score.a : score.b;
  const trailerScore = aLeads ? score.b : score.a;
  return `前半終了。${leader.name}が${leaderScore}-${trailerScore}でリードしている。`;
}

// --- 90分（または途中まで）の累計状態 -----------------------------------------

interface SimAccumulator {
  possessionMinutes: Record<Team, number>;
  shots: Record<Team, number>;
  shotsOnTarget: Record<Team, number>;
  score: Record<Team, number>;
  timeline: MatchEvent[];
}

function createAccumulator(): SimAccumulator {
  return {
    possessionMinutes: { A: 0, B: 0 },
    shots: { A: 0, B: 0 },
    shotsOnTarget: { A: 0, B: 0 },
    score: { A: 0, B: 0 },
    timeline: [],
  };
}

/**
 * `fromMinute`〜`toMinute`（両端含む）ぶんのイベント駆動シミュレーションを`acc`に積み上げる。
 * 呼び出し側は必ず「matchup.idが想定する正準順」でa/b/overallEdgeを揃えて渡すこと
 * （順序に関する決定性の保証はこの関数の外、simulateMatch/startMatch/resumeMatchが担う）。
 * `random`は呼び出しをまたいで同一インスタンスを使い続けることで、前半・後半を
 * 分けて呼んでも90分通しで呼んだ場合と同じ乱数列になる。
 */
function simulateMinuteRange(
  acc: SimAccumulator,
  a: Formation,
  b: Formation,
  overallEdge: Matchup["overallEdge"],
  random: () => number,
  fromMinute: number,
  toMinute: number,
): void {
  const formationOf: Record<Team, Formation> = { A: a, B: b };
  const opponentOf: Record<Team, Formation> = { A: b, B: a };

  for (let minute = fromMinute; minute <= toMinute; minute += 1) {
    const possessor = choosePossessor(a, b, overallEdge, random);
    acc.possessionMinutes[possessor] += 1;

    const attacker = formationOf[possessor];
    const defender = opponentOf[possessor];

    if (random() >= chanceProbability(attacker, defender)) continue;
    acc.shots[possessor] += 1;

    if (random() >= onTargetProbability(attacker, defender)) {
      acc.timeline.push({ minute, team: possessor, kind: "chance", text: eventText("chance", attacker.name) });
      continue;
    }
    acc.shotsOnTarget[possessor] += 1;

    if (random() >= goalProbability(attacker, defender)) {
      acc.timeline.push({ minute, team: possessor, kind: "shot", text: eventText("shot", attacker.name) });
      continue;
    }

    const opponentTeam: Team = possessor === "A" ? "B" : "A";
    const label = goalText(attacker.name, acc.score[possessor], acc.score[opponentTeam]);
    acc.score[possessor] += 1;
    acc.timeline.push({ minute, team: possessor, kind: "goal", text: eventText("goal", attacker.name, label) });
  }
}

/**
 * `acc`の累計値から`MatchSimulationResult`を組み立てる。
 * `totalMinutes`は経過分母（90分通しなら90、ハーフタイム時点の中間表示なら45）。
 * `totalMinutes < 90`のときは決着を前提としない`buildHalftimeSummary`を使う。
 */
function finalizeResult(a: Formation, b: Formation, acc: SimAccumulator, totalMinutes: number): MatchSimulationResult {
  const possessionA = Math.round((acc.possessionMinutes.A / totalMinutes) * 100);
  const possession = { a: possessionA, b: 100 - possessionA };
  const shots = { a: acc.shots.A, b: acc.shots.B };
  const shotsOnTarget = { a: acc.shotsOnTarget.A, b: acc.shotsOnTarget.B };
  const score = { a: acc.score.A, b: acc.score.B };

  return {
    possession,
    shots,
    shotsOnTarget,
    score,
    // acc.timelineへの参照をそのまま返すと、finalizeResult(45分時点)の戻り値を
    // 保持したまま同じacc(=progress.acc)でresumeMatchを呼んだ場合に、
    // 「前半の部分結果」の配列が後から90分ぶんへ書き換わってしまう。コピーして切り離す
    timeline: [...acc.timeline],
    summary:
      totalMinutes >= MINUTES
        ? buildSummary(a, b, score, possession, shots)
        : buildHalftimeSummary(a, b, score),
  };
}

function mirrorResult(result: MatchSimulationResult): MatchSimulationResult {
  return {
    possession: { a: result.possession.b, b: result.possession.a },
    shots: { a: result.shots.b, b: result.shots.a },
    shotsOnTarget: { a: result.shotsOnTarget.b, b: result.shotsOnTarget.a },
    score: { a: result.score.b, b: result.score.a },
    // summary はフォーメーション名（.name）で書かれておりA/Bのラベルを含まないため、
    // 鏡写しにしても文言はそのまま正しい（types/formation.tsのMatchup.overallReasonと
    // 同じ理由。「A/B相対表現を使わない」設計を踏襲している）
    summary: result.summary,
    timeline: result.timeline.map((event) => ({
      ...event,
      team: event.team === "A" ? "B" : "A",
    })),
  };
}

/**
 * matchup.overallEdge は「呼び出し時のa/b」を基準にした値。正準順（matchup.idの前半をAとする順）
 * で計算する前に、必要なら正準の向きへ反転させる。
 */
function mirrorEdgeIfNeeded(edge: Matchup["overallEdge"], reversed: boolean): Matchup["overallEdge"] {
  if (!reversed) return edge;
  if (edge === "A") return "B";
  if (edge === "B") return "A";
  return "even";
}

/**
 * 呼び出し時のa/bがmatchup.idの正準順と一致するか（一致しない＝鏡写しが必要）を判定する。
 * review-pre-commitの指摘(L-1)対応: matchup.idを"_vs_"で分割して比較すると、
 * フォーメーションidそのものに"_vs_"が含まれる場合に誤判定しうる。idの前半が
 * a.idと一致するかを直接調べる方が壊れにくい。
 */
function isReversed(a: Formation, matchup: Matchup): boolean {
  return !matchup.id.startsWith(`${a.id}_vs_`);
}

/**
 * 試合の途中経過を表す不透明な状態。`startMatch`が生成し`resumeMatch`に渡す以外の
 * 用途を想定しない（呼び出し側はフィールドを直接読み書きしない）。
 */
export interface MatchProgress {
  reversed: boolean;
  random: () => number;
  acc: SimAccumulator;
  throughMinute: number;
  // resumeMatchで一度消費されたことを示す。同じprogressを2回resumeMatchに渡すと
  // 46分目以降が二重加算される（accが破壊的に累積するため）。呼び出し側の実装ミスを
  // 早期に検知できるよう、2回目の呼び出しはエラーにする
  consumed: boolean;
}

/**
 * 試合開始から`throughMinute`分（既定45=前半終了）までを計算する。
 * 続きは`resumeMatch`で計算できる。
 *
 * 決定性・鏡写しのルールは`simulateMatch`と同じ（内部で同じヘルパーを共有する）。
 */
export function startMatch(
  a: Formation,
  b: Formation,
  matchup: Matchup,
  throughMinute = 45,
): { progress: MatchProgress; result: MatchSimulationResult } {
  const reversed = isReversed(a, matchup);
  const canonicalA = reversed ? b : a;
  const canonicalB = reversed ? a : b;
  const canonicalEdge = mirrorEdgeIfNeeded(matchup.overallEdge, reversed);

  const seed = fnv1aHash(matchup.id);
  const random = mulberry32(seed);
  const acc = createAccumulator();
  simulateMinuteRange(acc, canonicalA, canonicalB, canonicalEdge, random, 1, throughMinute);

  const partial = finalizeResult(canonicalA, canonicalB, acc, throughMinute);
  const progress: MatchProgress = { reversed, random, acc, throughMinute, consumed: false };
  return { progress, result: reversed ? mirrorResult(partial) : partial };
}

/**
 * `startMatch`の続きから90分目までを計算する。
 * a/b/matchupは後半に使うフォーメーション・マッチアップ（配置変更が無ければ
 * `startMatch`に渡したものと同じ値を渡す）。`progress`が保持する乱数インスタンスを
 * そのまま継続するため、配置を変更しなければ`simulateMatch`を90分通しで1回呼んだ
 * 場合と完全に同じ結果になる（決定性・後方互換性）。
 */
export function resumeMatch(progress: MatchProgress, a: Formation, b: Formation, matchup: Matchup): MatchSimulationResult {
  if (progress.consumed) {
    throw new Error("resumeMatch: このMatchProgressは既に使用済みです（同じprogressを2回resumeMatchに渡すことはできません）");
  }
  const canonicalA = progress.reversed ? b : a;
  const canonicalB = progress.reversed ? a : b;
  const canonicalEdge = mirrorEdgeIfNeeded(matchup.overallEdge, progress.reversed);

  simulateMinuteRange(progress.acc, canonicalA, canonicalB, canonicalEdge, progress.random, progress.throughMinute + 1, MINUTES);
  progress.consumed = true;

  const result = finalizeResult(canonicalA, canonicalB, progress.acc, MINUTES);
  return progress.reversed ? mirrorResult(result) : result;
}

/**
 * 2つのフォーメーションの対戦を、90分・1分刻みのイベント駆動でシミュレーションする。
 *
 * 決定性: 「組み合わせ」は呼び出し順に依存しない不変条件とする（FR-14の受け入れ条件、
 * および getMatchup / buildPairKey が組み合わせを順序非依存に扱う既存の設計と揃える）。
 * これを満たすため、内部計算は常に matchup.id が示す正準順（`${正準A}_vs_${正準B}`の
 * 前半側をAとする）で行い、呼び出し時のa/bが正準順と逆であれば結果を鏡写しにして返す。
 * こうすることで、A/Bを入れ替えて呼んでも「同じ90分の試合」を見ることになり、
 * 勝敗が呼び出し順によって変わることがない。
 */
export function simulateMatch(a: Formation, b: Formation, matchup: Matchup): MatchSimulationResult {
  return startMatch(a, b, matchup, MINUTES).result;
}
