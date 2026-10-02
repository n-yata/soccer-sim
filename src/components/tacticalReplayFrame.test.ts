import { describe, expect, it } from "vitest";
import { interpolateFrame } from "./tacticalReplayFrame";
import { wideOverloadScene } from "@/data/tacticalScenes";

describe("interpolateFrame", () => {
  const from = { players: [{ id: "runner", x: 20, y: 80 }], ball: { x: 30, y: 70 } };
  const to = { players: [{ id: "runner", x: 80, y: 60 }], ball: { x: 90, y: 50 } };

  it("選手とボールを独立して中間座標へ動かす", () => {
    expect(interpolateFrame(from, to, 0.5)).toEqual({
      players: [{ id: "runner", x: 50, y: 70 }],
      ball: { x: 60, y: 60 },
    });
    expect(from.players[0]?.x).toBe(20);
  });

  it.each([
    [-1, 20],
    [0, 20],
    [1, 80],
    [2, 80],
    [NaN, 20],
  ])("補間率%sで範囲外・非数を安全な端点へ制限する", (progress, x) => {
    expect(interpolateFrame(from, to, progress).players[0]?.x).toBe(x);
  });

  it("行の順序に依存せず選手IDを追跡する", () => {
    const start = {
      ...from,
      players: [
        { id: "a", x: 10, y: 20 },
        { id: "b", x: 80, y: 40 },
      ],
    };
    const end = {
      ...to,
      players: [
        { id: "b", x: 60, y: 60 },
        { id: "a", x: 30, y: 40 },
      ],
    };
    expect(interpolateFrame(start, end, 0.5).players).toEqual([
      { id: "a", x: 20, y: 30 },
      { id: "b", x: 70, y: 50 },
    ]);
  });

  it("教材の全停止状態が同じ選手を含み、ピッチ内の位置と解説を持つ", () => {
    expect(wideOverloadScene.steps).toHaveLength(5);
    for (const step of wideOverloadScene.steps) {
      expect(step.frame.players.map((p) => p.id).sort()).toEqual(
        wideOverloadScene.players.map((p) => p.id).sort(),
      );
      expect(step.explanation.length).toBeGreaterThan(20);
      for (const point of [...step.frame.players, step.frame.ball]) {
        expect(point.x).toBeGreaterThanOrEqual(0);
        expect(point.x).toBeLessThanOrEqual(300);
        expect(point.y).toBeGreaterThanOrEqual(0);
        expect(point.y).toBeLessThanOrEqual(200);
      }
    }
  });
});
