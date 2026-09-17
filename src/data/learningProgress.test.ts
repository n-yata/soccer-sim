import { beforeEach, describe, expect, it, vi, afterEach } from "vitest";
import {
  buildPairKey,
  clearProgress,
  countAllPairs,
  isPairViewed,
  loadProgress,
  markPairViewed,
} from "@/data/learningProgress";
import { formations } from "@/data/formations";
import type { Formation } from "@/types/formation";

const STORAGE_KEY = "formation-lab.learning-progress.v1";

function makeFormation(id: string): Formation {
  return {
    id,
    name: id,
    description: "",
    positions: [],
    stats: { attack: 0, defense: 0, balance: 0, spaceControl: 0, pressIntensity: 0 },
  };
}

describe("buildPairKey", () => {
  it("順序を入れ替えても同じキーになる", () => {
    expect(buildPairKey("4-4-2", "4-3-3")).toBe(buildPairKey("4-3-3", "4-4-2"));
  });

  it("異なる組み合わせは異なるキーになる", () => {
    expect(buildPairKey("4-4-2", "4-3-3")).not.toBe(buildPairKey("4-4-2", "3-5-2"));
  });
});

describe("countAllPairs", () => {
  it("4件なら6組（nC2）", () => {
    expect(countAllPairs([1, 2, 3, 4].map((n) => makeFormation(String(n))))).toBe(6);
  });

  it("5件なら10組", () => {
    expect(countAllPairs([1, 2, 3, 4, 5].map((n) => makeFormation(String(n))))).toBe(10);
  });

  it("1件以下なら0組（組み合わせが作れない）", () => {
    expect(countAllPairs([makeFormation("a")])).toBe(0);
    expect(countAllPairs([])).toBe(0);
  });

  it("実データのフォーメーション数と整合する", () => {
    const n = formations.length;
    expect(countAllPairs(formations)).toBe((n * (n - 1)) / 2);
  });
});

describe("進捗の保存と読み込み", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("何も保存されていなければ空の進捗を返す", () => {
    expect(loadProgress()).toEqual({ viewedPairs: [] });
  });

  it("記録した組み合わせが読み込みで復元される", () => {
    markPairViewed("4-4-2", "4-3-3");

    expect(loadProgress().viewedPairs).toEqual([buildPairKey("4-4-2", "4-3-3")]);
  });

  it("順序違いで同じ組み合わせを記録しても二重に数えない", () => {
    markPairViewed("4-4-2", "4-3-3");
    markPairViewed("4-3-3", "4-4-2");

    expect(loadProgress().viewedPairs).toHaveLength(1);
  });

  it("同じ組み合わせを繰り返し記録しても増えない", () => {
    markPairViewed("4-4-2", "4-3-3");
    markPairViewed("4-4-2", "4-3-3");
    markPairViewed("4-4-2", "4-3-3");

    expect(loadProgress().viewedPairs).toHaveLength(1);
  });

  it("異なる組み合わせは別々に記録される", () => {
    markPairViewed("4-4-2", "4-3-3");
    markPairViewed("4-4-2", "3-5-2");

    expect(loadProgress().viewedPairs).toHaveLength(2);
  });

  it("markPairViewed は記録後の進捗を返す", () => {
    const progress = markPairViewed("4-4-2", "4-3-3");

    expect(progress.viewedPairs).toContain(buildPairKey("4-4-2", "4-3-3"));
  });

  it("isPairViewed が順序に依存せず判定する", () => {
    const progress = markPairViewed("4-4-2", "4-3-3");

    expect(isPairViewed(progress, "4-4-2", "4-3-3")).toBe(true);
    expect(isPairViewed(progress, "4-3-3", "4-4-2")).toBe(true);
    expect(isPairViewed(progress, "4-4-2", "3-5-2")).toBe(false);
  });

  it("clearProgress で記録が消え、空の進捗が返る", () => {
    markPairViewed("4-4-2", "4-3-3");

    expect(clearProgress()).toEqual({ viewedPairs: [] });
    expect(loadProgress()).toEqual({ viewedPairs: [] });
  });
});

// localStorage の中身は利用者が書き換えられる。信用して描画しないことを確認する
describe("保存データが壊れている場合", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.restoreAllMocks();
  });

  it("JSONとして解釈できない値なら空の進捗として扱う", () => {
    window.localStorage.setItem(STORAGE_KEY, "{壊れた");

    expect(loadProgress()).toEqual({ viewedPairs: [] });
  });

  it("オブジェクトでない値（配列・数値・null）なら空の進捗として扱う", () => {
    for (const raw of ["[1,2,3]", "42", "null", '"text"']) {
      window.localStorage.setItem(STORAGE_KEY, raw);
      expect(loadProgress(), `raw=${raw}`).toEqual({ viewedPairs: [] });
    }
  });

  it("viewedPairs が配列でなければ空の進捗として扱う", () => {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ viewedPairs: "4-4-2__4-3-3" }));

    expect(loadProgress()).toEqual({ viewedPairs: [] });
  });

  it("viewedPairs が無ければ空の進捗として扱う", () => {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ other: [] }));

    expect(loadProgress()).toEqual({ viewedPairs: [] });
  });

  it("viewedPairs に文字列以外が混ざっていれば空の進捗として扱う", () => {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ viewedPairs: ["a__b", 42, null] }));

    expect(loadProgress()).toEqual({ viewedPairs: [] });
  });

  // 分子が分母を超えて「6/4 組」のような表示になるのを防ぐ
  it("viewedPairs に重複があれば取り除く", () => {
    window.localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ viewedPairs: ["a__b", "a__b", "c__d"] }),
    );

    expect(loadProgress().viewedPairs).toEqual(["a__b", "c__d"]);
  });
});

// プライベートモード・ストレージ無効化ではアクセス自体が例外を投げる
describe("localStorage が使えない場合", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("読み込みが例外を投げても、空の進捗を返して落ちない", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("SecurityError");
    });

    expect(() => loadProgress()).not.toThrow();
    expect(loadProgress()).toEqual({ viewedPairs: [] });
  });

  it("書き込みが例外を投げても、呼び出し側へ例外を伝播させない", () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });

    expect(() => markPairViewed("4-4-2", "4-3-3")).not.toThrow();
  });

  it("書き込みが失敗しても、その場の表示用に更新後の進捗を返す", () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });

    const progress = markPairViewed("4-4-2", "4-3-3");

    expect(progress.viewedPairs).toContain(buildPairKey("4-4-2", "4-3-3"));
  });

  it("消去が例外を投げても、空の進捗を返して落ちない", () => {
    vi.spyOn(Storage.prototype, "removeItem").mockImplementation(() => {
      throw new Error("SecurityError");
    });

    expect(() => clearProgress()).not.toThrow();
    expect(clearProgress()).toEqual({ viewedPairs: [] });
  });
});
