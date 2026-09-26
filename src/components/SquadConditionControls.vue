<template>
  <div class="squad-condition-controls">
    <button
      type="button"
      class="squad-condition-controls__toggle"
      :aria-pressed="isActive"
      @click="$emit('toggle')"
    >
      {{ isActive ? "✅ 選手個体差を反映中" : "🎲 選手個体差を反映する" }}
    </button>
    <button
      v-if="isActive"
      type="button"
      class="squad-condition-controls__reroll"
      @click="$emit('reroll')"
    >
      🔄 スカッドを組み直す
    </button>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  isActive: boolean;
}>();

defineEmits<{
  toggle: [];
  reroll: [];
}>();
</script>

<style scoped>
.squad-condition-controls {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
}

.squad-condition-controls__toggle,
.squad-condition-controls__reroll {
  min-height: 44px;
  box-sizing: border-box;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: #ffffff;
  box-shadow: var(--shadow-card);
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 700;
  color: #374151;
  cursor: pointer;
  transition:
    background-color 0.15s ease,
    border-color 0.15s ease,
    color 0.15s ease;
}

.squad-condition-controls__toggle:hover,
.squad-condition-controls__reroll:hover {
  background: var(--color-surface-hover);
}

.squad-condition-controls__toggle[aria-pressed="true"] {
  background: var(--color-team-a-bg);
  border-color: var(--color-team-a);
  color: #1e3a5f;
}

@media (prefers-reduced-motion: reduce) {
  .squad-condition-controls__toggle,
  .squad-condition-controls__reroll {
    transition: none;
  }
}
</style>
