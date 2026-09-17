import { describe, expect, it } from "vitest";
import { annotateText } from "@/data/termAnnotation";
import { soccerTerms } from "@/data/soccerTerms";
import type { SoccerTerm } from "@/types/formation";

function makeTerm(id: string, term: string, description = `${term}の説明`): SoccerTerm {
  return { id, term, reading: term, category: "陣形・戦術", description };
}

describe("annotateText", () => {
  it("用語を含まない文は平文1区間として返す", () => {
    const segments = annotateText("これはただの文章です", [makeTerm("space", "スペース")]);

    expect(segments).toEqual([{ kind: "plain", text: "これはただの文章です" }]);
  });

  it("空文字は空配列を返す", () => {
    expect(annotateText("", soccerTerms)).toEqual([]);
  });

  it("文中の用語を term 区間として切り出す", () => {
    const space = makeTerm("space", "スペース");
    const segments = annotateText("相手のスペースを突く", [space]);

    expect(segments).toEqual([
      { kind: "plain", text: "相手の" },
      { kind: "term", text: "スペース", term: space },
      { kind: "plain", text: "を突く" },
    ]);
  });

  it("用語だけで構成された文は term 区間のみを返す", () => {
    const pressing = makeTerm("pressing", "プレッシング");
    const segments = annotateText("プレッシング", [pressing]);

    expect(segments).toEqual([{ kind: "term", text: "プレッシング", term: pressing }]);
  });

  it("連続して並ぶ用語を、間に空の平文を挟まずに切り出す", () => {
    const midfield = makeTerm("midfield", "中盤");
    const space = makeTerm("space", "スペース");
    const segments = annotateText("中盤スペース", [midfield, space]);

    expect(segments).toEqual([
      { kind: "term", text: "中盤", term: midfield },
      { kind: "term", text: "スペース", term: space },
    ]);
  });

  it("同じ用語が複数回登場したら、そのすべてを切り出す", () => {
    const space = makeTerm("space", "スペース");
    const segments = annotateText("スペースを作りスペースを使う", [space]);

    const termSegments = segments.filter((s) => s.kind === "term");
    expect(termSegments).toHaveLength(2);
  });

  // 最長一致の核心。ここが短い方優先だと本文が別の意味の用語へ静かに化ける
  it("用語が部分的に重なる場合、より長い用語を優先して一致させる", () => {
    const backLine = makeTerm("back-line", "最終ライン");
    const gapBetweenLines = makeTerm("gap-between-lines", "ライン間");
    // 用語リストの並び順に依存しないことを示すため、短い用語を先に渡す
    const segments = annotateText("最終ラインを押し上げる", [gapBetweenLines, backLine]);

    expect(segments).toEqual([
      { kind: "term", text: "最終ライン", term: backLine },
      { kind: "plain", text: "を押し上げる" },
    ]);
  });

  it("短い用語しか一致しない箇所では、短い用語を切り出す", () => {
    const backLine = makeTerm("back-line", "最終ライン");
    const gapBetweenLines = makeTerm("gap-between-lines", "ライン間");
    const segments = annotateText("ライン間で受ける", [gapBetweenLines, backLine]);

    expect(segments).toEqual([
      { kind: "term", text: "ライン間", term: gapBetweenLines },
      { kind: "plain", text: "で受ける" },
    ]);
  });

  it("長い用語が短い用語を完全に含む場合、長いほうを採用する", () => {
    const block = makeTerm("compact-block", "コンパクトな守備ブロック");
    const midfield = makeTerm("midfield", "守備ブロック");
    const segments = annotateText("コンパクトな守備ブロックを崩す", [midfield, block]);

    expect(segments).toEqual([
      { kind: "term", text: "コンパクトな守備ブロック", term: block },
      { kind: "plain", text: "を崩す" },
    ]);
  });

  it("term が空文字の用語があっても無限ループにならず、無視される", () => {
    const empty = makeTerm("empty", "");
    const space = makeTerm("space", "スペース");
    const segments = annotateText("広いスペース", [empty, space]);

    expect(segments).toEqual([
      { kind: "plain", text: "広い" },
      { kind: "term", text: "スペース", term: space },
    ]);
  });

  it("用語リストが空なら全体を平文として返す", () => {
    expect(annotateText("スペースを突く", [])).toEqual([
      { kind: "plain", text: "スペースを突く" },
    ]);
  });

  it("切り出した区間を連結すると元の文字列に戻る（文字の欠落・重複がない）", () => {
    const text = "守備的MFが最終ラインの前でスペースを埋め、ライン間を消す";
    const segments = annotateText(text, soccerTerms);

    expect(segments.map((s) => s.text).join("")).toBe(text);
  });

  it("既定の用語リスト（soccerTerms）で実データの解説文を注釈できる", () => {
    const segments = annotateText("両ウイングが高い位置を取り、相手サイドバックとの1対1を作れる");

    const terms = segments.filter((s) => s.kind === "term").map((s) => s.text);
    expect(terms).toContain("ウイング");
    expect(terms).toContain("サイドバック");
    expect(terms).toContain("1対1");
  });
});
