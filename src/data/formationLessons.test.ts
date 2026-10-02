import { describe, expect, it } from "vitest";
import { formations } from "./formations";
import { formationLessons, getFormationLesson } from "./formationLessons";

describe("陣形別の場面教材", () => {
  it("全8陣形にそれぞれ異なる教材を用意する", () => {
    expect(formationLessons.map((lesson) => lesson.formationId).sort()).toEqual(
      formations.map((formation) => formation.id).sort(),
    );
    expect(new Set(formationLessons.map((lesson) => lesson.scene.title)).size).toBe(8);
    expect(
      new Set(
        formationLessons.map((lesson) =>
          JSON.stringify(lesson.scene.steps.map((step) => step.frame)),
        ),
      ).size,
    ).toBe(8);
  });

  it.each(formations)("$name の選手・座標・解説が一貫する", (formation) => {
    const lesson = getFormationLesson(formation.id)!;
    expect(lesson.scene.steps).toHaveLength(5);
    const ids = lesson.scene.players.map((player) => player.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const player of lesson.scene.players.filter((player) => player.team === "attack")) {
      expect(formation.positions.map((position) => position.id)).toContain(
        player.formationPositionId,
      );
    }
    for (const step of lesson.scene.steps) {
      expect(step.frame.players.map((player) => player.id).sort()).toEqual([...ids].sort());
      expect(step.explanation.length).toBeGreaterThan(20);
      expect(step.observation.length).toBeGreaterThan(10);
      for (const point of [
        ...step.frame.players,
        step.frame.ball,
        ...step.routes.flatMap((route) => [route.from, route.to]),
      ]) {
        expect(point.x).toBeGreaterThanOrEqual(10);
        expect(point.x).toBeLessThanOrEqual(290);
        expect(point.y).toBeGreaterThanOrEqual(10);
        expect(point.y).toBeLessThanOrEqual(190);
      }
      expect(
        step.frame.players.some(
          (player) => Math.hypot(player.x - step.frame.ball.x, player.y - step.frame.ball.y) <= 15,
        ),
      ).toBe(true);
    }
  });

  it("不明IDは教材を返さない", () => {
    expect(getFormationLesson("unknown")).toBeUndefined();
    expect(getFormationLesson("")).toBeUndefined();
  });

  it("2トップの教材は足元と背後を分け、パスが受け手に届く", () => {
    const steps = getFormationLesson("4-4-2")!.scene.steps;
    expect(steps[1]!.frame.players.find((player) => player.id === "blue-1")!.x).toBeLessThan(
      steps[0]!.frame.players.find((player) => player.id === "blue-1")!.x,
    );
    expect(steps[1]!.frame.players.find((player) => player.id === "blue-2")!.x).toBeGreaterThan(
      steps[0]!.frame.players.find((player) => player.id === "blue-2")!.x,
    );
    expect(steps[2]!.frame.ball).toEqual({ x: 264, y: 126 });
    expect(steps[2]!.routes.find((route) => route.kind === "pass")!.to).toEqual({ x: 264, y: 126 });
  });
});
