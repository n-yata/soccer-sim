<template>
  <header class="page-header" :class="{ 'page-header--hero': variant === 'hero' }">
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
// （一覧画面のようなトップレベル画面にはbackボタンを出さない）。
// variant="hero": トップレベル画面（一覧画面）専用の強調表示。タイトルを大きく、
// 背景にアンビエントなグラデーションを添える。DOM構造・クラス名は通常版と同一のため
// 既存テスト（page-header__actions配下の検証等）に影響しない
withDefaults(
  defineProps<{
    title: string;
    subtitle?: string;
    showBackButton?: boolean;
    backFallbackTo?: string;
    variant?: "default" | "hero";
  }>(),
  { subtitle: undefined, showBackButton: false, backFallbackTo: "/", variant: "default" },
);
</script>

<style scoped>
.page-header {
  position: relative;
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  padding: var(--space-xl) var(--gutter);
  color: var(--color-text);
}

/* 2026-10-01: 当初ここに角の2方向からにじませるradial-gradientの
   アンビエント演出を入れていたが、「とりあえず作った感」の典型（Linear/Vercel系の
   引き締まった印象と逆方向）という指摘を受けて撤回。hero版も通常版と同じ
   フラットな面のまま、タイポグラフィの大きさだけで強調する */
.page-header--hero {
  padding-block: var(--space-2xl);
}

.page-header__row {
  position: relative;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--space-md);
  flex-wrap: wrap;
  max-width: var(--width-wide);
  margin: 0 auto;
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

.page-header--hero .page-header__title {
  font-size: var(--font-3xl);
  letter-spacing: -0.02em;
}

.page-header__subtitle {
  margin: var(--space-sm) 0 0;
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  color: var(--color-text-sub);
}

.page-header--hero .page-header__subtitle {
  font-size: var(--font-md);
  margin-top: var(--space-sm);
}

.page-header__actions {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  flex-wrap: wrap;
}

@media (max-width: 640px) {
  .page-header {
    padding: var(--space-lg) var(--gutter-mobile);
  }

  .page-header--hero {
    padding-block: var(--space-xl);
  }

  .page-header--hero .page-header__title {
    font-size: var(--font-2xl);
  }
}
</style>
