<template>
  <div class="formation-list-page">
    <PageHeader
      title="⚽ フォーメーションラボ"
      subtitle="比較したいフォーメーションを2つ選んでください"
    >
      <button type="button" class="formation-list-page__matrix-button" @click="goToMatrix">
        相性表を見る
      </button>
      <router-link to="/league" class="formation-list-page__league-link"> 🏆 リーグ戦 </router-link>
      <router-link
        v-if="formations.length === CUP_REQUIRED_FORMATION_COUNT"
        to="/cup"
        class="formation-list-page__cup-link"
      >
        🥇 カップ戦
      </router-link>
      <router-link to="/quiz" class="formation-list-page__quiz-link">
        ✏️ 理解度チェック
      </router-link>
      <router-link to="/glossary" class="formation-list-page__glossary-link">
        📖 用語集
      </router-link>
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
import { CUP_REQUIRED_FORMATION_COUNT, formations } from "@/data/formations";

const router = useRouter();
const selectedIds = ref<string[]>([]);

function goToMatrix(): void {
  router.push("/matrix");
}

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
.formation-list-page__matrix-button {
  /* 半透明の白オーバーレイでは、緑背景に対し白文字がAA(4.5:1)未達になるため、
     既存の戻るボタン等と同じ「不透明な白背景+濃色テキスト」に統一する */
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

.formation-list-page__matrix-button:hover {
  background: var(--color-surface-hover);
}

.formation-list-page__league-link,
.formation-list-page__cup-link,
.formation-list-page__glossary-link,
.formation-list-page__quiz-link {
  display: inline-block;
  border: 1px solid rgba(255, 255, 255, 0.6);
  border-radius: var(--radius-pill);
  padding: var(--space-sm) var(--space-md);
  font-size: var(--font-sm);
  font-weight: 700;
  color: #ffffff;
  white-space: nowrap;
}

.formation-list-page__body {
  padding: var(--space-xl) var(--space-2xl);
}

.formation-list-page__grid {
  display: grid;
  /* 最大3列の可変グリッド（狭幅画面では自動的に列数が減る。screen-design.md参照） */
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: var(--space-md);
  max-width: 640px;
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
</style>
