import type { FreeLayoutOverrides, Position } from "@/types/formation";

const STORAGE_KEY = "formation-lab.free-layout-overrides.v1";

const EMPTY: Readonly<FreeLayoutOverrides> = Object.freeze({});

// JSON.parseは"__proto__"等のキーを持つオブジェクトも普通に返す。通常オブジェクトへの
// 代入(obj[key] = ...)でこれらのキーを使うとプロトタイプの書き換えとして働き、
// 無関係なフォーメーション/ポジションの座標を誤って拾わせる経路になる。読み込み時点で除外する
const DANGEROUS_KEYS = new Set(["__proto__", "constructor", "prototype"]);

function clampToPitchRange(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.min(100, Math.max(0, value));
}

/**
 * localStorage から読んだ値が期待する形かを検証する。
 *
 * localStorage の中身は利用者が自由に書き換えられる。信用して適用すると
 * 壊れたデータで静かに誤る（座標がNaN・範囲外になり、タグ判定・描画が壊れる）ため、
 * 形が期待から外れた部分は保存無しとして扱う。フォーメーション単位・ポジション単位で
 * 部分的に不正でも、正しい部分までは活かす（1件の書き換えで全データを捨てない）。
 */
function parseOverrides(raw: string | null): FreeLayoutOverrides {
  if (raw === null) return EMPTY;

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return EMPTY;
  }

  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) return EMPTY;

  const result: FreeLayoutOverrides = {};
  for (const [formationId, positions] of Object.entries(parsed as Record<string, unknown>)) {
    if (DANGEROUS_KEYS.has(formationId)) continue;
    if (typeof positions !== "object" || positions === null || Array.isArray(positions)) continue;

    const positionEntries: Record<string, { x: number; y: number }> = {};
    for (const [positionId, coords] of Object.entries(positions as Record<string, unknown>)) {
      if (DANGEROUS_KEYS.has(positionId)) continue;
      if (typeof coords !== "object" || coords === null) continue;
      const { x, y } = coords as { x?: unknown; y?: unknown };
      if (typeof x !== "number" || typeof y !== "number") continue;
      if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
      positionEntries[positionId] = { x: clampToPitchRange(x), y: clampToPitchRange(y) };
    }

    if (Object.keys(positionEntries).length > 0) {
      result[formationId] = positionEntries;
    }
  }
  return result;
}

/**
 * 保存済みの自由配置オーバーライドを読む。
 * localStorage が使えない環境（プライベートモード・無効化）ではアクセス自体が
 * 例外を投げることがあるため、握って空として扱う（復元できないだけで画面は壊さない）。
 */
function loadOverrides(): FreeLayoutOverrides {
  try {
    return parseOverrides(window.localStorage.getItem(STORAGE_KEY));
  } catch {
    return EMPTY;
  }
}

/**
 * オーバーライドを保存する。容量超過などで失敗しても例外を外に出さない。
 */
function saveOverrides(overrides: FreeLayoutOverrides): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(overrides));
  } catch {
    // 保存できなくても、その場の画面操作は成立させる（永続化だけが効かない）
  }
}

/**
 * canonicalなpositionsに、保存済みのオーバーライド（あれば）をマージした配列を返す。
 * 保存が無いポジション、保存データに含まれないポジションIDはcanonicalな値のまま残る
 * （フォーメーションのポジション構成が将来変わっても、対応するIDが無いだけで安全に無視される）。
 */
export function applyOverrides(positions: Position[], formationId: string): Position[] {
  const overrides = loadOverrides()[formationId];
  if (!overrides) return positions.map((position) => ({ ...position }));

  return positions.map((position) => {
    const override = overrides[position.id];
    if (!override) return { ...position };
    return { ...position, x: override.x, y: override.y };
  });
}

/**
 * 1ポジション分の配置を保存する。フォーメーションID単位で管理するため、
 * 他フォーメーションの保存済みデータには影響しない。
 */
export function savePositionOverride(
  formationId: string,
  positionId: string,
  x: number,
  y: number,
): void {
  const overrides = loadOverrides();
  const forFormation = overrides[formationId] ?? {};
  saveOverrides({
    ...overrides,
    [formationId]: {
      ...forFormation,
      [positionId]: { x: clampToPitchRange(x), y: clampToPitchRange(y) },
    },
  });
}

/** 指定フォーメーションの保存済みオーバーライドを消去する（他フォーメーションには影響しない） */
export function clearFormationOverride(formationId: string): void {
  const overrides = loadOverrides();
  if (!(formationId in overrides)) return;
  const next = { ...overrides };
  delete next[formationId];
  saveOverrides(next);
}
