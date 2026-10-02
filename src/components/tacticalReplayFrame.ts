import type { ReplayFrame, ReplayPoint } from "@/types/tacticalReplay";

/** 選手は配列順ではなくIDで追跡する。入力フレームを変更しない。 */
export function interpolateFrame(
  from: ReplayFrame,
  to: ReplayFrame,
  progress: number,
): ReplayFrame {
  const fraction = Number.isFinite(progress) ? Math.max(0, Math.min(1, progress)) : 0;
  const point = (a: ReplayPoint, b: ReplayPoint): ReplayPoint => ({
    x: a.x + (b.x - a.x) * fraction,
    y: a.y + (b.y - a.y) * fraction,
  });
  return {
    players: from.players.map((player) => ({
      id: player.id,
      ...point(player, to.players.find((target) => target.id === player.id) ?? player),
    })),
    ball: point(from.ball, to.ball),
  };
}
