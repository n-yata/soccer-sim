<template>
  <div
    class="free-layout-pitch-wrapper"
    role="group"
    :aria-label="`${formationA.name}と${formationB.name}の配置。各選手にTabで移動し、矢印キーで位置を調整できます`"
  >
    <svg
      ref="svgRef"
      viewBox="0 0 260 160"
      class="free-layout-pitch"
      @pointermove="onPointerMove"
      @pointerup="onPointerUp"
      @pointercancel="onPointerUp"
    >
      <defs>
        <linearGradient id="freeLayoutPitchGradient" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#3cb043" />
          <stop offset="100%" stop-color="#1b5e20" />
        </linearGradient>
      </defs>
      <rect x="0" y="0" width="260" height="160" class="free-layout-pitch__field" aria-hidden="true" />
      <rect x="1" y="1" width="258" height="158" class="free-layout-pitch__outline" aria-hidden="true" />
      <line x1="130" y1="0" x2="130" y2="160" class="free-layout-pitch__line" aria-hidden="true" />
      <circle cx="130" cy="80" r="25" class="free-layout-pitch__line-shape" aria-hidden="true" />
      <rect x="0" y="40" width="35" height="80" class="free-layout-pitch__line-shape" aria-hidden="true" />
      <rect x="225" y="40" width="35" height="80" class="free-layout-pitch__line-shape" aria-hidden="true" />

      <g class="free-layout-pitch__team free-layout-pitch__team--b">
        <g v-for="item in itemsB" :key="item.position.id">
          <circle
            :cx="item.cx"
            :cy="item.cy"
            r="4.5"
            tabindex="0"
            :aria-label="`赤チーム ${item.position.label}。矢印キーで移動できます`"
            class="free-layout-pitch__player red free-layout-pitch__player--draggable"
            @pointerdown="onPointerDown('B', item.position.id, $event)"
            @keydown="onKeyDown('B', item, $event)"
            @keyup="onKeyUp('B', item, $event)"
          />
          <text
            :x="item.cx"
            :y="item.cy - 7"
            text-anchor="middle"
            class="free-layout-pitch__label"
            aria-hidden="true"
          >
            {{ item.position.label }}
          </text>
        </g>
      </g>
      <g class="free-layout-pitch__team free-layout-pitch__team--a">
        <g v-for="item in itemsA" :key="item.position.id">
          <circle
            :cx="item.cx"
            :cy="item.cy"
            r="4.5"
            tabindex="0"
            :aria-label="`青チーム ${item.position.label}。矢印キーで移動できます`"
            class="free-layout-pitch__player blue free-layout-pitch__player--draggable"
            @pointerdown="onPointerDown('A', item.position.id, $event)"
            @keydown="onKeyDown('A', item, $event)"
            @keyup="onKeyUp('A', item, $event)"
          />
          <text
            :x="item.cx"
            :y="item.cy - 7"
            text-anchor="middle"
            class="free-layout-pitch__label"
            aria-hidden="true"
          >
            {{ item.position.label }}
          </text>
        </g>
      </g>
    </svg>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import type { Formation, Position } from "@/types/formation";
import { xToCy, cyToX, depthToCx, cxToDepth, clampToPitchRange } from "./freeLayoutCoordinates";

const props = defineProps<{
  formationA: Formation;
  formationB: Formation;
}>();

const emit = defineEmits<{
  "update-position": [team: "A" | "B", positionId: string, x: number, y: number];
  // ドラッグ確定時（pointerup/pointercancel）にのみ発火する。永続化（呼び出し側の
  // savePositionOverride）はここでのみ行うことを想定している。update-positionは
  // pointermoveのたびに（1ドラッグで数十〜数百回）発火するため、表示更新用に留め、
  // 高コストな永続化はドラッグ完了時の1回に絞る
  "update-position-end": [team: "A" | "B", positionId: string, x: number, y: number];
}>();

interface Item {
  position: Position;
  cx: number;
  cy: number;
}

function toItems(team: "A" | "B", formation: Formation): Item[] {
  return formation.positions.map((position) => ({
    position,
    cx: depthToCx(team, position.y),
    cy: xToCy(position.x),
  }));
}

const itemsA = computed(() => toItems("A", props.formationA));
const itemsB = computed(() => toItems("B", props.formationB));

const svgRef = ref<SVGSVGElement | null>(null);
const draggingPositionId = ref<string | null>(null);
const draggingTeam = ref<"A" | "B" | null>(null);
// ドラッグ確定時(update-position-end)に使う直近の座標。onPointerMoveのたびに更新するが、
// emitはpointerup/pointercancel時の1回のみ
let lastCoords: { x: number; y: number } | null = null;

function toPitchCoords(clientX: number, clientY: number): { cx: number; cy: number } | null {
  const svg = svgRef.value;
  if (!svg) return null;
  const ctm = svg.getScreenCTM?.();
  if (!ctm) return null;
  const point = svg.createSVGPoint();
  point.x = clientX;
  point.y = clientY;
  const transformed = point.matrixTransform(ctm.inverse());
  // 要素が非表示・幅0でレイアウトされた瞬間などはCTMが非可逆になり、
  // 例外を投げずNaN成分を返すことがある。クランプはNaNを素通しするため、
  // ここで有限値かを確認してから返す（NaNがfreePositionsAへ入るとタグ判定が
  // 全て偽側に倒れ、優位ポイント・総合判定が静かに誤る）
  if (!Number.isFinite(transformed.x) || !Number.isFinite(transformed.y)) return null;
  return { cx: transformed.x, cy: transformed.y };
}

function onPointerDown(team: "A" | "B", positionId: string, event: PointerEvent): void {
  draggingTeam.value = team;
  draggingPositionId.value = positionId;
  (event.target as Element).setPointerCapture?.(event.pointerId);
}

function onPointerMove(event: PointerEvent): void {
  const positionId = draggingPositionId.value;
  const team = draggingTeam.value;
  if (!positionId || !team) return;
  // ポインタキャプチャが張れない/失われた環境では、SVG外でボタンを離しても
  // このコンポーネントのpointerupを受け取れない。ボタンが離されているのに
  // ドラッグ状態が残ると、ポインタを戻しただけで選手が追従し続けるため、
  // ここで取りこぼしたpointerupを回復する
  if (event.buttons === 0) {
    onPointerUp();
    return;
  }
  const coords = toPitchCoords(event.clientX, event.clientY);
  if (!coords) return;
  const x = clampToPitchRange(cyToX(coords.cy));
  const y = clampToPitchRange(cxToDepth(team, coords.cx));
  lastCoords = { x, y };
  emit("update-position", team, positionId, x, y);
}

function onPointerUp(): void {
  const positionId = draggingPositionId.value;
  const team = draggingTeam.value;
  // 一度もpointermoveが発火しないままpointerup（クリックのみ等）の場合はlastCoordsが無く、
  // 確定すべき変更も無いためemitしない
  if (positionId && team && lastCoords) {
    emit("update-position-end", team, positionId, lastCoords.x, lastCoords.y);
  }
  draggingPositionId.value = null;
  draggingTeam.value = null;
  lastCoords = null;
}

// ポインタドラッグのみでは選手を1人も動かせないキーボード専用ユーザーが取り残される
// （WCAG 2.1.1）ため、矢印キーによる代替操作を提供する。
//
// 長押しするとブラウザはkeydownをオートリピート（一般に約20-30回/秒）するため、
// 「押下のたびにupdate-position-end（永続化）までemitする」とドラッグのpointermoveと
// 同種の高頻度I/O問題が復活する。ドラッグがpointerdown〜pointerupを1つの操作区間として
// 扱うのと同じく、キーボードもkeydown（連打含む）〜keyup を1つの操作区間として扱い、
// 表示更新（update-position）は毎回、永続化（update-position-end）はkeyup時の1回のみ
// にする
const KEYBOARD_STEP = 6;
let keyboardMoveTeam: "A" | "B" | null = null;
let keyboardMovePositionId: string | null = null;
let keyboardLastCoords: { x: number; y: number } | null = null;

function computeKeyboardDelta(event: KeyboardEvent): { dcx: number; dcy: number } | null {
  switch (event.key) {
    case "ArrowLeft":
      return { dcx: -KEYBOARD_STEP, dcy: 0 };
    case "ArrowRight":
      return { dcx: KEYBOARD_STEP, dcy: 0 };
    case "ArrowUp":
      return { dcx: 0, dcy: -KEYBOARD_STEP };
    case "ArrowDown":
      return { dcx: 0, dcy: KEYBOARD_STEP };
    default:
      return null;
  }
}

function onKeyDown(team: "A" | "B", item: Item, event: KeyboardEvent): void {
  const delta = computeKeyboardDelta(event);
  if (!delta) return;
  event.preventDefault();

  const x = clampToPitchRange(cyToX(item.cy + delta.dcy));
  const y = clampToPitchRange(cxToDepth(team, item.cx + delta.dcx));
  keyboardMoveTeam = team;
  keyboardMovePositionId = item.position.id;
  keyboardLastCoords = { x, y };
  emit("update-position", team, item.position.id, x, y);
}

function onKeyUp(team: "A" | "B", item: Item, event: KeyboardEvent): void {
  if (!computeKeyboardDelta(event)) return;
  if (
    keyboardMoveTeam === team &&
    keyboardMovePositionId === item.position.id &&
    keyboardLastCoords
  ) {
    emit("update-position-end", team, item.position.id, keyboardLastCoords.x, keyboardLastCoords.y);
  }
  keyboardMoveTeam = null;
  keyboardMovePositionId = null;
  keyboardLastCoords = null;
}
</script>

<style scoped>
.free-layout-pitch-wrapper {
  width: 100%;
}

.free-layout-pitch {
  width: 100%;
  height: auto;
  touch-action: none;
}

.free-layout-pitch__field {
  fill: url(#freeLayoutPitchGradient);
}

.free-layout-pitch__outline {
  fill: none;
  stroke: #ffffff;
  stroke-opacity: 0.7;
  stroke-width: 1;
}

.free-layout-pitch__line {
  stroke: #ffffff;
  stroke-opacity: 0.7;
  stroke-width: 0.8;
}

.free-layout-pitch__line-shape {
  fill: none;
  stroke: #ffffff;
  stroke-opacity: 0.7;
  stroke-width: 0.8;
}

.free-layout-pitch__player.blue {
  fill: #2563eb;
  stroke: #ffffff;
  stroke-width: 1;
  filter: drop-shadow(0 0.5px 1px rgba(0, 0, 0, 0.4));
}

.free-layout-pitch__player.red {
  fill: #ef4444;
  stroke: #ffffff;
  stroke-width: 1;
  filter: drop-shadow(0 0.5px 1px rgba(0, 0, 0, 0.4));
}

.free-layout-pitch__player--draggable {
  cursor: grab;
  /* r/cx/cyのCSSプロパティ化(SVG2)はSafari/iOSが未対応のため、
     transform(fill-box基準の拡大)で代替する */
  transform-box: fill-box;
  transform-origin: center;
  transition:
    transform 0.15s ease,
    stroke-width 0.15s ease;
}

.free-layout-pitch__player--draggable:hover,
.free-layout-pitch__player--draggable:focus-visible {
  transform: scale(1.25);
  stroke-width: 1.5;
}

.free-layout-pitch__player--draggable:active {
  cursor: grabbing;
}

.free-layout-pitch__player--draggable:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 1px;
}

@media (prefers-reduced-motion: reduce) {
  .free-layout-pitch__player--draggable {
    transition: none;
  }

  .free-layout-pitch__player--draggable:hover,
  .free-layout-pitch__player--draggable:focus-visible {
    transform: none;
  }
}

.free-layout-pitch__label {
  font-size: 3.5px;
  font-weight: 700;
  fill: #ffffff;
  paint-order: stroke;
  stroke: #000000;
  stroke-width: 0.6px;
  pointer-events: none;
}
</style>
