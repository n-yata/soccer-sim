<template>
  <svg
    ref="svgRef"
    viewBox="0 0 260 160"
    class="free-layout-pitch"
    role="img"
    :aria-label="pitchAriaLabel"
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
    <rect x="0" y="0" width="260" height="160" class="free-layout-pitch__field" />
    <rect x="1" y="1" width="258" height="158" class="free-layout-pitch__outline" />
    <line x1="130" y1="0" x2="130" y2="160" class="free-layout-pitch__line" />
    <circle cx="130" cy="80" r="25" class="free-layout-pitch__line-shape" />
    <rect x="0" y="40" width="35" height="80" class="free-layout-pitch__line-shape" />
    <rect x="225" y="40" width="35" height="80" class="free-layout-pitch__line-shape" />

    <g class="free-layout-pitch__team free-layout-pitch__team--b">
      <g v-for="item in itemsB" :key="item.position.id">
        <circle
          :cx="item.cx"
          :cy="item.cy"
          r="4.5"
          class="free-layout-pitch__player red"
          :class="{ 'free-layout-pitch__player--draggable': isDraggable('B') }"
          @pointerdown="onPointerDown('B', item.position.id, $event)"
        />
        <text :x="item.cx" :y="item.cy - 7" text-anchor="middle" class="free-layout-pitch__label">
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
          class="free-layout-pitch__player blue"
          :class="{ 'free-layout-pitch__player--draggable': isDraggable('A') }"
          @pointerdown="onPointerDown('A', item.position.id, $event)"
        />
        <text :x="item.cx" :y="item.cy - 7" text-anchor="middle" class="free-layout-pitch__label">
          {{ item.position.label }}
        </text>
      </g>
    </g>
  </svg>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import type { Formation, Position } from "@/types/formation";
import { xToCy, cyToX, depthToCx, cxToDepth, clampToPitchRange } from "./freeLayoutCoordinates";

const props = withDefaults(
  defineProps<{
    formationA: Formation;
    formationB: Formation;
    // ドラッグ操作を受け付けるチーム。既定はAのみ（FR-15）。
    // ハーフタイム采配（自チーム拡張）ではA/B両方を渡す
    draggableTeams?: ("A" | "B")[];
  }>(),
  { draggableTeams: () => ["A"] },
);

const emit = defineEmits<{
  "update-position": [team: "A" | "B", positionId: string, x: number, y: number];
}>();

function isDraggable(team: "A" | "B"): boolean {
  return props.draggableTeams.includes(team);
}

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

const pitchAriaLabel = computed(() => {
  if (isDraggable("A") && isDraggable("B")) {
    return `${props.formationA.name}・${props.formationB.name}の配置をドラッグで調整できる自由配置モードのピッチ図`;
  }
  return `${props.formationA.name}の配置をドラッグで調整できる自由配置モードのピッチ図`;
});

const svgRef = ref<SVGSVGElement | null>(null);
const draggingPositionId = ref<string | null>(null);
const draggingTeam = ref<"A" | "B" | null>(null);

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
  if (!isDraggable(team)) return;
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
  emit("update-position", team, positionId, x, y);
}

function onPointerUp(): void {
  draggingPositionId.value = null;
  draggingTeam.value = null;
}
</script>

<style scoped>
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
}

.free-layout-pitch__player--draggable:active {
  cursor: grabbing;
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
