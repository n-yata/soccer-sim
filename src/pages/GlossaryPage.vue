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
      <div class="glossary-page__search">
        <label for="glossary-search" class="glossary-page__search-label">用語を探す</label>
        <div class="glossary-page__search-row">
          <input
            id="glossary-search"
            ref="searchInput"
            v-model="searchQuery"
            type="search"
            class="glossary-page__search-input"
            placeholder="用語や説明から検索"
          />
          <button
            v-if="searchQuery"
            type="button"
            class="glossary-page__clear-search"
            @click="clearSearch"
          >
            検索を消す
          </button>
        </div>
        <p class="glossary-page__search-count" role="status">{{ filteredCount }}件の用語</p>
      </div>
      <p v-if="groupedTerms.length === 0" class="glossary-page__empty">
        {{
          searchQuery
            ? "一致する用語が見つかりません。検索語を変えてください。"
            : "表示できる用語がありません。"
        }}
      </p>
      <section v-for="group in groupedTerms" :key="group.category" class="glossary-page__category">
        <h2 class="glossary-page__category-title">{{ group.category }}</h2>
        <dl class="glossary-page__list">
          <div v-for="term in group.terms" :key="term.id" class="glossary-page__entry">
            <dt class="glossary-page__term">{{ term.term }}</dt>
            <dd class="glossary-page__description">{{ term.description }}</dd>
          </div>
        </dl>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { BookOpen } from "@lucide/vue";
import AppIcon from "@/components/AppIcon.vue";
import PageHeader from "@/components/PageHeader.vue";
import { soccerTerms } from "@/data/soccerTerms";
import type { SoccerTermCategory } from "@/types/formation";

// 表示順を固定するため、データ配列の登場順ではなくこの順序でカテゴリを並べる
const categoryOrder: SoccerTermCategory[] = ["ポジション", "陣形・戦術", "攻守の考え方"];
const searchQuery = ref("");
const searchInput = ref<HTMLInputElement | null>(null);

function clearSearch(): void {
  searchQuery.value = "";
  searchInput.value?.focus();
}
const normalizedQuery = computed(() => searchQuery.value.trim().toLocaleLowerCase());
const filteredTerms = computed(() =>
  soccerTerms.filter((term) =>
    `${term.term} ${term.description}`.toLocaleLowerCase().includes(normalizedQuery.value),
  ),
);
const filteredCount = computed(() => filteredTerms.value.length);

// カテゴリごとに用語をグルーピングし、該当する用語が1件も無いカテゴリは除外する
const groupedTerms = computed(() =>
  categoryOrder
    .map((category) => ({
      category,
      terms: filteredTerms.value.filter((term) => term.category === category),
    }))
    .filter((group) => group.terms.length > 0),
);
</script>

<style scoped>
.glossary-page__body {
  padding: var(--space-xl) var(--gutter);
  max-width: var(--width-wide);
  margin: 0 auto;
}

.glossary-page__search {
  max-width: var(--width-narrow);
  margin-bottom: var(--space-xl);
}

.glossary-page__search-label {
  display: block;
  margin-bottom: var(--space-xs);
  font-size: var(--font-sm);
  font-weight: var(--weight-semibold);
}

.glossary-page__search-row {
  display: flex;
  gap: var(--space-sm);
  flex-wrap: wrap;
}

.glossary-page__search-input {
  flex: 1 1 240px;
  min-width: 0;
  min-height: 44px;
  padding: var(--space-sm) var(--space-md);
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-md);
  background: var(--color-surface);
}

.glossary-page__clear-search {
  min-height: 44px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: var(--space-sm) var(--space-md);
  background: var(--color-surface);
  cursor: pointer;
}

.glossary-page__search-count {
  margin-top: var(--space-xs);
  color: var(--color-text-sub);
  font-size: var(--font-sm);
}

.glossary-page__empty {
  color: var(--color-text-sub);
  line-height: var(--leading-relaxed);
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
@media (min-width: 901px) {
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

.glossary-page__description {
  margin: 4px 0 0;
  font-size: var(--font-sm);
  line-height: var(--leading-relaxed);
  color: var(--color-text-sub);
}

@media (max-width: 640px) {
  .glossary-page__body {
    padding: var(--space-lg) var(--gutter-mobile);
  }
}
</style>
