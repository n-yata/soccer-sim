<template>
  <div
    class="formation-card"
    :class="{ selected }"
    role="button"
    tabindex="0"
    :aria-pressed="selected"
    @click="$emit('select', formation.id)"
    @keydown.enter="$emit('select', formation.id)"
    @keydown.space.prevent="$emit('select', formation.id)"
  >
    <div class="formation-card__header">
      <span class="formation-card__name">{{ formation.name }}</span>
      <span v-if="selected" class="formation-card__badge">
        <AppIcon :icon="Check" />
        選択中
      </span>
    </div>
    <FormationMiniPitch class="formation-card__pitch" :formation="formation" />
    <p class="formation-card__description">{{ formation.description }}</p>
  </div>
</template>

<script setup lang="ts">
import { Check } from "@lucide/vue";
import type { Formation } from "@/types/formation";
import AppIcon from "./AppIcon.vue";
import FormationMiniPitch from "./FormationMiniPitch.vue";

defineProps<{
  formation: Formation;
  selected: boolean;
}>();

defineEmits<{
  select: [id: string];
}>();
</script>

<style scoped>
.formation-card {
  position: relative;
  box-sizing: border-box;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-md);
  padding: 16px;
  text-align: center;
  color: var(--color-text);
  cursor: pointer;
  transition: box-shadow 0.15s ease;
}

.formation-card:hover {
  box-shadow: var(--shadow-lg);
}

.formation-card.selected {
  /* border-widthは状態によらず1px固定（レイアウトジャンプ防止）。
     リングはbox-shadowで表現するためフロー幅に影響しない */
  border-color: var(--color-accent);
  box-shadow: 0 0 0 2px var(--color-accent);
  background-color: var(--color-accent-bg);
}

.formation-card.selected:hover {
  box-shadow:
    0 0 0 2px var(--color-accent),
    var(--shadow-lg);
}

.formation-card__header {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 20px;
  margin-bottom: 8px;
}

.formation-card__name {
  font-size: var(--font-lg);
  font-weight: var(--weight-semibold);
}

.formation-card__badge {
  display: inline-flex;
  align-items: center;
  gap: var(--space-xs);
  font-size: var(--font-xs);
  font-weight: var(--weight-medium);
  white-space: nowrap;
}

.formation-card__pitch {
  margin: 0 auto 8px;
  max-width: 120px;
  border-radius: var(--radius-sm);
  overflow: hidden;
}

.formation-card__description {
  margin: 0;
  font-size: var(--font-xs);
  font-weight: var(--weight-normal);
  line-height: var(--leading-normal);
  color: var(--color-text-sub);
}

@media (prefers-reduced-motion: reduce) {
  .formation-card {
    transition: none;
  }
}
</style>
