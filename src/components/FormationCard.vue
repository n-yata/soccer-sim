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
      <span v-if="selected" class="formation-card__badge">✓ 選択中</span>
    </div>
    <FormationMiniPitch class="formation-card__pitch" :formation="formation" />
    <p class="formation-card__description">{{ formation.description }}</p>
  </div>
</template>

<script setup lang="ts">
import type { Formation } from "@/types/formation";
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
  background: #ffffff;
  border: 3px solid var(--color-border);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
  padding: 16px;
  text-align: center;
  color: var(--color-text);
  cursor: pointer;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}

.formation-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 14px rgba(0, 0, 0, 0.12);
}

.formation-card.selected {
  border-color: var(--color-accent);
  background-color: var(--color-accent-bg);
  color: #b44712;
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
  font-size: 18px;
  font-weight: 700;
}

.formation-card__badge {
  font-size: 11px;
  font-weight: 700;
  white-space: nowrap;
}

.formation-card__pitch {
  margin: 0 auto 8px;
  max-width: 120px;
  border-radius: 4px;
  overflow: hidden;
}

.formation-card__description {
  margin: 0;
  font-size: 11px;
  font-weight: 400;
  line-height: 1.5;
  color: var(--color-text-sub);
}

.formation-card.selected .formation-card__description {
  color: #b44712;
}
</style>
