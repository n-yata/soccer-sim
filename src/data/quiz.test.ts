import { describe, expect, it } from "vitest";
import { buildQuiz, DEFAULT_QUIZ_LENGTH, defaultShuffle } from "@/data/quiz";
import { formations } from "@/data/formations";
import { matchups } from "@/data/matchups";
import type { Formation, Matchup, QuizQuestion, Shuffle } from "@/types/formation";

// 決定的な並べ替え（恒等関数）。本番コードに分岐を持たせずにテストを決定的にするため、
// buildQuiz は shuffle を差し替えられるようにしてある
const identity: Shuffle = (items) => [...items];
// 順序が実際に shuffle 経由で決まっていることを見るための、逆順に並べ替える実装
const reverse: Shuffle = (items) => [...items].reverse();

function makeFormation(id: string, name: string): Formation {
  return {
    id,
    name,
    description: `${name}の説明`,
    positions: [],
    stats: { attack: 50, defense: 50, balance: 50, spaceControl: 50, pressIntensity: 50 },
  };
}

function makeMatchup(overrides: Partial<Matchup> = {}): Matchup {
  return {
    id: "x_vs_y",
    formationAId: "x",
    formationBId: "y",
    advantagesForA: ["Xの優位1"],
    advantagesForB: ["Yの優位1"],
    overallEdge: "A",
    overallReason: "Xのほうが上回りやすい",
    ...overrides,
  };
}

function countCorrect(question: QuizQuestion): number {
  return question.choices.filter((c) => c.correct).length;
}

describe("buildQuiz", () => {
  it("実データから設問を生成する", () => {
    const questions = buildQuiz(formations, matchups, { shuffle: identity });

    expect(questions.length).toBeGreaterThan(0);
  });

  it("3種別（優劣判定・陣形識別・優位ポイント帰属）すべてを生成する", () => {
    // limit を外して生成可能な全設問を見る
    const questions = buildQuiz(formations, matchups, {
      shuffle: identity,
      limit: Number.MAX_SAFE_INTEGER,
    });

    const kinds = new Set(questions.map((q) => q.kind));
    expect(kinds).toEqual(new Set(["edge", "formation", "advantage"]));
  });

  it("どの設問も正解がちょうど1つだけである", () => {
    const questions = buildQuiz(formations, matchups, {
      shuffle: identity,
      limit: Number.MAX_SAFE_INTEGER,
    });

    for (const question of questions) {
      expect(countCorrect(question), `設問 ${question.id} の正解数`).toBe(1);
    }
  });

  it("どの設問も選択肢が2つ以上あり、説明文を持つ", () => {
    const questions = buildQuiz(formations, matchups, {
      shuffle: identity,
      limit: Number.MAX_SAFE_INTEGER,
    });

    for (const question of questions) {
      expect(question.choices.length, `設問 ${question.id} の選択肢数`).toBeGreaterThanOrEqual(2);
      expect(question.explanation, `設問 ${question.id} の解説`).not.toBe("");
    }
  });

  it("設問IDが重複しない（描画時のkey衝突を防ぐ）", () => {
    const questions = buildQuiz(formations, matchups, {
      shuffle: identity,
      limit: Number.MAX_SAFE_INTEGER,
    });

    const ids = questions.map((q) => q.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("既定では DEFAULT_QUIZ_LENGTH 問までに絞る", () => {
    const questions = buildQuiz(formations, matchups, { shuffle: identity });

    expect(questions).toHaveLength(DEFAULT_QUIZ_LENGTH);
  });

  it("生成できる設問が limit より少ないときは、作れた分だけを返す", () => {
    const fs = [makeFormation("x", "X"), makeFormation("y", "Y")];
    const questions = buildQuiz(fs, [makeMatchup()], { shuffle: identity, limit: 100 });

    // edge 1 + formation 2 + advantage 2 = 5
    expect(questions).toHaveLength(5);
  });

  it("shuffle を差し替えると出題順が変わる（順序が shuffle 経由で決まっている）", () => {
    const asIs = buildQuiz(formations, matchups, {
      shuffle: identity,
      limit: Number.MAX_SAFE_INTEGER,
    });
    const reversed = buildQuiz(formations, matchups, {
      shuffle: reverse,
      limit: Number.MAX_SAFE_INTEGER,
    });

    expect(reversed.map((q) => q.id)).not.toEqual(asIs.map((q) => q.id));
    // 中身の集合は同じ（並べ替えであって取捨選択ではない）
    expect(new Set(reversed.map((q) => q.id))).toEqual(new Set(asIs.map((q) => q.id)));
  });

  it("同じ shuffle を渡せば出題内容が再現する", () => {
    const first = buildQuiz(formations, matchups, { shuffle: identity });
    const second = buildQuiz(formations, matchups, { shuffle: identity });

    expect(first.map((q) => q.id)).toEqual(second.map((q) => q.id));
  });

  describe("優劣判定の設問", () => {
    it("overallEdge が示す側だけを正解にする", () => {
      const fs = [makeFormation("x", "X"), makeFormation("y", "Y")];
      const questions = buildQuiz(fs, [makeMatchup({ overallEdge: "B" })], {
        shuffle: identity,
        limit: Number.MAX_SAFE_INTEGER,
      });

      const edge = questions.find((q) => q.kind === "edge");
      const correct = edge!.choices.find((c) => c.correct);
      expect(correct!.label).toBe("Yがやや優位");
    });

    it("互角の組み合わせでは「互角」が正解になる", () => {
      const fs = [makeFormation("x", "X"), makeFormation("y", "Y")];
      const questions = buildQuiz(fs, [makeMatchup({ overallEdge: "even" })], {
        shuffle: identity,
        limit: Number.MAX_SAFE_INTEGER,
      });

      const edge = questions.find((q) => q.kind === "edge");
      expect(edge!.choices.find((c) => c.correct)!.label).toBe("互角");
    });

    it("解説に overallReason を使う", () => {
      const fs = [makeFormation("x", "X"), makeFormation("y", "Y")];
      const questions = buildQuiz(fs, [makeMatchup({ overallReason: "理由テキスト" })], {
        shuffle: identity,
        limit: Number.MAX_SAFE_INTEGER,
      });

      expect(questions.find((q) => q.kind === "edge")!.explanation).toBe("理由テキスト");
    });
  });

  describe("陣形識別の設問", () => {
    it("正解のフォーメーションを設問に添える（ミニピッチ図の描画に使う）", () => {
      const questions = buildQuiz(formations, matchups, {
        shuffle: identity,
        limit: Number.MAX_SAFE_INTEGER,
      });

      const question = questions.find((q) => q.kind === "formation");
      const correct = question!.choices.find((c) => c.correct);
      expect(question!.formation).toBeDefined();
      expect(question!.formation!.id).toBe(correct!.id);
    });

    it("フォーメーションが4件以上あれば選択肢を4つ出す", () => {
      expect(formations.length).toBeGreaterThanOrEqual(4);
      const questions = buildQuiz(formations, matchups, {
        shuffle: identity,
        limit: Number.MAX_SAFE_INTEGER,
      });

      const question = questions.find((q) => q.kind === "formation");
      expect(question!.choices).toHaveLength(4);
    });

    it("フォーメーションが4件未満なら、用意できる分だけの選択肢で出題する", () => {
      const fs = [makeFormation("x", "X"), makeFormation("y", "Y"), makeFormation("z", "Z")];
      const questions = buildQuiz(fs, [], { shuffle: identity, limit: Number.MAX_SAFE_INTEGER });

      const formationQuestions = questions.filter((q) => q.kind === "formation");
      expect(formationQuestions).toHaveLength(3);
      for (const question of formationQuestions) {
        expect(question.choices).toHaveLength(3);
        expect(countCorrect(question)).toBe(1);
      }
    });

    it("フォーメーションが1件だけなら、誤答を作れないので出題しない", () => {
      const questions = buildQuiz([makeFormation("x", "X")], [], {
        shuffle: identity,
        limit: Number.MAX_SAFE_INTEGER,
      });

      expect(questions.filter((q) => q.kind === "formation")).toHaveLength(0);
    });
  });

  describe("優位ポイント帰属の設問", () => {
    it("優位ポイントの由来した側を正解にする", () => {
      const fs = [makeFormation("x", "X"), makeFormation("y", "Y")];
      const questions = buildQuiz(
        fs,
        [makeMatchup({ advantagesForA: ["Xだけの強み"], advantagesForB: ["Yだけの強み"] })],
        { shuffle: identity, limit: Number.MAX_SAFE_INTEGER },
      );

      const forA = questions.find((q) => q.kind === "advantage" && q.prompt.includes("Xだけの強み"));
      const forB = questions.find((q) => q.kind === "advantage" && q.prompt.includes("Yだけの強み"));

      expect(forA!.choices.find((c) => c.correct)!.id).toBe("x");
      expect(forB!.choices.find((c) => c.correct)!.id).toBe("y");
    });

    it("優位ポイントの数だけ設問を作る", () => {
      const fs = [makeFormation("x", "X"), makeFormation("y", "Y")];
      const questions = buildQuiz(
        fs,
        [makeMatchup({ advantagesForA: ["A1", "A2"], advantagesForB: ["B1"] })],
        { shuffle: identity, limit: Number.MAX_SAFE_INTEGER },
      );

      expect(questions.filter((q) => q.kind === "advantage")).toHaveLength(3);
    });
  });

  describe("データが不足・不整合な場合", () => {
    it("フォーメーションもマッチアップも無ければ空配列を返す（例外を投げない）", () => {
      expect(buildQuiz([], [], { shuffle: identity })).toEqual([]);
    });

    it("マッチアップが無ければ優劣判定・優位ポイントの設問は作られない", () => {
      const questions = buildQuiz(formations, [], {
        shuffle: identity,
        limit: Number.MAX_SAFE_INTEGER,
      });

      expect(questions.some((q) => q.kind === "edge")).toBe(false);
      expect(questions.some((q) => q.kind === "advantage")).toBe(false);
      expect(questions.some((q) => q.kind === "formation")).toBe(true);
    });

    // 参照先が消えたマッチアップから "undefined vs X" のような壊れた設問を作らない
    it("参照先のフォーメーションが存在しないマッチアップは設問にしない", () => {
      const fs = [makeFormation("x", "X")];
      const questions = buildQuiz(fs, [makeMatchup({ formationAId: "x", formationBId: "missing" })], {
        shuffle: identity,
        limit: Number.MAX_SAFE_INTEGER,
      });

      expect(questions.some((q) => q.kind === "edge")).toBe(false);
      expect(questions.some((q) => q.kind === "advantage")).toBe(false);
      expect(questions.every((q) => !q.prompt.includes("undefined"))).toBe(true);
    });

    it("limit が 0 以下なら出題しない", () => {
      expect(buildQuiz(formations, matchups, { shuffle: identity, limit: 0 })).toEqual([]);
      expect(buildQuiz(formations, matchups, { shuffle: identity, limit: -5 })).toEqual([]);
    });
  });
});

describe("defaultShuffle", () => {
  it("要素を落とさず・増やさずに並べ替える", () => {
    const input = [1, 2, 3, 4, 5, 6, 7, 8];
    const result = defaultShuffle(input);

    expect(result).toHaveLength(input.length);
    expect([...result].sort((a, b) => a - b)).toEqual(input);
  });

  it("元の配列を破壊しない", () => {
    const input = [1, 2, 3];
    defaultShuffle(input);

    expect(input).toEqual([1, 2, 3]);
  });

  it("空配列でも壊れない", () => {
    expect(defaultShuffle([])).toEqual([]);
  });
});
