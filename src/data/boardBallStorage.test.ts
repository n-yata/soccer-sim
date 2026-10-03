import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { loadBoardBallPosition, saveBoardBallPosition } from "./boardBallStorage";

const STORAGE_KEY = "formation-lab.board-ball.v1";

describe("ボードのボール保存", () => {
  beforeEach(() => localStorage.clear());
  afterEach(() => vi.restoreAllMocks());

  it("未保存時は中央を返し、保存した位置を復元する", () => {
    expect(loadBoardBallPosition()).toEqual({ x: 50, y: 50 });
    saveBoardBallPosition({ x: 24, y: 80 });
    expect(loadBoardBallPosition()).toEqual({ x: 24, y: 80 });
  });

  it.each(["broken", "null", "[]", '{"x":"20","y":30}', '{"x":20}', '{"x":1e309,"y":10}'])(
    "不正な保存値 %s は中央に戻す",
    (raw) => {
      localStorage.setItem(STORAGE_KEY, raw);
      expect(loadBoardBallPosition()).toEqual({ x: 50, y: 50 });
    },
  );

  it("範囲外座標はピッチ範囲に収め、非有限値は保存しない", () => {
    saveBoardBallPosition({ x: -10, y: 120 });
    expect(loadBoardBallPosition()).toEqual({ x: 0, y: 100 });
    saveBoardBallPosition({ x: NaN, y: Infinity });
    expect(loadBoardBallPosition()).toEqual({ x: 0, y: 100 });
    localStorage.setItem(STORAGE_KEY, '{"x":120,"y":-20}');
    expect(loadBoardBallPosition()).toEqual({ x: 100, y: 0 });
  });

  it("読み書き不可でも例外を外へ出さない", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("blocked");
    });
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("quota");
    });
    expect(loadBoardBallPosition()).toEqual({ x: 50, y: 50 });
    expect(() => saveBoardBallPosition({ x: 20, y: 30 })).not.toThrow();
  });
});
