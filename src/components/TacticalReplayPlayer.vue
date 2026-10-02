<template>
  <div class="replay-player">
    <p class="replay-player__context">
      {{ scene.context ?? "局面を切り出した戦術教材です。" }}
    </p>
    <div class="replay-player__layout">
      <div>
        <TacticalReplayPitch
          :scene="scene"
          :frame="frame"
          :step="step"
          :is-moving="isPlaying"
          :is-at-checkpoint="progress === 0"
        />
        <div class="replay-player__legend">
          <span>● 青：学習する陣形</span><span>■ 赤：相手の守備</span><span>○ ボール</span>
        </div>
        <div class="replay-player__legend">
          <span>破線：走る道</span><span>黄色の矢印：パス</span>
        </div>
      </div>
      <div class="replay-player__lesson" aria-live="polite" aria-atomic="true">
        <p class="replay-player__count" data-testid="replay-step">
          解説 {{ index + 1 }} / {{ scene.steps.length }}<span v-if="isPlaying"> · 再生中</span
          ><span v-else-if="progress > 0"> · 移動途中で一時停止</span><span v-else> · 停止中</span>
        </p>
        <h3>{{ step.title }}</h3>
        <p class="replay-player__advantage">{{ step.advantage }}</p>
        <p>{{ step.explanation }}</p>
        <p v-if="progress > 0" class="replay-player__count">
          次の解説へ移動途中です。図の強調は到着後に表示します。
        </p>
        <div class="replay-player__observe">
          <strong>見るポイント</strong>
          <p>{{ step.observation }}</p>
        </div>
      </div>
    </div>
    <div class="replay-player__progress" aria-hidden="true">
      <span
        v-for="(_, i) in scene.steps"
        :key="i"
        :class="{ current: i === index, done: i < index }"
      />
    </div>
    <div class="replay-player__controls">
      <button
        type="button"
        data-testid="replay-prev"
        :disabled="index === 0 && progress === 0"
        @click="go(index - (progress > 0 ? 0 : 1))"
      >
        <AppIcon :icon="SkipBack" />前の解説
      </button>
      <button
        type="button"
        data-testid="replay-play"
        class="replay-player__primary"
        :disabled="isLastStep"
        @click="togglePlay"
      >
        <AppIcon :icon="isPlaying ? Pause : Play" />{{
          isPlaying
            ? "一時停止"
            : isLastStep
              ? "再生完了"
              : shouldReduceMotion
                ? "次の静止画へ"
                : index === 0 && progress === 0
                  ? "再生する"
                  : "続きを再生"
        }}
      </button>
      <button type="button" data-testid="replay-next" :disabled="isLastStep" @click="go(index + 1)">
        次の解説<AppIcon :icon="SkipForward" />
      </button>
      <button type="button" data-testid="replay-restart" @click="go(0)">
        <AppIcon :icon="RotateCcw" />最初から
      </button>
    </div>
    <p class="replay-player__hint">
      {{
        shouldReduceMotion
          ? "動きを減らす設定に合わせて、静止画で解説を進めます。"
          : "要所で自動停止します。読み終えたら「続きを再生」で進もう。"
      }}
    </p>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from "vue";
import { Pause, Play, RotateCcw, SkipBack, SkipForward } from "@lucide/vue";
import AppIcon from "./AppIcon.vue";
import TacticalReplayPitch from "./TacticalReplayPitch.vue";
import { interpolateFrame } from "./tacticalReplayFrame";
import type { TacticalScene } from "@/types/tacticalReplay";

const props = defineProps<{ scene: TacticalScene }>();
const index = ref(0);
const progress = ref(0);
const isPlaying = ref(false);
const shouldReduceMotion = ref(false);
const step = computed(() => props.scene.steps[index.value]!);
const isLastStep = computed(() => index.value === props.scene.steps.length - 1);
const frame = computed(() =>
  interpolateFrame(
    step.value.frame,
    props.scene.steps[index.value + 1]?.frame ?? step.value.frame,
    progress.value,
  ),
);
let timer: ReturnType<typeof setInterval> | undefined;
let motionQuery: MediaQueryList | undefined;

function pause(): void {
  if (timer !== undefined) clearInterval(timer);
  timer = undefined;
  isPlaying.value = false;
}

function go(target: number): void {
  pause();
  index.value = Math.max(0, Math.min(props.scene.steps.length - 1, target));
  progress.value = 0;
}

function togglePlay(): void {
  if (isPlaying.value) return pause();
  if (isLastStep.value || document.hidden) return;
  if (shouldReduceMotion.value) return go(index.value + 1);
  const started = performance.now();
  const previousProgress = progress.value;
  isPlaying.value = true;
  timer = setInterval(() => {
    progress.value = Math.min(
      1,
      previousProgress + (performance.now() - started) / props.scene.durationMs,
    );
    if (progress.value >= 1) go(index.value + 1);
  }, 32);
}

function visibilityChanged(): void {
  if (document.hidden) pause();
}

function motionChanged(event: MediaQueryListEvent): void {
  shouldReduceMotion.value = event.matches;
  if (event.matches && progress.value > 0) go(index.value + 1);
  else if (event.matches) pause();
}

onMounted(() => {
  motionQuery = window.matchMedia?.("(prefers-reduced-motion: reduce)");
  shouldReduceMotion.value = motionQuery?.matches ?? false;
  motionQuery?.addEventListener("change", motionChanged);
  document.addEventListener("visibilitychange", visibilityChanged);
});
onUnmounted(() => {
  pause();
  motionQuery?.removeEventListener("change", motionChanged);
  document.removeEventListener("visibilitychange", visibilityChanged);
});
</script>

<style scoped>
.replay-player {
  border-top: 1px solid var(--color-border);
  margin-top: var(--space-lg);
  padding-top: var(--space-md);
}
.replay-player__context,
.replay-player__hint {
  font-size: var(--font-sm);
  color: var(--color-text-sub);
  line-height: var(--leading-normal);
}
.replay-player__context {
  margin: 0 0 var(--space-md);
}
.replay-player__layout {
  display: grid;
  grid-template-columns: 1.2fr 1fr;
  gap: var(--space-lg);
  align-items: start;
}
.replay-player__legend {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-md);
  font-size: var(--font-xs);
  color: var(--color-text-muted);
  margin-top: var(--space-sm);
}
.replay-player__lesson {
  line-height: var(--leading-relaxed);
}
.replay-player__count {
  font-size: var(--font-sm);
  color: var(--color-text-sub);
  margin: 0 0 var(--space-sm);
}
h3 {
  font-size: var(--font-lg);
  margin: 0 0 var(--space-md);
  line-height: var(--leading-tight);
}
.replay-player__advantage {
  background: var(--color-primary-soft);
  color: var(--color-primary);
  padding: var(--space-sm) var(--space-md);
  border-left: 3px solid var(--color-primary);
  font-weight: var(--weight-semibold);
}
.replay-player__observe {
  border-top: 1px solid var(--color-border);
  margin-top: var(--space-md);
  padding-top: var(--space-md);
  font-size: var(--font-sm);
}
.replay-player__observe p {
  margin: var(--space-xs) 0 0;
}
.replay-player__progress {
  display: flex;
  gap: var(--space-xs);
  margin: var(--space-lg) 0 var(--space-md);
}
.replay-player__progress span {
  height: 4px;
  flex: 1;
  background: var(--color-border);
  border-radius: var(--radius-sm);
}
.replay-player__progress .current {
  background: var(--color-primary);
}
.replay-player__progress .done {
  background: var(--color-text-sub);
}
.replay-player__controls {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-sm);
}
button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-sm);
  min-height: 44px;
  padding: var(--space-sm) var(--space-md);
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text);
  font: inherit;
  cursor: pointer;
}
button:focus-visible {
  outline: 3px solid var(--color-text);
  outline-offset: 3px;
}
button:disabled {
  color: var(--color-text-sub);
  background: var(--color-surface-sub);
  cursor: default;
}
.replay-player__primary:not(:disabled) {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: var(--color-surface);
}
.replay-player__hint {
  margin: var(--space-sm) 0 0;
}
@media (max-width: 900px) {
  .replay-player__layout {
    grid-template-columns: 1fr;
  }
}
@media (max-width: 640px) {
  .replay-player__controls {
    display: grid;
    grid-template-columns: 1fr 1fr;
  }
  button {
    padding: var(--space-sm);
    font-size: var(--font-sm);
  }
}
</style>
