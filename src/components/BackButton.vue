<template>
  <button type="button" class="back-button" @click="goBack">← 戻る</button>
</template>

<script setup lang="ts">
import { useRouter } from "vue-router";

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
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);
  background: var(--color-surface);
  box-shadow: var(--shadow-card);
  padding: var(--space-sm) var(--space-md);
  font-size: var(--font-sm);
  font-weight: 700;
  color: var(--color-text-muted);
  cursor: pointer;
}

.back-button:hover {
  background: var(--color-surface-hover);
}
</style>
