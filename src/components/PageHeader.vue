<template>
  <header class="page-header">
    <div class="page-header__row">
      <div class="page-header__heading">
        <BackButton v-if="showBackButton" :fallback-to="backFallbackTo" />
        <div>
          <h1 class="page-header__title">{{ title }}</h1>
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
  background: linear-gradient(90deg, var(--color-primary), var(--color-primary-end));
  padding: var(--space-xl) var(--space-2xl);
  color: #ffffff;
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
  margin: 0;
  font-size: var(--font-2xl);
  font-weight: 700;
}

.page-header__subtitle {
  margin: var(--space-sm) 0 0;
  font-size: var(--font-sm);
  font-weight: 600;
  color: #ffffff;
  /* text-shadowはWCAGのコントラスト比計算に算入されない。AA(4.5:1)を満たすため、
     白文字と組み合わせて--color-primary/--color-primary-end自体を暗めの値にしている
     （tokens.css）。text-shadowは可読性の補助のみ */
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.35);
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
