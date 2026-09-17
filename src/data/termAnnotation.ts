import { soccerTerms } from "@/data/soccerTerms";
import type { SoccerTerm, TextSegment } from "@/types/formation";

// 長さ降順に並べ替えた用語リストのキャッシュ。
// annotateText は解説文1本ごと・再描画ごとに呼ばれるため、呼び出しのたびに
// 並べ替えると無駄が積み上がる。引数の配列参照をキーにして一度だけ作る。
// 件数(size)もあわせて記録し、同じ配列参照のまま要素が push/splice で
// 増減した場合はキャッシュを作り直す（参照だけを見ると古い並びを返し続け、
// 新しく追加した用語が永久に注釈されない静かな欠陥になるため）。
const sortedCache = new WeakMap<readonly SoccerTerm[], { size: number; sorted: SoccerTerm[] }>();

function sortByLengthDesc(terms: readonly SoccerTerm[]): SoccerTerm[] {
  const cached = sortedCache.get(terms);
  if (cached && cached.size === terms.length) return cached.sorted;
  const sorted = [...terms].sort((a, b) => b.term.length - a.term.length);
  sortedCache.set(terms, { size: terms.length, sorted });
  return sorted;
}

/**
 * 解説文を「平文」と「登録済みサッカー用語」の区間へ切り出す（FR-11）。
 *
 * 各位置から始まる用語のうち**最長のもの**を採用する。用語同士は部分的に重なりうるため
 * （「最終ライン」と「ライン間」、「守備的MF」と「中盤」など）、短いほうを先に採ると
 * 「最終ラ」「イン間」のように本文が別の意味の用語へ静かに化ける。
 *
 * 戻り値は文字列ではなく構造。描画側は v-for + {{ }} で組み立てるため、
 * 用語データにHTMLが混入しても描画されない。
 */
export function annotateText(
  text: string,
  terms: readonly SoccerTerm[] = soccerTerms,
): TextSegment[] {
  if (!text) return [];

  const sorted = sortByLengthDesc(terms);
  const segments: TextSegment[] = [];
  let plainStart = 0;
  let cursor = 0;

  while (cursor < text.length) {
    // term が空文字の用語は cursor を進めずに無限ループを作るため対象外にする
    const matched = sorted.find((t) => t.term.length > 0 && text.startsWith(t.term, cursor));

    if (!matched) {
      cursor += 1;
      continue;
    }

    if (plainStart < cursor) {
      segments.push({ kind: "plain", text: text.slice(plainStart, cursor) });
    }
    segments.push({ kind: "term", text: matched.term, term: matched });
    cursor += matched.term.length;
    plainStart = cursor;
  }

  if (plainStart < text.length) {
    segments.push({ kind: "plain", text: text.slice(plainStart) });
  }

  return segments;
}
