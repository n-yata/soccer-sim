import { beforeEach, describe, expect, it, vi, afterEach } from "vitest";
import {
  applyOverrides,
  savePositionOverride,
  clearFormationOverride,
} from "@/data/freeLayoutStorage";
import type { Position } from "@/types/formation";

const STORAGE_KEY = "formation-lab.free-layout-overrides.v1";

function makePositions(): Position[] {
  return [
    { id: "gk", type: "GK", label: "GK", x: 50, y: 5 },
    { id: "df1", type: "DF", label: "DF", x: 20, y: 25 },
  ];
}

describe("applyOverrides / savePositionOverride / clearFormationOverride", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("何も保存されていなければcanonicalなpositionsをそのまま返す", () => {
    const positions = makePositions();
    expect(applyOverrides(positions, "4-4-2")).toEqual(positions);
  });

  it("保存済みのpositionIdはx/yが上書きされ、保存の無いpositionIdはcanonicalな値のまま残る", () => {
    const positions = makePositions();
    savePositionOverride("4-4-2", "gk", 60, 10);

    const result = applyOverrides(positions, "4-4-2");
    expect(result.find((p) => p.id === "gk")).toEqual({ id: "gk", type: "GK", label: "GK", x: 60, y: 10 });
    expect(result.find((p) => p.id === "df1")).toEqual(positions[1]);
  });

  it("保存→適用の往復で値が一致する（決定性）", () => {
    savePositionOverride("4-4-2", "gk", 33, 77);
    const first = applyOverrides(makePositions(), "4-4-2");
    const second = applyOverrides(makePositions(), "4-4-2");
    expect(first).toEqual(second);
  });

  it("座標は0-100にクランプされて保存される", () => {
    savePositionOverride("4-4-2", "gk", -50, 999);
    const result = applyOverrides(makePositions(), "4-4-2");
    const gk = result.find((p) => p.id === "gk")!;
    expect(gk.x).toBe(0);
    expect(gk.y).toBe(100);
  });

  it("別のフォーメーションIDへの保存は、他フォーメーションのデータに影響しない", () => {
    savePositionOverride("4-4-2", "gk", 60, 10);
    savePositionOverride("4-3-3", "gk", 40, 90);

    const resultA = applyOverrides(makePositions(), "4-4-2");
    const resultB = applyOverrides(makePositions(), "4-3-3");
    expect(resultA.find((p) => p.id === "gk")).toMatchObject({ x: 60, y: 10 });
    expect(resultB.find((p) => p.id === "gk")).toMatchObject({ x: 40, y: 90 });
  });

  it("同一フォーメーション内の複数ポジションへの保存が両方反映される", () => {
    savePositionOverride("4-4-2", "gk", 60, 10);
    savePositionOverride("4-4-2", "df1", 15, 35);

    const result = applyOverrides(makePositions(), "4-4-2");
    expect(result.find((p) => p.id === "gk")).toMatchObject({ x: 60, y: 10 });
    expect(result.find((p) => p.id === "df1")).toMatchObject({ x: 15, y: 35 });
  });

  it("clearFormationOverride後は該当フォーメーションの上書きが消え、canonicalな値が返る", () => {
    const positions = makePositions();
    savePositionOverride("4-4-2", "gk", 60, 10);
    clearFormationOverride("4-4-2");

    expect(applyOverrides(positions, "4-4-2")).toEqual(positions);
  });

  it("clearFormationOverrideは他フォーメーションのデータを消さない", () => {
    savePositionOverride("4-4-2", "gk", 60, 10);
    savePositionOverride("4-3-3", "gk", 40, 90);
    clearFormationOverride("4-4-2");

    const resultB = applyOverrides(makePositions(), "4-3-3");
    expect(resultB.find((p) => p.id === "gk")).toMatchObject({ x: 40, y: 90 });
  });

  it("保存が無いフォーメーションIDに対するclearFormationOverrideは何もしない（例外を投げない）", () => {
    expect(() => clearFormationOverride("存在しないID")).not.toThrow();
  });
});

// localStorage の中身は利用者が書き換えられる。信用して適用しないことを確認する
describe("保存データが壊れている場合", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.restoreAllMocks();
  });

  it("JSONとして解釈できない値なら保存無しとして扱う", () => {
    window.localStorage.setItem(STORAGE_KEY, "{壊れた");
    const positions = makePositions();
    expect(applyOverrides(positions, "4-4-2")).toEqual(positions);
  });

  it("オブジェクトでない値（配列・数値・null）なら保存無しとして扱う", () => {
    const positions = makePositions();
    for (const raw of ["[1,2,3]", "42", "null", '"text"']) {
      window.localStorage.setItem(STORAGE_KEY, raw);
      expect(applyOverrides(positions, "4-4-2"), `raw=${raw}`).toEqual(positions);
    }
  });

  it("x/yが数値でない・NaN・Infinityなら、そのポジションだけcanonicalな値のまま残る", () => {
    window.localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        "4-4-2": {
          gk: { x: "60", y: 10 },
          df1: { x: NaN, y: 20 },
        },
      }),
    );
    const positions = makePositions();
    const result = applyOverrides(positions, "4-4-2");
    expect(result.find((p) => p.id === "gk")).toEqual(positions[0]);
    expect(result.find((p) => p.id === "df1")).toEqual(positions[1]);
  });

  it("一部のフォーメーションエントリが壊れていても、他の正しいエントリは活かされる", () => {
    window.localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        "4-4-2": "壊れている",
        "4-3-3": { gk: { x: 40, y: 90 } },
      }),
    );
    const positions = makePositions();
    expect(applyOverrides(positions, "4-4-2")).toEqual(positions);
    expect(applyOverrides(positions, "4-3-3").find((p) => p.id === "gk")).toMatchObject({
      x: 40,
      y: 90,
    });
  });

  it("__proto__/constructor/prototypeキーが混入していても、他の無関係なフォーメーション・ポジションの座標を汚染しない", () => {
    // オブジェクトリテラルの `__proto__:` はプロトタイプ設定として特別扱いされ、
    // 通常のenumerableな own property にならない（JSON.stringifyでキーとして出力されない）。
    // 攻撃/汚染データを模すには、JSON.parseが実際に生成する形と同じ「文字列」を直接与える必要がある
    const raw =
      '{"__proto__":{"gk":{"x":99,"y":99}},' +
      '"4-4-2":{"gk":{"x":10,"y":20},"__proto__":{"x":88,"y":88},"constructor":{"x":77,"y":77}}}';
    window.localStorage.setItem(STORAGE_KEY, raw);
    const positions = makePositions();
    // 汚染されていれば、無関係な "4-3-3" や未保存のformationIdでもgk等の座標が
    // 拾えてしまう（Object.prototype経由の継承）。汚染されていなければ、
    // 保存していないformationIdは常にcanonicalな値のまま返る
    expect(applyOverrides(positions, "存在しないID")).toEqual(positions);
    expect(applyOverrides(positions, "4-4-2").find((p) => p.id === "gk")).toMatchObject({
      x: 10,
      y: 20,
    });
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

  it("読み込みが例外を投げても、canonicalなpositionsを返して落ちない", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("SecurityError");
    });
    const positions = makePositions();
    expect(() => applyOverrides(positions, "4-4-2")).not.toThrow();
    expect(applyOverrides(positions, "4-4-2")).toEqual(positions);
  });

  it("書き込みが例外を投げても、呼び出し側へ例外を伝播させない", () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });
    expect(() => savePositionOverride("4-4-2", "gk", 60, 10)).not.toThrow();
  });

  it("消去が例外を投げても、呼び出し側へ例外を伝播させない", () => {
    // clearFormationOverrideは対象キーが無ければ早期returnしsetItemに到達しないため、
    // 先に保存しておき、例外を投げる経路（setItem呼び出し）を実際に通す
    savePositionOverride("4-4-2", "gk", 60, 10);
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });
    expect(() => clearFormationOverride("4-4-2")).not.toThrow();
  });
});
