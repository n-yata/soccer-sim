<template>
  <div class="free-layout-controls">
    <button
      type="button"
      class="free-layout-controls__toggle"
      :aria-pressed="isActive"
      @click="$emit('toggle')"
    >
      {{ isActive ? "✅ 自由配置モード中" : "🖐️ 自由に配置を調整する" }}
    </button>
    <button
      v-if="isActive"
      type="button"
      class="free-layout-controls__reset"
      @click="$emit('reset')"
    >
      ↺ 配置をリセット
    </button>
  </div>
</template>

<script setup lang="ts">
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
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: #ffffff;
  box-shadow: var(--shadow-card);
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 700;
  color: #374151;
  cursor: pointer;
}

.free-layout-controls__toggle[aria-pressed="true"] {
  background: var(--color-team-a-bg);
  border-color: var(--color-team-a);
  color: #1e3a5f;
}
</style>
