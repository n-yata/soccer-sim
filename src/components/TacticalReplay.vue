<template>
  <section class="tactical-replay" aria-label="動きで学ぶ戦術">
    <div class="tactical-replay__heading">
      <div>
        <p class="tactical-replay__eyebrow">動きで学ぶ戦術</p>
        <h2>{{ scene.title }}</h2>
        <p>守備者を引きつけると、どこが空く？ 選手とボールの動きで確かめよう。</p>
      </div>
      <button
        type="button"
        data-testid="replay-open"
        :aria-expanded="isOpen"
        :aria-controls="contentId"
        @click="isOpen = !isOpen"
      >
        <AppIcon :icon="isOpen ? ChevronUp : Play" />{{
          isOpen ? "教材を閉じる" : "場面を見て学ぶ"
        }}
      </button>
    </div>
    <div :id="contentId">
      <TacticalReplayPlayer v-if="isOpen" :scene="scene" />
    </div>
  </section>
</template>

<script setup lang="ts">
import { ref, useId } from "vue";
import { ChevronUp, Play } from "@lucide/vue";
import AppIcon from "./AppIcon.vue";
import TacticalReplayPlayer from "./TacticalReplayPlayer.vue";
import type { TacticalScene } from "@/types/tacticalReplay";

defineProps<{ scene: TacticalScene }>();

const isOpen = ref(false);
const contentId = useId();
</script>

<style scoped>
.tactical-replay {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  padding: var(--space-lg);
}
.tactical-replay__heading {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-lg);
}
.tactical-replay__eyebrow {
  color: var(--color-primary);
  font-size: var(--font-sm);
  font-weight: var(--weight-semibold);
  margin: 0 0 var(--space-xs);
}
h2 {
  font-size: var(--font-lg);
  margin: 0 0 var(--space-sm);
}
p {
  color: var(--color-text-sub);
  margin: 0;
  line-height: var(--leading-normal);
}
button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-sm);
  flex-shrink: 0;
  min-height: 44px;
  padding: var(--space-sm) var(--space-md);
  border: 1px solid var(--color-primary);
  border-radius: var(--radius-md);
  background: var(--color-primary);
  color: var(--color-surface);
  font: inherit;
  cursor: pointer;
}
button:focus-visible {
  outline: 3px solid var(--color-text);
  outline-offset: 3px;
}
@media (max-width: 640px) {
  .tactical-replay {
    padding: var(--space-md);
  }
  .tactical-replay__heading {
    align-items: stretch;
    flex-direction: column;
    gap: var(--space-md);
  }
}
</style>
