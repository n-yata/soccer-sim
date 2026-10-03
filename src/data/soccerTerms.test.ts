import { describe, it, expect } from "vitest";
import { soccerTerms } from "./soccerTerms";
import { matchups } from "./matchups";
import { radarAxes } from "./radarAxes";
import { formations } from "./formations";
import { formationLessons } from "./formationLessons";

// soccerTerms.ts の先頭コメントが宣言する「実際に登場する用語のみを収録する（推測で
// 追加しない）」という不変条件を、正本（matchups.ts等の実文言）から独立に検証する
const sourceText = [
  ...matchups.flatMap((matchup) => [
    ...matchup.advantagesForA,
    ...matchup.advantagesForB,
    matchup.overallReason,
  ]),
  ...radarAxes.map((axis) => axis.description),
  ...formations.map((formation) => formation.description),
  ...formationLessons.flatMap((lesson) => [
    lesson.objective,
    lesson.caution,
    lesson.scene.title,
    ...lesson.scene.steps.flatMap((step) => [
      step.title,
      step.explanation,
      step.observation,
      step.advantage,
    ]),
  ]),
].join("\n");

describe("soccerTerms", () => {
  it("新しい教材の役割名を平易な説明で調べられる", () => {
    for (const name of ["アンカー", "ボランチ", "トップ下"]) {
      expect(soccerTerms.find((term) => term.term === name)?.description).toContain("選手");
    }
  });
  it("idが一意である", () => {
    const ids = soccerTerms.map((term) => term.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("全件がterm/reading/description/categoryを空でない文字列として持つ", () => {
    expect(soccerTerms.length).toBeGreaterThan(0);
    for (const term of soccerTerms) {
      expect(term.term.length).toBeGreaterThan(0);
      expect(term.reading.length).toBeGreaterThan(0);
      expect(term.description.length).toBeGreaterThan(0);
      expect(term.category.length).toBeGreaterThan(0);
    }
  });

  it("全件のtermが、matchups/radarAxes/formationsの実文言のいずれかに登場する", () => {
    for (const { term } of soccerTerms) {
      expect(sourceText).toContain(term);
    }
  });

  it("各用語の説明文に、他の登録用語が登場しない（NFR-02: 説明は他のサッカー用語を使わずに書く）", () => {
    for (const { id, description } of soccerTerms) {
      const otherTermsFoundInDescription = soccerTerms
        .filter((other) => other.id !== id)
        .map((other) => other.term)
        .filter((otherTerm) => description.includes(otherTerm));
      expect(otherTermsFoundInDescription).toEqual([]);
    }
  });
});
