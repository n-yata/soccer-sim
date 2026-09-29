<template>
  <div class="glossary-page">
    <PageHeader
      show-back-button
      title="サッカー用語集"
      subtitle="解説文に出てくる用語を、専門知識なしでも分かる言葉で説明します"
    >
      <template #title-icon>
        <AppIcon :icon="BookOpen" size="lg" />
      </template>
    </PageHeader>
    <div class="glossary-page__body">
      <section v-for="group in groupedTerms" :key="group.category" class="glossary-page__category">
        <h2 class="glossary-page__category-title">{{ group.category }}</h2>
        <dl class="glossary-page__list">
          <div v-for="term in group.terms" :key="term.id" class="glossary-page__entry">
            <dt class="glossary-page__term">
              {{ term.term }}
              <span class="glossary-page__reading">（{{ term.reading }}）</span>
            </dt>
            <dd class="glossary-page__description">{{ term.description }}</dd>
          </div>
        </dl>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { BookOpen } from "@lucide/vue";
import AppIcon from "@/components/AppIcon.vue";
import PageHeader from "@/components/PageHeader.vue";
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
.glossary-page__body {
  padding: var(--space-xl) var(--space-2xl);
  max-width: 1000px;
}

.glossary-page__category {
  margin-bottom: var(--space-lg);
}

.glossary-page__category-title {
  margin: 0 0 var(--space-sm);
  font-size: var(--font-md);
  font-weight: var(--weight-semibold);
  color: var(--color-primary);
  border-bottom: 2px solid var(--color-border);
  padding-bottom: 6px;
}

.glossary-page__list {
  margin: 0;
}

/* 広い画面幅では2カラムに段組みし、縦スクロール量を減らす。
   dt/ddのペアが段の境目で分断されないよう、divでペアをまとめてbreak-insideを指定する
   （dl直下へのdiv配置はHTML5仕様上、dt/ddのグルーピングとして許容されている） */
@media (min-width: 769px) {
  .glossary-page__list {
    columns: 2;
    column-gap: var(--space-xl);
  }
}

.glossary-page__entry {
  break-inside: avoid;
}

.glossary-page__term {
  font-size: var(--font-md);
  font-weight: var(--weight-semibold);
  color: var(--color-text);
  margin-top: var(--space-md);
}

.glossary-page__reading {
  font-size: var(--font-xs);
  font-weight: var(--weight-normal);
  color: var(--color-text-sub);
}

.glossary-page__description {
  margin: 4px 0 0;
  font-size: var(--font-sm);
  line-height: var(--leading-relaxed);
  color: var(--color-text-sub);
}

@media (max-width: 640px) {
  .glossary-page__body {
    padding: var(--space-lg) var(--space-md);
  }
}
</style>
