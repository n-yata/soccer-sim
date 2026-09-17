import type { Formation, Matchup, QuizChoice, QuizQuestion, Shuffle } from "@/types/formation";

/**
 * 1回の挑戦で出す設問数の既定値。
 *
 * これはデータから導かれる値ではなく「1回が長すぎると最後まで解かれない」という
 * UX上の判断なので、定数として明示する。生成できる設問がこれより少ない場合は
 * 生成できた分だけを出す（設問数そのものをコードに固定しているわけではない。NFR-03）。
 */
export const DEFAULT_QUIZ_LENGTH = 10;

// 1問につき提示する選択肢の上限（陣形識別の設問で使う）。正解1 + 誤答3。
const FORMATION_CHOICE_COUNT = 4;

/**
 * 既定の並べ替え。Fisher-Yates。
 * buildQuiz は shuffle を差し替えられるようにしてあり、テストは決定的な関数を渡す
 * （本番コードにテスト用の分岐を入れないため）。
 */
export const defaultShuffle: Shuffle = <T,>(items: readonly T[]): T[] => {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
};

function findName(formations: readonly Formation[], id: string): string | undefined {
  return formations.find((f) => f.id === id)?.name;
}

/** 優劣判定の設問: 2つのフォーメーションのどちらが優位かを3択で問う */
function buildEdgeQuestions(
  formations: readonly Formation[],
  matchups: readonly Matchup[],
  shuffle: Shuffle,
): QuizQuestion[] {
  const questions: QuizQuestion[] = [];

  for (const matchup of matchups) {
    const nameA = findName(formations, matchup.formationAId);
    const nameB = findName(formations, matchup.formationBId);
    // 参照先のフォーメーションが無いマッチアップからは設問を作れない。
    // 設問文が "undefined vs 4-4-2" のような壊れた表示になるより、出さないほうがよい
    if (!nameA || !nameB) continue;

    const choices: QuizChoice[] = [
      { id: "A", label: `${nameA}がやや優位`, correct: matchup.overallEdge === "A" },
      { id: "B", label: `${nameB}がやや優位`, correct: matchup.overallEdge === "B" },
      { id: "even", label: "互角", correct: matchup.overallEdge === "even" },
    ];

    questions.push({
      id: `edge-${matchup.id}`,
      kind: "edge",
      prompt: `${nameA} と ${nameB} が対戦したとき、総合的に優位なのはどちらでしょう？`,
      choices: shuffle(choices),
      explanation: matchup.overallReason,
    });
  }

  return questions;
}

/** 陣形識別の設問: ミニピッチ図だけを見てフォーメーション名を当てる */
function buildFormationQuestions(
  formations: readonly Formation[],
  shuffle: Shuffle,
): QuizQuestion[] {
  const questions: QuizQuestion[] = [];

  for (const formation of formations) {
    const others = formations.filter((f) => f.id !== formation.id);
    // 誤答が1つも作れない（フォーメーションが1件しかない）場合は設問として成立しない。
    // 3件に満たない場合は、用意できる分だけの選択肢で出す
    if (others.length === 0) continue;

    const distractors = shuffle(others).slice(0, FORMATION_CHOICE_COUNT - 1);
    const choices: QuizChoice[] = [
      { id: formation.id, label: formation.name, correct: true },
      ...distractors.map((f) => ({ id: f.id, label: f.name, correct: false })),
    ];

    questions.push({
      id: `formation-${formation.id}`,
      kind: "formation",
      prompt: "この選手配置は、どのフォーメーションでしょう？",
      choices: shuffle(choices),
      explanation: formation.description,
      formation,
    });
  }

  return questions;
}

/** 優位ポイント帰属の設問: 優位ポイントの一文が、どちらのフォーメーションのものかを問う */
function buildAdvantageQuestions(
  formations: readonly Formation[],
  matchups: readonly Matchup[],
  shuffle: Shuffle,
): QuizQuestion[] {
  const questions: QuizQuestion[] = [];

  for (const matchup of matchups) {
    const nameA = findName(formations, matchup.formationAId);
    const nameB = findName(formations, matchup.formationBId);
    if (!nameA || !nameB) continue;

    const sides = [
      { points: matchup.advantagesForA, ownerId: matchup.formationAId, slug: "a" },
      { points: matchup.advantagesForB, ownerId: matchup.formationBId, slug: "b" },
    ];

    for (const side of sides) {
      side.points.forEach((point, index) => {
        const choices: QuizChoice[] = [
          {
            id: matchup.formationAId,
            label: nameA,
            correct: side.ownerId === matchup.formationAId,
          },
          {
            id: matchup.formationBId,
            label: nameB,
            correct: side.ownerId === matchup.formationBId,
          },
        ];

        questions.push({
          id: `advantage-${matchup.id}-${side.slug}-${index}`,
          kind: "advantage",
          prompt: `「${point}」これは ${nameA} と ${nameB} のどちらの優位ポイントでしょう？`,
          choices: shuffle(choices),
          explanation: matchup.overallReason,
        });
      });
    }
  }

  return questions;
}

/**
 * 静的データからクイズの設問を生成する（FR-12）。
 *
 * 設問は formations / matchups を走査して作るため、データを追加すれば設問も
 * 自動的に増える（NFR-03）。出題できる設問が1件も作れない場合は空配列を返し、
 * 画面側がその旨を表示する（例外を投げない）。
 */
export function buildQuiz(
  formations: readonly Formation[],
  matchups: readonly Matchup[],
  options: { shuffle?: Shuffle; limit?: number } = {},
): QuizQuestion[] {
  const shuffle = options.shuffle ?? defaultShuffle;
  const limit = options.limit ?? DEFAULT_QUIZ_LENGTH;

  const all = [
    ...buildEdgeQuestions(formations, matchups, shuffle),
    ...buildFormationQuestions(formations, shuffle),
    ...buildAdvantageQuestions(formations, matchups, shuffle),
  ];

  // limit が 0 以下なら出題しない（負数で slice の末尾指定に化けるのを防ぐ）
  if (limit <= 0) return [];

  return shuffle(all).slice(0, limit);
}
