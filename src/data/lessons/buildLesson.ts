import type { FormationLesson, ReplayPlayer } from "@/types/tacticalReplay";

type Point = [number, number];
type Layout = [Point, Point, Point, Point, Point];
interface LessonStep {
  title: string;
  explanation: string;
  observation: string;
  advantage: string;
  layout: Layout;
  holder: 0 | 1 | 2;
}
interface LessonDefinition {
  formationId: string;
  title: string;
  objective: string;
  caution: string;
  areaLabel: string;
  roles: [string, string, string];
  positionIds: [string, string, string];
  steps: [LessonStep, LessonStep, LessonStep, LessonStep, LessonStep];
}

// 座標と文章は教材ごとに作成し、ここでは共通の描画データ形式へ変換する。
export function buildLesson(definition: LessonDefinition): FormationLesson {
  const players: ReplayPlayer[] = [
    ...definition.roles.map((label, index) => ({
      id: `blue-${index}`,
      label,
      number: [6, 9, 10][index]!,
      team: "attack" as const,
      formationPositionId: `${definition.formationId}-${definition.positionIds[index]}`,
    })),
    { id: "red-0", label: "ボール側の守備者", number: 3, team: "defence" },
    { id: "red-1", label: "カバー役", number: 4, team: "defence" },
  ];
  const frames = definition.steps.map((step) => ({
    players: step.layout.map(([x, y], index) => ({ id: players[index]!.id, x, y })),
    ball: { x: step.layout[step.holder][0] + 12, y: step.layout[step.holder][1] + 6 },
  }));
  return {
    formationId: definition.formationId,
    objective: definition.objective,
    caution: definition.caution,
    scene: {
      id: `${definition.formationId}-lesson`,
      title: definition.title,
      durationMs: 2800,
      context: `${definition.formationId}の役割を使った局面の教材です。青が学習する陣形、赤が相手。関係する5人を切り出し、他の選手は省略しています。`,
      areaLabel: definition.areaLabel,
      players,
      steps: definition.steps.map((step, index) => ({
        title: step.title,
        explanation: step.explanation,
        observation: step.observation,
        advantage: step.advantage,
        frame: frames[index]!,
        routes:
          index > 0 && step.holder !== definition.steps[index - 1]!.holder
            ? [{ from: frames[index - 1]!.ball, to: frames[index]!.ball, kind: "pass" }]
            : index < definition.steps.length - 1
              ? [
                  {
                    from: frames[index]!.players[2]!,
                    to: frames[index + 1]!.players[2]!,
                    kind: "run",
                  },
                ]
              : [],
      })),
    },
  };
}
