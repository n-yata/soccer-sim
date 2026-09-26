export type PositionType = "GK" | "DF" | "MF" | "FW";

/**
 * フォーメーションの特徴タグ。
 *
 * マッチアップの解説文は「組み合わせごとの手書き」ではなく「タグ同士の噛み合わせ」から
 * 生成する（data/matchupRules.ts / data/matchupGenerator.ts）。そのためタグは解説
 * コンテンツの語彙そのものであり、ここに無い特徴はルール表から参照できない。
 *
 * 大半は positions から機械的に導出できるが、`ライン間が空く` のように座標に現れない
 * 特徴もあるため、Formation.extraTags による補完を併用する
 * （導出の実装は data/formationTags.ts の deriveTags / getTags）。
 *
 * 定義をここ（types）に置くのは、Formation がこの型に依存するため。導出ロジック側
 * （data/formationTags.ts）へ置くと types → data の逆流になる。
 */
export type FormationTag =
  | "3バック"
  | "4バック"
  | "1トップ"
  | "2トップ"
  | "3トップ"
  | "ウイング有"
  | "ウイングバック有"
  | "守備的MF2枚"
  | "攻撃的MF3枚"
  | "中盤3枚"
  | "中盤フラット4枚"
  | "中盤実質5枚"
  | "ライン間が空く"
  | "5バック"
  | "中盤ダイヤ"
  | "アンカー1枚";

export interface Position {
  id: string;
  type: PositionType;
  label: string;
  x: number;
  y: number;
}

export type RadarAxisId = "attack" | "defense" | "balance" | "spaceControl" | "pressIntensity";

// 各軸0-100。フォーメーション単体に属する静的な特性値であり、Matchupのa/b入れ替えロジック
// （getMatchupがformationAId/formationBIdの入れ替えに応じてadvantagesForA/B・overallEdgeを
// 反転する処理）とは独立している
export type FormationStats = Record<RadarAxisId, number>;

export interface Formation {
  id: string;
  name: string;
  description: string;
  positions: Position[];
  stats: FormationStats;
  // 座標からは導出できない特徴を補うタグ（data/formationTags.ts の deriveTags で拾えないもの）。
  // 例: 4-4-2 の「ライン間が空く」はFWとMFのy差では表現できない（4-3-3のほうが差が大きくなり
  // 戦術的な意味と逆転する）。省略時は導出タグのみでマッチアップが生成される
  extraTags?: readonly FormationTag[];
}

export interface Matchup {
  id: string;
  formationAId: string;
  formationBId: string;
  // formationAId 側の優位ポイント（箇条書き）。「Aの弱点＝Bの優位点」という対称関係を前提とし、
  // 弱点は独立したフィールドとして持たない
  // readonly: getMatchup が入れ替え時に元データの配列参照をそのまま返すため、
  // 呼び出し側からの書き換えで静的データが破壊されるのを型レベルで防ぐ
  advantagesForA: readonly string[];
  // formationBId 側の優位ポイント（箇条書き）
  advantagesForB: readonly string[];
  // 総合的な優劣判定。"A" = formationAId側がやや有利、"B" = formationBId側がやや有利、
  // "even" = 一方的な優劣がない拮抗した組み合わせ
  overallEdge: "A" | "B" | "even";
  // 総合判定の一言理由（画面上部に見出しとして表示する）。
  // 不変条件: getMatchup は入れ替え時に overallEdge のみ反転し、overallReason はそのまま
  // 返す。そのため overallReason には「Aは」「Bの弱点」のようなA/B相対表現を使わないこと
  // （入れ替え後に逆側のフォーメーションへ誤って適用された文言に見えてしまう）。
  // フォーメーション名を明示するか、中立表現（例:「〜な構成のため上回りやすい」）で書く
  overallReason: string;
}

export type SoccerTermCategory = "ポジション" | "陣形・戦術" | "攻守の考え方";

export interface SoccerTerm {
  id: string;
  term: string;
  reading: string;
  category: SoccerTermCategory;
  // 他のサッカー用語を使わずに説明すること（NFR-02準拠。説明の中に別の専門用語が
  // 出てくると、初心者にとって解決にならないため）
  description: string;
}

// FR-11: 解説文を「平文」と「用語」へ切り出した結果の1区間。
// 文字列ではなく構造として返すことで、描画側は v-html を使わずに済む
// （用語データにHTMLが混入しても描画されない＝XSSの経路を作らない）
export type TextSegment =
  | { kind: "plain"; text: string }
  | { kind: "term"; text: string; term: SoccerTerm };

// FR-12: クイズの選択肢。correct は1問につき必ず1つだけ true になる
export interface QuizChoice {
  id: string;
  label: string;
  correct: boolean;
}

export type QuizQuestionKind = "edge" | "formation" | "advantage";

export interface QuizQuestion {
  id: string;
  kind: QuizQuestionKind;
  prompt: string;
  choices: QuizChoice[];
  // 回答後に表示する根拠。既存データの文言（overallReason / description）を流用し、
  // 新たな専門用語を持ち込まない（NFR-02準拠）
  explanation: string;
  // kind === "formation" のときだけ設定される。ミニピッチ図の描画に使う
  formation?: Formation;
}

// 並べ替えの実装を差し替え可能にするための型。既定は Math.random ベース、
// テストでは決定的な関数を渡す（本番コードにテスト用の分岐を入れないため）
export type Shuffle = <T>(items: readonly T[]) => T[];

// FR-13: 学習進捗。viewedPairs は buildPairKey が返す順序非依存キーの配列
export interface LearningProgress {
  viewedPairs: string[];
}

// FR-14: 試合シミュレーションの1イベント種別。
// "chance"=枠を外れた/防がれた攻撃機会、"shot"=枠内シュート（ゴールにならなかったもの）、
// "goal"=得点。3種類とも composables/matchSimulation.ts の段階的な確率判定に対応する
export type MatchEventKind = "chance" | "shot" | "goal";

export interface MatchEvent {
  // 1-90（分）。同一分に複数のイベントが同時に発生することは無い設計のため、
  // timeline内では単調非減少（実質は昇順）になる
  minute: number;
  team: "A" | "B";
  kind: MatchEventKind;
  // 平易な日本語の一文（分は含まない。分はminuteフィールド側で表現し、表示側が
  // 「{minute}分: {text}」の形で組み立てる。例:「4-2-3-1が追加点を挙げる」）
  text: string;
}

// FR-14: composables/matchSimulation.ts の simulateMatch が返す試合結果。
// a/bは呼び出し時に渡した formationA/formationB にそのまま対応する
// （getMatchup と同様、呼び出し側は「戻り値のa = 呼び出し時のformationA」を前提にできる）
export interface MatchSimulationResult {
  // %。a + b は常に100（bをaの補数として算出するため丸め誤差でも保証される）
  possession: { a: number; b: number };
  shots: { a: number; b: number };
  // shotsOnTarget <= shots を常に満たす
  shotsOnTarget: { a: number; b: number };
  // score(=ゴール数) <= shotsOnTarget を常に満たす
  score: { a: number; b: number };
  // 分昇順のイベント一覧
  timeline: MatchEvent[];
  // 試合結果を要約する平易な日本語の一文（NFR-02準拠）
  summary: string;
}

// リーグ戦: 総当たり1回戦（n(n-1)/2試合）を composables/leagueSimulation.ts の
// runLeagueSimulation が集計した、1フォーメーション分の成績
export interface LeagueStanding {
  formationId: string;
  formationName: string;
  // 勝ち点→得失点差→総得点の順で決定する順位。すべて同値の場合は同順位（同着順位方式。
  // 例: 1位が2チーム並んだ場合、次点は2位ではなく3位になる）
  rank: number;
  played: number;
  win: number;
  draw: number;
  lose: number;
  goalsFor: number;
  goalsAgainst: number;
  // goalsFor - goalsAgainst と常に一致する
  goalDifference: number;
  // win * 3 + draw * 1 と常に一致する
  points: number;
}

// リーグ戦の1試合分の結果。a/bは simulateMatch 呼び出し時の a/b にそのまま対応する
export interface LeagueMatchResult {
  formationAId: string;
  formationAName: string;
  formationBId: string;
  formationBName: string;
  scoreA: number;
  scoreB: number;
}

export interface LeagueSimulationResult {
  // rank昇順に並んでいる
  standings: LeagueStanding[];
  matches: LeagueMatchResult[];
}

// カップ戦: composables/cupSimulation.ts の runCupSimulation が返す1試合分の結果。
// a/bは呼び出し時に渡したFormationにそのまま対応する（LeagueMatchResultと同じ規約）
export interface CupMatch {
  round: 1 | 2 | 3; // 1=準々決勝 2=準決勝 3=決勝
  formationAId: string;
  formationAName: string;
  formationBId: string;
  formationBName: string;
  scoreA: number;
  scoreB: number;
  // 90分で同点だった場合のみtrue。falseの場合penaltyScoreA/Bはundefined
  wentToPenalties: boolean;
  penaltyScoreA?: number;
  penaltyScoreB?: number;
  winnerId: string;
  winnerName: string;
}

// 8フォーメーション固定のノックアウト方式トーナメント結果
export interface CupSimulationResult {
  quarterfinals: CupMatch[]; // 4件。入力formationsの並び順([0]vs[1], [2]vs[3], ...)
  semifinals: CupMatch[]; // 2件
  final: CupMatch;
  championId: string;
  championName: string;
}

// FR-15: 自由配置モードでドラッグした配置の永続化（data/freeLayoutStorage.ts）。
// フォーメーションID単位で保存し、組み合わせ（相手フォーメーション）には依存しない
export type FreeLayoutOverrides = Record<string, Record<string, { x: number; y: number }>>;
