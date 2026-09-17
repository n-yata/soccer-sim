<template>
  <div class="glossary-page">
    <header class="glossary-page__header">
      <h1 class="glossary-page__title">📖 サッカー用語集</h1>
      <p class="glossary-page__subtitle">
        解説文に出てくる用語を、専門知識なしでも分かる言葉で説明します
      </p>
    </header>
    <div class="glossary-page__body">
      <router-link to="/" class="glossary-page__back-link"> ← 一覧画面へ戻る </router-link>
      <section v-for="group in groupedTerms" :key="group.category" class="glossary-page__category">
        <h2 class="glossary-page__category-title">{{ group.category }}</h2>
        <dl class="glossary-page__list">
          <template v-for="term in group.terms" :key="term.id">
            <dt class="glossary-page__term">
              {{ term.term }}
              <span class="glossary-page__reading">（{{ term.reading }}）</span>
            </dt>
            <dd class="glossary-page__description">{{ term.description }}</dd>
          </template>
        </dl>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { soccerTerms } from "@/data/soccerTerms";
import type { SoccerTermCategory } from "@/types/formation";

// 表示順を固定するため、データ配列の登場順ではなくこの順序でカテゴリを並べる
const categoryOrder: SoccerTermCategory[] = ["ポジション", "陣形・戦術", "攻守の考え方"];

// カテゴリごとに用語をグルーピングし、該当する用語が1件も無いカテゴリは除外する
const groupedTerms = computed(() =>
  categoryOrder
    .map((category) => ({
      category,
      terms: soccerTerms.filter((term) => term.category === category),
    }))
    .filter((group) => group.terms.length > 0),
);
</script>

<style scoped>
.glossary-page__header {
  background: linear-gradient(90deg, var(--color-primary), var(--color-primary-end));
  padding: 32px 40px;
  color: #ffffff;
}

.glossary-page__title {
  margin: 0;
  font-size: 28px;
  font-weight: 700;
}

.glossary-page__subtitle {
  margin: 8px 0 0;
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.35);
}

.glossary-page__body {
  padding: 32px 40px;
  max-width: 720px;
}

.glossary-page__back-link {
  display: inline-block;
  margin-bottom: 24px;
  font-size: 13px;
  font-weight: 700;
  color: var(--color-text);
}

.glossary-page__category {
  margin-bottom: 28px;
}

.glossary-page__category-title {
  margin: 0 0 12px;
  font-size: 16px;
  font-weight: 700;
  color: var(--color-primary);
  border-bottom: 2px solid var(--color-border);
  padding-bottom: 6px;
}

.glossary-page__list {
  margin: 0;
}

.glossary-page__term {
  font-size: 15px;
  font-weight: 700;
  color: var(--color-text);
  margin-top: 16px;
}

.glossary-page__reading {
  font-size: 12px;
  font-weight: 400;
  color: var(--color-text-sub);
}

.glossary-page__description {
  margin: 4px 0 0;
  font-size: 13px;
  line-height: 1.6;
  color: var(--color-text-sub);
}
</style>
