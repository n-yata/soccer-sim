<template>
  <button type="button" class="back-button" @click="goBack">
    <AppIcon :icon="ArrowLeft" />
    戻る
  </button>
</template>

<script setup lang="ts">
import { useRouter } from "vue-router";
import { ArrowLeft } from "@lucide/vue";
import AppIcon from "./AppIcon.vue";

const props = withDefaults(defineProps<{ fallbackTo?: string }>(), {
  fallbackTo: "/",
});

const router = useRouter();

// vue-routerのhistoryモードはhistory.stateに前後のルートパスを持つため、
// アプリ内遷移の履歴があるときだけrouter.back()で遷移元へ戻す。
// 履歴が無い（URL直打ち等）場合のみfallbackToへ固定する
function goBack(): void {
  if (window.history.state?.back) {
    router.back();
    return;
  }
  router.push(props.fallbackTo);
}
</script>

<style scoped>
.back-button {
  display: inline-flex;
  align-items: center;
  gap: var(--space-xs);
  min-height: 44px;
  box-sizing: border-box;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);
  background: var(--color-surface);
  box-shadow: var(--shadow-card);
  padding: var(--space-sm) var(--space-md);
  font-size: var(--font-sm);
  font-weight: 700;
  color: var(--color-text-muted);
  cursor: pointer;
  transition:
    background-color 0.15s ease,
    transform 0.15s ease;
}

.back-button:hover {
  background: var(--color-surface-hover);
  transform: translateY(-1px);
}

@media (prefers-reduced-motion: reduce) {
  .back-button {
    transition: none;
  }
}
</style>
