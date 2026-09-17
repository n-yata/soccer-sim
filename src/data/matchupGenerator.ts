import type { Formation, Matchup, RadarAxisId } from "@/types/formation";
import { getTags, type FormationTag } from "./formationTags";
import { matchupRules, type MatchupRule } from "./matchupRules";

/**
 * 総合優劣の判定しきい値。スコア差がこの値以上で「やや優位」と判定する。
 *
 * この値は「どれだけ差がついたら優劣を断言するか」という表現上の基準であり、
 * 個々の組み合わせの判定を期待どおりにする調整つまみではない。判定が意図と合わない
 * ときは、ここではなくルール表（片側にだけルールが厚い＝左右非対称）を直すこと。
 * ここで辻褄を合わせると、フォーメーションを追加した瞬間に全組の判定が崩れる。
 */
const EDGE_THRESHOLD = 2;

/**
 * 総合判定の見出しに並べる根拠の最大数。1つだと情報が薄く、3つ以上だと一文が長すぎて
 * 画面上部の見出しとして読めなくなるため2つにしている。
 */
const REASON_COUNT = 2;

/** FNV-1a（32bit）。Math.random を使わず、同じ入力から常に同じ添字を得るために使う */
function hash(input: string): number {
  let value = 0x811c9dc5;
  for (let i = 0; i < input.length; i += 1) {
    value ^= input.charCodeAt(i);
    // 32bit FNV prime (16777619) の乗算。>>> 0 で符号なし32bitへ畳み込む
    value = Math.imul(value, 0x01000193) >>> 0;
  }
  return value;
}

/**
 * 候補から1つを決定的に選ぶ。添字を返すのは、左右で別の言い回しを選ぶために
 * 「相手側が何番目を選んだか」を知る必要があるため（pickIndexAvoiding 参照）。
 *
 * Math.random を使うと、同じデータから実行のたびに違う文言が出てしまい、
 * 「画面を開き直すと解説が変わる」「テストが不安定になる」という二重の害がある。
 */
function pickIndex(candidatesLength: number, seed: string): number {
  return hash(seed) % candidatesLength;
}

/**
 * 相手側が使った添字を避けて選ぶ。
 *
 * 同じルールが左右両方で発火することがある（双方が同じタグを持ち、かつ相手条件も双方が
 * 満たす場合。例: 1トップ同士・4バック同士の組み合わせで「1トップが相手のセンターバックを
 * ピン留めできる」が両側に成立する）。このとき同じ添字が選ばれると**一字一句同じ文が
 * 左右に並ぶ**。既存の重複検知は片側の配列内しか見ないため、テストは緑のまま画面だけが
 * 破綻する。
 *
 * ハッシュのシードを変えるだけでは「偶然一致しない」にとどまるため、相手の添字から
 * 確実にずらす。言い回しが1つしか無いルールでは避けようがないので、その場合は同じものを
 * 返す（matchupGenerator.test.ts の左右重複テストが検知する）。
 */
function pickIndexAvoiding(candidatesLength: number, avoid: number): number {
  if (candidatesLength <= 1) return 0;
  return (avoid + 1) % candidatesLength;
}

function matches(
  rule: MatchupRule,
  selfTags: FormationTag[],
  opponentTags: FormationTag[],
): boolean {
  return (
    rule.selfTags.every((tag) => selfTags.includes(tag)) &&
    rule.opponentTags.every((tag) => opponentTags.includes(tag))
  );
}

/**
 * 適用ルールを matchupRules の配列順で返す。ただし**同一テーマからは1件だけ**。
 *
 * 配列順は「噛み合わせへの影響が大きい順」であり（matchupRules.ts の先頭コメント参照）、
 * 優位ポイントの並び順と総合判定の見出しに使う根拠の優先順位を兼ねている。
 * したがって同一テーマ内で残すのは「先に来たもの」でよい。
 *
 * テーマによる間引きが無いと、同じ戦術を別の切り口で書いたルールが同時に当たり、
 * ほぼ同じ文が2行並ぶうえ score が二重に積まれる。文字列としては異なるため重複検知に
 * かからず、テストは緑のまま総合判定だけが片側へ静かに歪む（RuleTheme のコメント参照）。
 */
function applicableRules(selfTags: FormationTag[], opponentTags: FormationTag[]): MatchupRule[] {
  const usedThemes = new Set<MatchupRule["theme"]>();
  const selected: MatchupRule[] = [];
  for (const rule of matchupRules) {
    if (!matches(rule, selfTags, opponentTags)) continue;
    if (usedThemes.has(rule.theme)) continue;
    usedThemes.add(rule.theme);
    selected.push(rule);
  }
  return selected;
}

/**
 * ルールが1件も当たらない側に使う汎用文。stats の最も高い軸から作る。
 *
 * stats は総合優劣の算出には使わない（使うと「噛み合わせ」ではなく単なる数値比較になる）。
 * ここでだけ使うのは、優位ポイントが空欄のまま表示される事故を防ぐためである
 * （空配列は matchups.test.ts が検知して落ちる）。
 */
const FALLBACK_BY_AXIS: Record<RadarAxisId, { advantage: string; reason: string }> = {
  attack: {
    advantage: "前線に人数をかけられるため、相手のゴール前へ圧力をかけやすい",
    reason: "前線の厚みで相手のゴール前へ圧力をかけやすい点",
  },
  defense: {
    advantage: "後ろに人数を残せるため、自陣のゴール前を固めやすい",
    reason: "後ろの人数で自陣のゴール前を固めやすい点",
  },
  balance: {
    advantage: "人数の配分が偏らないため、攻守のどちらにも対応しやすい",
    reason: "人数の配分が偏らず攻守のどちらにも対応しやすい点",
  },
  spaceControl: {
    advantage: "ピッチの幅を広く使えるため、相手の守備を広げてスペースを作りやすい",
    reason: "ピッチの幅を使って相手の守備にスペースを作らせやすい点",
  },
  pressIntensity: {
    advantage: "選手同士の距離が近いため、素早いプレッシングをかけやすい",
    reason: "選手同士の距離が近く素早いプレッシングをかけやすい点",
  },
};

// 最大値が並んだときの優先順位。Object.keys の列挙順に依存すると、stats の
// キー記述順を入れ替えただけで解説文が変わってしまうためここで固定する
const FALLBACK_AXIS_ORDER: readonly RadarAxisId[] = [
  "attack",
  "defense",
  "balance",
  "spaceControl",
  "pressIntensity",
];

function fallbackFor(formation: Formation): { advantage: string; reason: string } {
  const best = FALLBACK_AXIS_ORDER.reduce((current, axis) =>
    formation.stats[axis] > formation.stats[current] ? axis : current,
  );
  return FALLBACK_BY_AXIS[best];
}

/**
 * ルールを適用してマッチアップ1件を組み立てる。
 *
 * 引数の順序がそのまま formationAId / formationBId になる。呼び出し側は
 * buildAllMatchups と同じ正準順序（formations の配列順で i < j）で渡すこと。
 */
export function generateMatchup(a: Formation, b: Formation): Matchup {
  const tagsA = getTags(a);
  const tagsB = getTags(b);
  const rulesA = applicableRules(tagsA, tagsB);
  const rulesB = applicableRules(tagsB, tagsA);

  const pairId = `${a.id}_vs_${b.id}`;
  const fallbackA = fallbackFor(a);
  const fallbackB = fallbackFor(b);

  // A側を先に決め、使った添字をルールIDで覚えておく。B側は同じルールが発火していたら
  // その添字を避ける（pickIndexAvoiding 参照）。順序に依存するが、buildAllMatchups が
  // 常に正準順序（formations の配列順で i < j）で呼ぶため結果は決定的
  const indexByRuleA = new Map<string, number>();
  const advantagesForA =
    rulesA.length > 0
      ? rulesA.map((rule) => {
          const index = pickIndex(rule.advantages.length, `${pairId}:${rule.id}`);
          indexByRuleA.set(rule.id, index);
          return rule.advantages[index];
        })
      : [fallbackA.advantage];
  const advantagesForB =
    rulesB.length > 0
      ? rulesB.map((rule) => {
          const usedByA = indexByRuleA.get(rule.id);
          const index =
            usedByA === undefined
              ? pickIndex(rule.advantages.length, `${pairId}:${rule.id}`)
              : pickIndexAvoiding(rule.advantages.length, usedByA);
          return rule.advantages[index];
        })
      : [fallbackB.advantage];

  const reasonsA = rulesA.length > 0 ? rulesA.map((rule) => rule.reason) : [fallbackA.reason];
  const reasonsB = rulesB.length > 0 ? rulesB.map((rule) => rule.reason) : [fallbackB.reason];

  const scoreA = rulesA.reduce((total, rule) => total + rule.score, 0);
  const scoreB = rulesB.reduce((total, rule) => total + rule.score, 0);
  const diff = scoreA - scoreB;
  const overallEdge: Matchup["overallEdge"] =
    diff >= EDGE_THRESHOLD ? "A" : diff <= -EDGE_THRESHOLD ? "B" : "even";

  return {
    id: pairId,
    formationAId: a.id,
    formationBId: b.id,
    advantagesForA,
    advantagesForB,
    overallEdge,
    overallReason: buildOverallReason(overallEdge, { a, b, reasonsA, reasonsB }),
  };
}

/**
 * 総合判定の見出しを組み立てる。
 *
 * フォーメーション名を明示し、「Aは」「Bの」といったA/B相対表現は使わない。
 * getMatchup は引き渡し順が逆のとき overallEdge だけを反転し overallReason は
 * そのまま返すため、相対表現が入ると逆側を指す文言として表示される（types/formation.ts
 * の不変条件）。
 */
function buildOverallReason(
  edge: Matchup["overallEdge"],
  context: { a: Formation; b: Formation; reasonsA: string[]; reasonsB: string[] },
): string {
  const { a, b, reasonsA, reasonsB } = context;

  if (edge === "even") {
    // 同じルールが左右で発火すると根拠の文が一致する（1トップ同士・4バック同士など）。
    // そのまま「〜点と、〜点が拮抗しており」の型へ入れると同じ内容を2回繰り返す文になるため、
    // 「どちらも同じ強みを持つ」という意味の型へ切り替える
    if (reasonsA[0] === reasonsB[0]) {
      return `${a.name}と${b.name}はどちらも${reasonsA[0]}で並んでおり、優劣がつきにくい`;
    }
    return `${a.name}の${reasonsA[0]}と、${b.name}の${reasonsB[0]}が拮抗しており、優劣がつきにくい`;
  }

  const winner = edge === "A" ? a : b;
  const reasons = (edge === "A" ? reasonsA : reasonsB).slice(0, REASON_COUNT);
  return `${winner.name}は、${reasons.join("と")}が効いており、噛み合わせで優位に立ちやすい`;
}

/**
 * 全フォーメーションの2件組み合わせ（n(n-1)/2 通り）を生成する。
 *
 * formations の配列順で i < j の組を作るため、formationAId は常に配列前方になる。
 * これは matchups.ts の既存レコードが守っていた正準順序と同じであり、getMatchup の
 * 入れ替えロジックがそのまま成り立つ前提になっている。
 */
export function buildAllMatchups(formations: readonly Formation[]): Matchup[] {
  const result: Matchup[] = [];
  for (let i = 0; i < formations.length; i += 1) {
    for (let j = i + 1; j < formations.length; j += 1) {
      result.push(generateMatchup(formations[i], formations[j]));
    }
  }
  return result;
}
