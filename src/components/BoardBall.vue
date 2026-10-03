<template>
  <svg ref="svgRef" viewBox="0 0 260 160" class="board-ball-overlay">
    <g
      class="board-ball"
      tabindex="0"
      role="img"
      aria-label="ボール。矢印キーで移動できます"
      :transform="`translate(${cx} ${cy})`"
      @pointerdown="startDrag"
      @pointermove="moveDrag"
      @pointerup="endDrag"
      @pointercancel="endDrag"
      @lostpointercapture="endDrag"
      @keydown="moveWithKey"
      @keyup="endKeyMove"
      @blur="finishMove"
    >
      <circle :r="hitRadius" class="board-ball__hit" aria-hidden="true" />
      <circle r="4.5" class="board-ball__body" aria-hidden="true" />
      <path
        d="M0 -2.5 L2.4 -0.8 L1.5 2 L-1.5 2 L-2.4 -0.8 Z"
        class="board-ball__pattern"
        aria-hidden="true"
      />
    </g>
  </svg>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import type { BoardBallPosition } from "@/data/boardBallStorage";

const props = defineProps<{ position: BoardBallPosition }>();
const emit = defineEmits<{
  "update-position": [position: BoardBallPosition];
  "update-position-end": [position: BoardBallPosition];
}>();

// 既存ピッチのviewBoxと同じ寸法。ボール本体が端で切れないよう半径分を内側へ寄せる。
const cx = computed(() => 5 + props.position.x * 2.5);
const cy = computed(() => 5 + props.position.y * 1.5);
const svgRef = ref<SVGSVGElement | null>(null);
const hitRadius = ref(9);
let resizeObserver: ResizeObserver | null = null;
let pointerId: number | null = null;
let pendingPosition: BoardBallPosition | null = null;

onMounted(() => {
  const svg = svgRef.value;
  if (!svg || typeof ResizeObserver === "undefined") return;
  // スマホ幅でもボールの操作領域を44px以上にする。
  resizeObserver = new ResizeObserver(() => {
    const width = svg.getBoundingClientRect().width;
    if (width > 0) hitRadius.value = Math.max(9, (22 * 260) / width);
  });
  resizeObserver.observe(svg);
});
onBeforeUnmount(() => resizeObserver?.disconnect());

function updatePosition(x: number, y: number): void {
  if (!Number.isFinite(x) || !Number.isFinite(y)) return;
  pendingPosition = { x: Math.min(100, Math.max(0, x)), y: Math.min(100, Math.max(0, y)) };
  emit("update-position", pendingPosition);
}

function finishMove(): void {
  if (pendingPosition) emit("update-position-end", pendingPosition);
  pendingPosition = null;
}

function startDrag(event: PointerEvent): void {
  if (event.button !== 0 || pointerId !== null) return;
  finishMove();
  pointerId = event.pointerId;
  (event.currentTarget as Element).setPointerCapture?.(event.pointerId);
}

function moveDrag(event: PointerEvent): void {
  if (pointerId === null || event.pointerId !== pointerId) return;
  if (event.buttons === 0) {
    endDrag(event);
    return;
  }
  const svg = svgRef.value;
  if (!svg) return;
  try {
    const ctm = svg.getScreenCTM?.();
    if (!ctm) return;
    const point = svg.createSVGPoint();
    point.x = event.clientX;
    point.y = event.clientY;
    const transformed = point.matrixTransform(ctm.inverse());
    updatePosition((transformed.x - 5) / 2.5, (transformed.y - 5) / 1.5);
  } catch {
    // 非表示などで逆変換できない瞬間は、最後の正常位置を維持する。
  }
}

function endDrag(event: PointerEvent): void {
  if (event.pointerId !== pointerId) return;
  pointerId = null;
  finishMove();
}

const KEY_DELTAS: Record<string, { x: number; y: number }> = {
  ArrowLeft: { x: -2.4, y: 0 },
  ArrowRight: { x: 2.4, y: 0 },
  ArrowUp: { x: 0, y: -4 },
  ArrowDown: { x: 0, y: 4 },
};

function moveWithKey(event: KeyboardEvent): void {
  const delta = KEY_DELTAS[event.key];
  if (!delta || pointerId !== null) return;
  event.preventDefault();
  const position = pendingPosition ?? props.position;
  updatePosition(position.x + delta.x, position.y + delta.y);
}

function endKeyMove(event: KeyboardEvent): void {
  if (KEY_DELTAS[event.key] && pointerId === null) finishMove();
}
</script>

<style scoped>
.board-ball-overlay {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  /* 端に置いたボールの透明な操作領域も、SVG枠で切り詰めない。 */
  overflow: visible;
  pointer-events: none;
}
.board-ball {
  pointer-events: all;
  touch-action: none;
  cursor: grab;
}
.board-ball:active {
  cursor: grabbing;
}
.board-ball__hit {
  fill: transparent;
}
.board-ball__body {
  fill: var(--color-surface);
  stroke: var(--color-text);
  stroke-width: 0.8;
}
.board-ball__pattern {
  fill: var(--color-text);
  pointer-events: none;
}
.board-ball:focus-visible .board-ball__body {
  stroke: var(--color-accent);
  stroke-width: 1.5;
}
</style>
