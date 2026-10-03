export interface BoardBallPosition {
  x: number;
  y: number;
}

export const BOARD_BALL_CENTER: Readonly<BoardBallPosition> = Object.freeze({ x: 50, y: 50 });
const STORAGE_KEY = "formation-lab.board-ball.v1";

function parsePosition(value: unknown): BoardBallPosition | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const { x, y } = value as { x?: unknown; y?: unknown };
  if (typeof x !== "number" || typeof y !== "number") return null;
  if (!Number.isFinite(x) || !Number.isFinite(y)) return null;
  return { x: Math.min(100, Math.max(0, x)), y: Math.min(100, Math.max(0, y)) };
}

/** 保存先が使えない場合も、ボードの操作は中央から開始できる。 */
export function loadBoardBallPosition(): BoardBallPosition {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    return (raw ? parsePosition(JSON.parse(raw)) : null) ?? { ...BOARD_BALL_CENTER };
  } catch {
    return { ...BOARD_BALL_CENTER };
  }
}

/** 高頻度の操作途中では呼ばず、操作確定時に保存する。 */
export function saveBoardBallPosition(position: BoardBallPosition): void {
  const valid = parsePosition(position);
  if (!valid) return;
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(valid));
  } catch {
    // 保存失敗でも表示中の配置を維持し、操作を継続させる。
  }
}
