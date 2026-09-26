<template>
  <div class="radar-chart-wrapper">
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
        v-for="(s, seriesIndex) in displaySeries"
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
    <!--
      role="img"のsvg配下のaria-labelは、値が変わっても再通知されるとは限らない
      （AT依存で信頼できない）。そのため、変化の通知は別要素のrole="status"
      （aria-live="polite"）で行う。liveLabelはdebounceしたテキストを表示し、
      ドラッグ中の高頻度な値変化（pointermoveのたびのchartLabel再計算）を
      そのまま読み上げキューに積まないようにする
    -->
    <div role="status" aria-live="polite" class="radar-chart__sr-only">{{ liveLabel }}</div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from "vue";
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

// aria-liveでの通知用テキスト。chartLabelをそのまま流すと、自由配置モードの
// ドラッグ中（pointermoveのたびに再計算される）や選手個体差の連続変更のたびに
// 長文の読み上げがキューへ積まれてしまう。実際の値変化から一定時間経っても
// 変化が続かなくなってから最新値を反映することで、ドラッグ確定後の1回程度に絞る
const LIVE_LABEL_DEBOUNCE_MS = 500;
const liveLabel = ref(chartLabel.value);
let liveLabelTimer: ReturnType<typeof setTimeout> | null = null;

watch(chartLabel, (next) => {
  if (liveLabelTimer !== null) clearTimeout(liveLabelTimer);
  liveLabelTimer = setTimeout(() => {
    liveLabel.value = next;
    liveLabelTimer = null;
  }, LIVE_LABEL_DEBOUNCE_MS);
});

onBeforeUnmount(() => {
  if (liveLabelTimer !== null) clearTimeout(liveLabelTimer);
});

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

// フォーメーション切替・自由配置モードのドラッグ・選手個体差のスコア変化のたびに
// 頂点がその場で瞬時にジャンプすると、どの軸がどれだけ変わったのか目で追えない。
// seriesPolygons（新しい目標値）とは別に、実際に描画する座標(displaySeries)を持ち、
// 目標値が変わるたびにrequestAnimationFrameで補間する。
// SVGの<polygon>のpoints属性はCSS transitionの対象外（アニメーション可能な
// プロパティとして定義されていない）ため、JS側で座標を補間する方式を採る
type DisplaySeries = (typeof seriesPolygons)["value"][number];

function cloneSeries(list: typeof seriesPolygons.value): DisplaySeries[] {
  return list.map((s) => ({
    label: s.label,
    colorVar: s.colorVar,
    points: s.points,
    vertices: s.vertices.map((v) => ({ ...v })),
  }));
}

function prefersReducedMotion(): boolean {
  return (
    typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

const RADAR_TRANSITION_MS = 300;
// 自由配置モードのドラッグ中はpointermoveのたびにseriesPolygonsが再計算される
// （FreeLayoutPitchDiagram.vue「1ドラッグで数十〜数百回」）。そのたびに300msの
// 補間をゼロからやり直すと、常に目標値より遅れ続ける「追従負け」が起きる。
// 直前の変化からこの時間未満で次の変化が来た場合は連続変化とみなし、補間せず
// 即座に反映することで、ドラッグ中は指の動きにそのまま追従させる
const RAPID_CHANGE_THRESHOLD_MS = 120;
const displaySeries = ref<DisplaySeries[]>(cloneSeries(seriesPolygons.value));
let rafId: number | null = null;
let lastChangeAt: number | null = null;

watch(seriesPolygons, (next) => {
  const from = displaySeries.value;
  // 系列数・軸数・軸の並び順が変わった場合は補間の対応が取れないため、即座に確定させる
  // （axisIdまで見ないと、頂点数が同じまま順序だけ変わったときに別軸同士を
  // 補間する無意味なモーフが起きる）
  const shapeMatches =
    from.length === next.length &&
    from.every(
      (s, i) =>
        s.vertices.length === next[i]?.vertices.length &&
        s.vertices.every((v, j) => v.axisId === next[i]?.vertices[j]?.axisId),
    );

  const now = performance.now();
  const isRapidChange =
    lastChangeAt !== null && now - lastChangeAt < RAPID_CHANGE_THRESHOLD_MS;
  lastChangeAt = now;

  if (prefersReducedMotion() || !shapeMatches || isRapidChange) {
    if (rafId !== null) cancelAnimationFrame(rafId);
    rafId = null;
    displaySeries.value = cloneSeries(next);
    return;
  }

  const fromSnapshot = cloneSeries(from);
  const start = performance.now();
  if (rafId !== null) cancelAnimationFrame(rafId);

  function step(now: number): void {
    const t = Math.min(1, (now - start) / RADAR_TRANSITION_MS);
    const eased = 1 - (1 - t) * (1 - t);
    displaySeries.value = next.map((target, seriesIndex) => {
      const fromS = fromSnapshot[seriesIndex];
      const vertices = target.vertices.map((v, vertexIndex) => {
        const fv = fromS.vertices[vertexIndex];
        return {
          axisId: v.axisId,
          x: fv.x + (v.x - fv.x) * eased,
          y: fv.y + (v.y - fv.y) * eased,
        };
      });
      return {
        label: target.label,
        colorVar: target.colorVar,
        points: vertices.map((v) => `${v.x},${v.y}`).join(" "),
        vertices,
      };
    });
    rafId = t < 1 ? requestAnimationFrame(step) : null;
  }

  rafId = requestAnimationFrame(step);
});

onBeforeUnmount(() => {
  if (rafId !== null) cancelAnimationFrame(rafId);
});
</script>

<style scoped>
.radar-chart-wrapper {
  width: 100%;
}

.radar-chart {
  width: 100%;
  height: auto;
}

.radar-chart__sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  margin: -1px;
  border: 0;
  padding: 0;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
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
