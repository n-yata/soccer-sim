<template>
  <div class="formation-list-page">
    <PageHeader
      title="⚽ フォーメーションラボ"
      subtitle="比較したいフォーメーションを2つ選んでください"
    >
      <a
        href="https://www.jleague.jp/j1/special/"
        target="_blank"
        rel="noopener noreferrer"
        class="formation-list-page__jleague-link"
      >
        ⚽ Jリーグ情報（外部サイト）
      </a>
    </PageHeader>
    <div class="formation-list-page__body">
      <div class="formation-list-page__grid">
        <FormationCard
          v-for="formation in formations"
          :key="formation.id"
          :formation="formation"
          :selected="selectedIds.includes(formation.id)"
          @select="toggleSelection"
        />
      </div>
      <p class="formation-list-page__footer">2つ選択すると自動的に比較画面へ遷移します</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import { useRouter } from "vue-router";
import FormationCard from "@/components/FormationCard.vue";
import PageHeader from "@/components/PageHeader.vue";
import { formations } from "@/data/formations";

const router = useRouter();
const selectedIds = ref<string[]>([]);

function toggleSelection(id: string): void {
  const index = selectedIds.value.indexOf(id);
  if (index !== -1) {
    selectedIds.value.splice(index, 1);
    return;
  }
  if (selectedIds.value.length === 2) {
    selectedIds.value.shift();
  }
  selectedIds.value.push(id);
}

watch(
  selectedIds,
  (ids) => {
    if (ids.length === 2) {
      router.push(`/compare/${ids[0]}/${ids[1]}`);
    }
  },
  { deep: true },
);
</script>

<style scoped>
.formation-list-page__jleague-link {
  /* 外部サイトへの遷移であることを、他の内部導線と区別できるよう破線枠にする */
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  box-sizing: border-box;
  border: 1px dashed rgba(255, 255, 255, 0.6);
  border-radius: var(--radius-pill);
  padding: var(--space-sm) var(--space-md);
  font-size: var(--font-sm);
  font-weight: 700;
  color: #ffffff;
  white-space: nowrap;
  transition: background-color 0.15s ease;
}

.formation-list-page__jleague-link:hover {
  background: rgba(255, 255, 255, 0.15);
}

.formation-list-page__body {
  padding: var(--space-xl) var(--space-2xl);
}

.formation-list-page__grid {
  display: grid;
  /* 画面幅に応じて列数が増減する可変グリッド（screen-design.md参照） */
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: var(--space-md);
  max-width: 1200px;
}

.formation-list-page__footer {
  display: inline-block;
  margin-top: var(--space-lg);
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
  color: #166534;
  font-size: var(--font-xs);
  font-style: italic;
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-pill);
}

@media (max-width: 640px) {
  .formation-list-page__body {
    padding: var(--space-lg) var(--space-md);
  }

  .formation-list-page__grid {
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  }
}

@media (prefers-reduced-motion: reduce) {
  .formation-list-page__jleague-link {
    transition: none;
  }
}
</style>
