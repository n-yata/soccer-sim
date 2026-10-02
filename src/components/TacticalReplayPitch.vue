<template>
  <svg
    class="replay-pitch"
    viewBox="0 0 300 200"
    role="img"
    :aria-label="
      isAtCheckpoint
        ? `${step.title}。${step.observation}`
        : `${step.title}から次の解説へ移動途中のピッチ図`
    "
  >
    <defs>
      <marker
        :id="runMarker"
        viewBox="0 0 10 10"
        refX="8"
        refY="5"
        markerWidth="5"
        markerHeight="5"
        orient="auto-start-reverse"
      >
        <path d="M 0 0 L 10 5 L 0 10 z" class="replay-pitch__white" />
      </marker>
      <marker
        :id="passMarker"
        viewBox="0 0 10 10"
        refX="8"
        refY="5"
        markerWidth="5"
        markerHeight="5"
        orient="auto-start-reverse"
      >
        <path d="M 0 0 L 10 5 L 0 10 z" class="replay-pitch__yellow" />
      </marker>
    </defs>
    <rect width="300" height="200" rx="4" class="replay-pitch__grass" />
    <path
      d="M 10 10 H 290 V 190 H 10 Z M 290 42 H 239 V 125 H 290 M 290 65 H 270 V 101 H 290"
      class="replay-pitch__line"
    />
    <path d="M 290 73 H 297 V 93 H 290" class="replay-pitch__line" />
    <text x="20" y="28" class="replay-pitch__direction">攻撃方向 →</text>
    <text x="20" y="44" class="replay-pitch__caption">右サイドの局面</text>
    <g v-if="!isMoving && isAtCheckpoint && step.space">
      <rect
        :x="step.space.x"
        :y="step.space.y"
        :width="step.space.width"
        :height="step.space.height"
        rx="4"
        class="replay-pitch__space"
      />
      <text
        :x="step.space.x + step.space.width / 2"
        :y="step.space.y - 5"
        text-anchor="middle"
        class="replay-pitch__space-label"
      >
        {{ step.space.label }}
      </text>
    </g>
    <g v-if="!isMoving && isAtCheckpoint">
      <line
        v-for="(route, i) in step.routes"
        :key="i"
        :x1="route.from.x"
        :y1="route.from.y"
        :x2="route.to.x"
        :y2="route.to.y"
        :class="route.kind === 'run' ? 'replay-pitch__run' : 'replay-pitch__pass'"
        :marker-end="`url(#${route.kind === 'run' ? runMarker : passMarker})`"
      />
    </g>
    <g
      v-for="position in frame.players"
      :key="position.id"
      :data-player="position.id"
      :transform="`translate(${position.x}, ${position.y})`"
    >
      <circle v-if="player(position.id).team === 'attack'" r="10" class="replay-pitch__attacker" />
      <rect v-else x="-10" y="-10" width="20" height="20" rx="3" class="replay-pitch__defender" />
      <text text-anchor="middle" y="3.5" class="replay-pitch__number">
        {{ player(position.id).number }}
      </text>
      <title>
        {{ player(position.id).team === "attack" ? "青" : "赤" }}{{ player(position.id).number }}
        {{ player(position.id).label }}
      </title>
    </g>
    <g :transform="`translate(${frame.ball.x}, ${frame.ball.y})`" data-testid="replay-ball">
      <circle r="4" class="replay-pitch__ball" />
      <path d="M -2 -1 L 1 -2 L 2 1 L 0 2 L -2 0 Z" class="replay-pitch__ball-detail" />
    </g>
  </svg>
</template>

<script setup lang="ts">
import { useId } from "vue";
import type { ReplayFrame, ReplayStep, TacticalScene } from "@/types/tacticalReplay";

const props = defineProps<{
  scene: TacticalScene;
  frame: ReplayFrame;
  step: ReplayStep;
  isMoving: boolean;
  isAtCheckpoint: boolean;
}>();
const id = useId();
const runMarker = `${id}-run`;
const passMarker = `${id}-pass`;
function player(id: string) {
  return props.scene.players.find((player) => player.id === id)!;
}
</script>

<style scoped>
.replay-pitch {
  display: block;
  width: 100%;
  border-radius: var(--radius-md);
}
.replay-pitch__grass {
  fill: var(--color-pitch-dark);
}
.replay-pitch__line {
  fill: none;
  stroke: var(--color-surface);
  stroke-width: 1;
  opacity: 0.6;
}
.replay-pitch__direction,
.replay-pitch__caption,
.replay-pitch__number {
  fill: var(--color-surface);
  font-weight: var(--weight-bold);
  font-size: var(--font-xs);
}
.replay-pitch__caption {
  font-size: var(--font-xs);
  font-weight: var(--weight-normal);
}
.replay-pitch__attacker {
  fill: var(--color-team-a);
  stroke: var(--color-surface);
  stroke-width: 1.5;
}
.replay-pitch__defender {
  fill: var(--color-team-b);
  stroke: var(--color-surface);
  stroke-width: 1.5;
}
.replay-pitch__number {
  paint-order: stroke;
  stroke: var(--color-text);
  stroke-width: 0.9;
}
.replay-pitch__white {
  fill: var(--color-surface);
}
.replay-pitch__yellow {
  fill: var(--color-undefined-bg-alt);
}
.replay-pitch__run {
  stroke: var(--color-surface);
  stroke-width: 1.5;
  stroke-dasharray: 4 3;
}
.replay-pitch__pass {
  stroke: var(--color-undefined-bg-alt);
  stroke-width: 2;
}
.replay-pitch__space {
  fill: var(--color-undefined-bg-alt);
  fill-opacity: 0.15;
  stroke: var(--color-undefined-bg-alt);
  stroke-width: 1;
  stroke-dasharray: 3 2;
}
.replay-pitch__space-label {
  fill: var(--color-undefined-bg-alt);
  font-size: var(--font-xs);
  font-weight: var(--weight-bold);
}
.replay-pitch__ball {
  fill: var(--color-surface);
  stroke: var(--color-text);
  stroke-width: 1;
}
.replay-pitch__ball-detail {
  fill: var(--color-text);
}
</style>
