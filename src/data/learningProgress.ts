import type { Formation, LearningProgress } from "@/types/formation";

const STORAGE_KEY = "formation-lab.learning-progress.v1";

const EMPTY: LearningProgress = { viewedPairs: [] };

/**
 * フォーメーション2件の組み合わせを表す、順序に依存しないキーを作る。
 *
 * "A vs B" と "B vs A" が別レコードになると進捗が二重に数えられ、
 * 「確認済み / 全組み合わせ」の分子だけが膨らんで 1周したかの判定が静かに誤る。
 */
export function buildPairKey(idA: string, idB: string): string {
  return [idA, idB].sort().join("__");
}

/** 全フォーメーションから作れる、異なる2件の組み合わせ数（進捗の分母） */
export function countAllPairs(formations: readonly Formation[]): number {
  const n = formations.length;
  if (n < 2) return 0;
  return (n * (n - 1)) / 2;
}

/**
 * localStorage から読んだ値が期待する形かを検証する。
 *
 * localStorage の中身は利用者が自由に書き換えられる。信用して描画すると
 * 壊れたデータで静かに誤る（進捗が NaN になる、undefined を含む配列で落ちる等）ため、
 * 1つでも期待から外れたら空の進捗として扱う。
 */
function parseProgress(raw: string | null): LearningProgress {
  if (raw === null) return EMPTY;

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return EMPTY;
  }

  if (typeof parsed !== "object" || parsed === null) return EMPTY;

  const candidate = (parsed as { viewedPairs?: unknown }).viewedPairs;
  if (!Array.isArray(candidate)) return EMPTY;
  if (!candidate.every((item) => typeof item === "string")) return EMPTY;

  // 重複は取り除く。手で書き換えられた場合や、将来の書き込み経路の不具合で
  // 同じキーが二重に入ると、分子が分母を超える
  return { viewedPairs: [...new Set(candidate as string[])] };
}

/**
 * 保存済みの学習進捗を読む。
 * localStorage が使えない環境（プライベートモード・無効化）ではアクセス自体が
 * 例外を投げることがあるため、握って空の進捗を返す（記録できないだけで画面は壊さない）。
 */
export function loadProgress(): LearningProgress {
  try {
    return parseProgress(window.localStorage.getItem(STORAGE_KEY));
  } catch {
    return EMPTY;
  }
}

/**
 * 進捗を保存する。容量超過などで失敗しても例外を外に出さない。
 * 戻り値は「保存できたか」。呼び出し側は保存の成否にかかわらず処理を続けてよい。
 */
function saveProgress(progress: LearningProgress): boolean {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(progress));
    return true;
  } catch {
    return false;
  }
}

/**
 * 組み合わせを「確認済み」として記録し、記録後の進捗を返す。
 * 保存に失敗した場合も、その場の画面表示が食い違わないよう更新後の値を返す。
 */
export function markPairViewed(idA: string, idB: string): LearningProgress {
  const key = buildPairKey(idA, idB);
  const current = loadProgress();
  if (current.viewedPairs.includes(key)) return current;

  const next: LearningProgress = { viewedPairs: [...current.viewedPairs, key] };
  saveProgress(next);
  return next;
}

/** 指定の組み合わせが確認済みか */
export function isPairViewed(progress: LearningProgress, idA: string, idB: string): boolean {
  return progress.viewedPairs.includes(buildPairKey(idA, idB));
}

/** 進捗を消去し、空の進捗を返す */
export function clearProgress(): LearningProgress {
  try {
    window.localStorage.removeItem(STORAGE_KEY);
  } catch {
    // 消せなくても、画面上は空として扱う
  }
  return { viewedPairs: [] };
}
