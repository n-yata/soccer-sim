<template>
  <section class="match-simulation-panel" aria-label="試合シミュレーション結果">
    <div class="match-simulation-panel__scoreboard">
      <span class="match-simulation-panel__team match-simulation-panel__team--a">
        {{ formationAName }}
      </span>
      <span class="match-simulation-panel__score" aria-live="polite">
        {{ result.score.a }} - {{ result.score.b }}
      </span>
      <span class="match-simulation-panel__team match-simulation-panel__team--b">
        {{ formationBName }}
      </span>
    </div>

    <p class="match-simulation-panel__summary">
      <TermAnnotatedText :text="result.summary" />
    </p>

    <div class="match-simulation-panel__stats">
      <h3 class="match-simulation-panel__stats-title">ボール保持率</h3>
      <div
        class="match-simulation-panel__possession-bar"
        role="img"
        :aria-label="`ボール保持率 ${formationAName} ${result.possession.a}% 対 ${formationBName} ${result.possession.b}%`"
      >
        <div
          class="match-simulation-panel__possession-segment match-simulation-panel__possession-segment--a"
          :style="{ width: `${result.possession.a}%` }"
        />
        <div
          class="match-simulation-panel__possession-segment match-simulation-panel__possession-segment--b"
          :style="{ width: `${result.possession.b}%` }"
        />
      </div>
      <div class="match-simulation-panel__possession-labels">
        <span>{{ result.possession.a }}%</span>
        <span>{{ result.possession.b }}%</span>
      </div>

      <dl class="match-simulation-panel__shot-stats">
        <div class="match-simulation-panel__shot-row">
          <dt>シュート</dt>
          <dd>{{ result.shots.a }}</dd>
          <dd>{{ result.shots.b }}</dd>
        </div>
        <div class="match-simulation-panel__shot-row">
          <dt>枠内シュート</dt>
          <dd>{{ result.shotsOnTarget.a }}</dd>
          <dd>{{ result.shotsOnTarget.b }}</dd>
        </div>
      </dl>
    </div>

    <div class="match-simulation-panel__timeline-wrapper">
      <h3 class="match-simulation-panel__timeline-title">試合のハイライト</h3>
      <ol class="match-simulation-panel__timeline">
        <li
          v-for="(event, index) in result.timeline"
          :key="index"
          class="match-simulation-panel__event"
          :class="[
            `match-simulation-panel__event--${event.kind}`,
            `match-simulation-panel__event--team-${event.team.toLowerCase()}`,
          ]"
        >
          <span class="match-simulation-panel__event-minute">{{ event.minute }}分</span>
          <span class="match-simulation-panel__event-text">{{ event.text }}</span>
        </li>
        <li v-if="result.timeline.length === 0" class="match-simulation-panel__event-empty">
          <!-- ハーフタイム(FR-19)の前半45分ぶんの部分結果でもこのパネルを再利用するため、
               「90分」と決め打ちしない時間帯に依存しない文言にする -->
          目立った決定機のない時間帯だった
        </li>
      </ol>
    </div>
  </section>
</template>

<script setup lang="ts">
import TermAnnotatedText from "@/components/TermAnnotatedText.vue";
import type { MatchSimulationResult } from "@/types/formation";

defineProps<{
  result: MatchSimulationResult;
  formationAName: string;
  formationBName: string;
}>();
</script>

<style scoped>
.match-simulation-panel {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  box-shadow: var(--shadow-md);
  padding: 20px;
  margin-top: 16px;
  animation: match-simulation-panel-appear 0.4s ease-out both;
}

@keyframes match-simulation-panel-appear {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@media (prefers-reduced-motion: reduce) {
  .match-simulation-panel {
    animation: none;
  }
}

.match-simulation-panel__scoreboard {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  margin-bottom: 8px;
}

.match-simulation-panel__team {
  font-size: var(--font-md);
  font-weight: var(--weight-semibold);
}

.match-simulation-panel__team--a {
  color: var(--color-team-a);
}

.match-simulation-panel__team--b {
  color: var(--color-team-b);
}

.match-simulation-panel__score {
  font-size: var(--font-2xl);
  font-weight: var(--weight-bold);
  color: var(--color-text);
  font-variant-numeric: tabular-nums;
}

.match-simulation-panel__summary {
  margin: 0 0 16px;
  text-align: center;
  font-size: var(--font-sm);
  line-height: var(--leading-relaxed);
  color: var(--color-text-muted);
}

.match-simulation-panel__stats {
  margin-bottom: 20px;
}

.match-simulation-panel__stats-title {
  margin: 0 0 8px;
  font-size: var(--font-sm);
  font-weight: var(--weight-semibold);
  color: var(--color-text-sub);
}

.match-simulation-panel__possession-bar {
  display: flex;
  width: 100%;
  height: 12px;
  border-radius: var(--radius-pill);
  overflow: hidden;
  background: var(--color-border);
}

.match-simulation-panel__possession-segment {
  height: 100%;
}

.match-simulation-panel__possession-segment--a {
  background: var(--color-team-a);
}

.match-simulation-panel__possession-segment--b {
  background: var(--color-team-b);
}

.match-simulation-panel__possession-labels {
  display: flex;
  justify-content: space-between;
  margin-top: 4px;
  font-size: var(--font-xs);
  font-weight: var(--weight-medium);
  color: var(--color-text-sub);
}

.match-simulation-panel__shot-stats {
  margin: 16px 0 0;
}

.match-simulation-panel__shot-row {
  display: grid;
  grid-template-columns: 1fr auto auto;
  gap: 12px;
  align-items: center;
  padding: 6px 0;
  border-top: 1px solid var(--color-border);
  font-size: var(--font-sm);
}

.match-simulation-panel__shot-row dt {
  color: var(--color-text-sub);
}

.match-simulation-panel__shot-row dd {
  margin: 0;
  width: 32px;
  text-align: center;
  font-weight: var(--weight-semibold);
  color: var(--color-text);
}

.match-simulation-panel__timeline-title {
  margin: 0 0 8px;
  font-size: var(--font-sm);
  font-weight: var(--weight-semibold);
  color: var(--color-text-sub);
}

.match-simulation-panel__timeline {
  list-style: none;
  margin: 0;
  padding: 0;
  max-height: 280px;
  overflow-y: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.match-simulation-panel__event {
  display: flex;
  align-items: baseline;
  gap: 10px;
  padding: 8px 12px;
  border-bottom: 1px solid var(--color-border);
  font-size: var(--font-sm);
}

.match-simulation-panel__event:last-child {
  border-bottom: none;
}

.match-simulation-panel__event-minute {
  flex: 0 0 auto;
  width: 36px;
  font-weight: var(--weight-semibold);
  color: var(--color-text-sub);
  font-variant-numeric: tabular-nums;
}

.match-simulation-panel__event-text {
  flex: 1 1 auto;
  color: var(--color-text);
}

.match-simulation-panel__event--goal {
  background: var(--color-accent-bg);
  font-weight: var(--weight-semibold);
}

.match-simulation-panel__event--team-a .match-simulation-panel__event-minute {
  color: var(--color-team-a);
}

.match-simulation-panel__event--team-b .match-simulation-panel__event-minute {
  color: var(--color-team-b);
}

.match-simulation-panel__event-empty {
  padding: 16px 12px;
  text-align: center;
  color: var(--color-text-sub);
  font-size: var(--font-sm);
}
</style>
