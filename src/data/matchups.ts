import type { Formation, Matchup } from "@/types/formation";
import { formations } from "./formations";
import { buildAllMatchups } from "./matchupGenerator";

// 組み合わせごとの手書きではなく、フォーメーションの特徴タグ同士の噛み合わせルール
// （matchupRules.ts）から生成する。フォーメーションを1種増やしたときに必要な執筆が
// 「既存全件との組み合わせ分の解説文」ではなく「足りないルールの追加」で済むようにするため。

// 生成結果は、供給元（formations）の参照が変わらない限り使い回す。
//
// 本番では formations は再代入されない静的データなので、この分岐は初回しか通らない
// ＝実質「読み込み時に1回だけ生成」である。分岐が意味を持つのはテストで formations を
// 差し替えたときだけ（MatrixPage.test.ts は formations を可変ゲッターでモックし、
// モジュール読み込み後に中身を入れ替える）。素直に1回生成へ固定すると、読み込み時点の
// 空配列で固まり、マトリクスの全セルが無言で「データ無し」になる。
let generatedFrom: readonly Formation[] | null = null;
let generated: Matchup[] = [];

function currentMatchups(): readonly Matchup[] {
  if (generatedFrom !== formations) {
    generatedFrom = formations;
    generated = buildAllMatchups(formations);
  }
  return generated;
}

// 読み込み時点の formations から生成した一覧。
//
// 注意: これは**スナップショット**であり、formations が後から差し替わっても追従しない
// （const の再代入を避けるため）。本番では formations が不変なので getMatchup と常に
// 一致するが、テストのように formations を動的に差し替える文脈では両者が食い違いうる。
// 常に最新を必要とする参照は getMatchup を経由すること。
//
// readonly にしているのは、消費側の sort() 等が内部キャッシュと同一の配列を破壊し、
// getMatchup の結果順序まで巻き込むのを型で止めるため
export const matchups: readonly Matchup[] = currentMatchups();

// フォーメーションAとBの順序に依存せず、同一のマッチアップを返す。
// レコードの格納順序と呼び出し順序が逆の場合は、advantagesForA/Bを入れ替えて返すことで、
// 呼び出し側は常に「戻り値の formationAId = 呼び出し時の formationAId」を前提にできる。
//
// 注意: 入れ替えて返す場合、返り値の id はレコードに格納された正準の id
// （常に "${matchups上のformationAId}_vs_${matchups上のformationBId}"）のままであり、
// 呼び出し時の formationAId/formationBId から機械的に再構成した文字列とは一致しない。
// id はマッチアップの一意識別にのみ使い、画面表示・順序判定には使わないこと。
export function getMatchup(formationAId: string, formationBId: string): Matchup | undefined {
  const found = currentMatchups().find(
    (matchup) =>
      (matchup.formationAId === formationAId && matchup.formationBId === formationBId) ||
      (matchup.formationAId === formationBId && matchup.formationBId === formationAId),
  );
  if (!found) return undefined;
  if (found.formationAId === formationAId) return found;
  return {
    ...found,
    formationAId,
    formationBId,
    advantagesForA: found.advantagesForB,
    advantagesForB: found.advantagesForA,
    // overallEdgeもA/Bの入れ替えに合わせて反転する（evenはそのまま）
    overallEdge:
      found.overallEdge === "A" ? "B" : found.overallEdge === "B" ? "A" : found.overallEdge,
  };
}
