<template>
  <svg viewBox="-35 0 270 200" class="radar-chart" role="img" :aria-label="chartLabel">
    <polygon
      v-for="ring in gridRings"
      :key="ring.ratio"
      :points="ring.points"
      class="radar-chart__grid"
    />
    <line
      v-for="axis in axisLines"
      :key="axis.id"
      :x1="center"
      :y1="center"
      :x2="axis.x"
      :y2="axis.y"
      class="radar-chart__axis-line"
    />
    <text
      v-for="axis in axisLines"
      :key="`label-${axis.id}`"
      :x="axis.labelX"
      :y="axis.labelY"
      text-anchor="middle"
      dominant-baseline="middle"
      class="radar-chart__axis-label"
    >
      {{ axis.label }}
    </text>
    <g
      v-for="(s, seriesIndex) in seriesPolygons"
      :key="`${seriesIndex}-${s.label}`"
      :style="{ '--series-color': `var(${s.colorVar})` }"
    >
      <polygon :points="s.points" class="radar-chart__series" />
      <circle
        v-for="vertex in s.vertices"
        :key="vertex.axisId"
        :cx="vertex.x"
        :cy="vertex.y"
        r="3"
        class="radar-chart__vertex"
      />
    </g>
  </svg>
</template>

<script setup lang="ts">
import { computed } from "vue";
import type { RadarAxisMeta } from "@/data/radarAxes";
import type { FormationStats } from "@/types/formation";

const props = defineProps<{
  axes: readonly RadarAxisMeta[];
  maxValue: number;
  series: { label: string; colorVar: string; values: FormationStats }[];
}>();

const center = 100;
const radius = 70;
const labelRadius = 88;

// 真上(-90度)を先頭に、軸の数だけ時計回りに等分した角度を返す
function angleForIndex(index: number, total: number): number {
  return (-90 + (360 / total) * index) * (Math.PI / 180);
}

function pointOnAxis(index: number, total: number, distance: number) {
  const angle = angleForIndex(index, total);
  return {
    x: center + distance * Math.cos(angle),
    y: center + distance * Math.sin(angle),
  };
}

const axisLines = computed(() =>
  props.axes.map((axis, index) => {
    const point = pointOnAxis(index, props.axes.length, radius);
    const labelPoint = pointOnAxis(index, props.axes.length, labelRadius);
    return {
      id: axis.id,
      label: axis.label,
      x: point.x,
      y: point.y,
      labelX: labelPoint.x,
      labelY: labelPoint.y,
    };
  }),
);

// 25/50/75/100%の同心多角形（装飾のみの目盛り線）
const gridRings = computed(() =>
  [0.25, 0.5, 0.75, 1].map((ratio) => ({
    ratio,
    points: props.axes
      .map((_, index) => {
        const point = pointOnAxis(index, props.axes.length, radius * ratio);
        return `${point.x},${point.y}`;
      })
      .join(" "),
  })),
);

// スクリーンリーダー向けの代替テキスト。図形では伝わらない各系列の軸別数値を
// そのまま読み上げられるようにする
const chartLabel = computed(
  () =>
    `フォーメーション特性レーダーチャート（${props.maxValue}点満点）: ` +
    props.series
      .map(
        (s) =>
          `${s.label}は` +
          props.axes.map((axis) => `${axis.label}${s.values[axis.id]}`).join("、"),
      )
      .join(" / "),
);

const seriesPolygons = computed(() =>
  props.series.map((s) => {
    const vertices = props.axes.map((axis, index) => {
      // maxValueが0以下の場合、除算がNaNになりSVG座標が壊れるため0(中心)として扱う
      const ratio =
        props.maxValue > 0
          ? Math.max(0, Math.min(1, s.values[axis.id] / props.maxValue))
          : 0;
      const point = pointOnAxis(index, props.axes.length, radius * ratio);
      return { axisId: axis.id, x: point.x, y: point.y };
    });
    return {
      label: s.label,
      colorVar: s.colorVar,
      points: vertices.map((v) => `${v.x},${v.y}`).join(" "),
      vertices,
    };
  }),
);
</script>

<style scoped>
.radar-chart {
  width: 100%;
  height: auto;
}

.radar-chart__grid {
  fill: none;
  stroke: var(--color-border, #e5e7eb);
  stroke-width: 1;
}

.radar-chart__axis-line {
  stroke: var(--color-border, #e5e7eb);
  stroke-width: 1;
}

.radar-chart__axis-label {
  font-size: 7px;
  font-weight: 700;
  fill: var(--color-text-sub, #6b7280);
}

.radar-chart__series {
  fill: var(--series-color);
  fill-opacity: 0.25;
  stroke: var(--series-color);
  stroke-width: 2;
}

.radar-chart__vertex {
  fill: var(--series-color);
  stroke: #ffffff;
  stroke-width: 1;
}
</style>
