// FreeLayoutPitchDiagram.vue が使う、実座標(0-100)とSVG座標の単純な線形マッピング。
// MatchupPitchDiagram.vueのクラスタリング・列アンカー補間・衝突回避とは異なり、
// ドラッグでつまんだ位置と deriveTags が使う実座標を一致させるため、往復可能な
// 単純な線形変換のみを行う。DOM(SVGのgetScreenCTM等)に依存しない純粋関数として
// 切り出すことで、jsdom環境でも座標変換そのものを直接検証できるようにしている。

export const PITCH_WIDTH = 260;
export const PITCH_HEIGHT = 160;
export const HALF_WIDTH = PITCH_WIDTH / 2;
export const LATERAL_MARGIN = 10;

/** 実座標のx(0-100, 幅方向)をSVGのcy(高さ方向)へ変換する */
export function xToCy(x: number): number {
  return LATERAL_MARGIN + (x / 100) * (PITCH_HEIGHT - LATERAL_MARGIN * 2);
}

/** SVGのcy(高さ方向)を実座標のx(0-100, 幅方向)へ逆変換する */
export function cyToX(cy: number): number {
  return ((cy - LATERAL_MARGIN) / (PITCH_HEIGHT - LATERAL_MARGIN * 2)) * 100;
}

/**
 * 実座標のy(0-100, 自陣0→敵陣100)をSVGのcx(奥行き方向)へ変換する。
 * Aチームは自陣(y=0)がcx=0側、Bチームは自陣(y=0)がcx=260側になるよう鏡映する
 * （中央cx=130で両チームが向き合う）。
 */
export function depthToCx(team: "A" | "B", y: number): number {
  const fromOwnGoal = (y / 100) * HALF_WIDTH;
  return team === "A" ? fromOwnGoal : PITCH_WIDTH - fromOwnGoal;
}

/** SVGのcx(奥行き方向)を実座標のy(0-100)へ逆変換する */
export function cxToDepth(team: "A" | "B", cx: number): number {
  const fromOwnGoal = team === "A" ? cx : PITCH_WIDTH - cx;
  return (fromOwnGoal / HALF_WIDTH) * 100;
}

/** ピッチ範囲(0-100)外に出ないようクランプする */
export function clampToPitchRange(value: number): number {
  return Math.min(100, Math.max(0, value));
}
