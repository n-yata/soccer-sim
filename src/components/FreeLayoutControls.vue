<template>
  <div class="free-layout-controls">
    <button
      type="button"
      class="free-layout-controls__toggle"
      :aria-pressed="isActive"
      @click="$emit('toggle')"
    >
      <AppIcon :icon="isActive ? Check : Hand" />
      {{ isActive ? "自由配置モード中" : "自由に配置を調整する" }}
    </button>
    <button
      v-if="isActive"
      type="button"
      class="free-layout-controls__reset"
      @click="$emit('reset')"
    >
      <AppIcon :icon="RotateCcw" />
      配置をリセット
    </button>
  </div>
</template>

<script setup lang="ts">
import { Check, Hand, RotateCcw } from "@lucide/vue";
import AppIcon from "./AppIcon.vue";

defineProps<{
  isActive: boolean;
}>();

defineEmits<{
  toggle: [];
  reset: [];
}>();
</script>

<style scoped>
.free-layout-controls {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
}

.free-layout-controls__toggle,
.free-layout-controls__reset {
  display: inline-flex;
  align-items: center;
  gap: var(--space-xs);
  min-height: 44px;
  box-sizing: border-box;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);
  background: #ffffff;
  box-shadow: var(--shadow-md);
  padding: 8px 16px;
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  color: #374151;
  cursor: pointer;
  transition:
    background-color 0.15s ease,
    border-color 0.15s ease,
    color 0.15s ease;
}

.free-layout-controls__toggle:hover,
.free-layout-controls__reset:hover {
  background: var(--color-surface-hover);
}

.free-layout-controls__toggle[aria-pressed="true"] {
  background: var(--color-team-a-bg);
  border-color: var(--color-team-a);
  color: #1e3a5f;
}

@media (prefers-reduced-motion: reduce) {
  .free-layout-controls__toggle,
  .free-layout-controls__reset {
    transition: none;
  }
}
</style>
