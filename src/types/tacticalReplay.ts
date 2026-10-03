export interface ReplayPoint {
  x: number;
  y: number;
}
export interface ReplayPosition extends ReplayPoint {
  id: string;
}
export interface ReplayFrame {
  players: ReplayPosition[];
  ball: ReplayPoint;
}
export interface ReplayPlayer {
  id: string;
  label: string;
  number: number;
  team: "attack" | "defence";
  formationPositionId?: string;
}
export interface ReplayRoute {
  from: ReplayPoint;
  to: ReplayPoint;
  kind: "run" | "pass";
}
export interface ReplayStep {
  title: string;
  explanation: string;
  observation: string;
  advantage: string;
  frame: ReplayFrame;
  routes: ReplayRoute[];
  space?: { x: number; y: number; width: number; height: number; label: string };
}
export interface TacticalScene {
  id: string;
  title: string;
  durationMs: number;
  players: ReplayPlayer[];
  steps: ReplayStep[];
  context?: string;
  areaLabel?: string;
}

export interface FormationLesson {
  formationId: string;
  objective: string;
  caution: string;
  scene: TacticalScene;
}
