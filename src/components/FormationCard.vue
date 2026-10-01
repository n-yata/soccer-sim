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
    <span v-if="selected" class="formation-card__badge">
      <AppIcon :icon="Check" size="sm" />
      選択中
    </span>
    <div class="formation-card__pitch-frame">
      <FormationMiniPitch class="formation-card__pitch" :formation="formation" />
    </div>
    <span class="formation-card__name">{{ formation.name }}</span>
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
  display: flex;
  flex-direction: column;
  align-items: center;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-xl);
  box-shadow: var(--shadow-md);
  padding: 20px 16px;
  text-align: center;
  color: var(--color-text);
  cursor: pointer;
  transition:
    box-shadow 0.15s ease,
    border-color 0.15s ease,
    background-color 0.15s ease;
}

.formation-card:hover {
  /* 2026-10-01: 4pxリフト+強い影は「浮き上がるカード」演出としてカジュアルに
     寄りすぎていた（指摘: モダンに見えない）ため撤回。Linear/Vercel系に倣い、
     レイヤーを動かさずborder-colorと背景の微変化だけで状態を示すフラットな
     ホバーへ変更する */
  border-color: var(--color-border-strong);
  background-color: var(--color-surface-hover);
}

.formation-card.selected {
  /* border-widthは状態によらず1px固定（レイアウトジャンプ防止）。
     リングはbox-shadowで表現するためフロー幅に影響しない */
  border-color: var(--color-accent);
  box-shadow: 0 0 0 2px var(--color-accent);
  background-color: var(--color-accent-bg);
}

.formation-card.selected:hover {
  background-color: var(--color-accent-bg);
}

.formation-card__badge {
  position: absolute;
  top: 12px;
  right: 12px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: var(--color-accent);
  color: var(--color-surface);
  border-radius: var(--radius-pill);
  padding: 3px 10px 3px 8px;
  font-size: var(--font-xs);
  font-weight: var(--weight-semibold);
  white-space: nowrap;
}

.formation-card__pitch-frame {
  width: 100%;
  max-width: 128px;
  margin: 4px auto 14px;
  padding: 10px;
  border-radius: var(--radius-md);
  background: var(--color-canvas);
}

.formation-card__pitch {
  border-radius: var(--radius-sm);
  overflow: hidden;
}

.formation-card__name {
  font-size: var(--font-xl);
  font-weight: var(--weight-bold);
  letter-spacing: -0.01em;
  font-variant-numeric: tabular-nums;
}

.formation-card__description {
  margin: 6px 0 0;
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
