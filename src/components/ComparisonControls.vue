<template>
  <div class="comparison-controls">
    <div class="comparison-controls__select-group">
      <label for="comparison-select-a" class="comparison-controls__select-label--blue">
        青チームを変更
      </label>
      <select
        id="comparison-select-a"
        :value="formationAId"
        @change="$emit('select-a', ($event.target as HTMLSelectElement).value)"
      >
        <option
          v-for="candidate in formations"
          :key="candidate.id"
          :value="candidate.id"
          :disabled="candidate.id === formationBId"
        >
          {{ candidate.name }}
        </option>
      </select>
    </div>
    <button
      type="button"
      class="comparison-controls__swap-button"
      aria-label="青チームと赤チームを入れ替える"
      @click="$emit('swap')"
    >
      ⇄ 入れ替え
    </button>
    <div class="comparison-controls__select-group">
      <label for="comparison-select-b" class="comparison-controls__select-label--red">
        赤チームを変更
      </label>
      <select
        id="comparison-select-b"
        :value="formationBId"
        @change="$emit('select-b', ($event.target as HTMLSelectElement).value)"
      >
        <option
          v-for="candidate in formations"
          :key="candidate.id"
          :value="candidate.id"
          :disabled="candidate.id === formationAId"
        >
          {{ candidate.name }}
        </option>
      </select>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { Formation } from "@/types/formation";

defineProps<{
  formations: Formation[];
  formationAId: string;
  formationBId: string;
}>();

defineEmits<{
  swap: [];
  "select-a": [id: string];
  "select-b": [id: string];
}>();
</script>

<style scoped>
.comparison-controls {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}

.comparison-controls__select-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.comparison-controls__select-group label {
  font-size: 11px;
  font-weight: 700;
}

.comparison-controls__select-label--blue {
  color: var(--color-team-a);
}

.comparison-controls__select-label--red {
  color: var(--color-team-b);
}

.comparison-controls__select-group select {
  border: 1px solid var(--color-border);
  border-radius: 8px;
  padding: 6px 10px;
  font-size: 13px;
  background: #ffffff;
  color: var(--color-text);
}

.comparison-controls__swap-button {
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: #ffffff;
  box-shadow: var(--shadow-card);
  padding: 8px 14px;
  font-size: 13px;
  font-weight: 700;
  color: #374151;
  cursor: pointer;
}
</style>
