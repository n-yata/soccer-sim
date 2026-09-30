<template>
  <header class="page-header">
    <div class="page-header__row">
      <div class="page-header__heading">
        <BackButton v-if="showBackButton" :fallback-to="backFallbackTo" />
        <div>
          <h1 class="page-header__title"><slot name="title-icon" />{{ title }}</h1>
          <p v-if="subtitle" class="page-header__subtitle">{{ subtitle }}</p>
        </div>
      </div>
      <div v-if="$slots.default" class="page-header__actions">
        <slot />
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import BackButton from "@/components/BackButton.vue";

// 全画面共通のページヘッダー。戻るボタンの有無は呼び出し元が判断する
// （一覧画面のようなトップレベル画面にはbackボタンを出さない）
withDefaults(
  defineProps<{
    title: string;
    subtitle?: string;
    showBackButton?: boolean;
    backFallbackTo?: string;
  }>(),
  { subtitle: undefined, showBackButton: false, backFallbackTo: "/" },
);
</script>

<style scoped>
.page-header {
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  padding: var(--space-xl) var(--space-2xl);
  color: var(--color-text);
}

.page-header__row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--space-md);
  flex-wrap: wrap;
}

.page-header__heading {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  flex-wrap: wrap;
}

.page-header__title {
  display: inline-flex;
  align-items: center;
  gap: var(--space-sm);
  margin: 0;
  font-size: var(--font-2xl);
  font-weight: var(--weight-bold);
}

.page-header__subtitle {
  margin: var(--space-sm) 0 0;
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  color: var(--color-text-sub);
}

.page-header__actions {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  flex-wrap: wrap;
}

@media (max-width: 640px) {
  .page-header {
    padding: var(--space-lg) var(--space-md);
  }
}
</style>
