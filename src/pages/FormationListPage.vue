<template>
  <div class="formation-list-page">
    <PageHeader
      title="フォーメーションラボ"
      subtitle="2つのフォーメーションがどう噛み合うかを、ピッチ図と解説で比較する"
      variant="hero"
    >
      <template #title-icon>
        <AppIcon :icon="Goal" size="lg" />
      </template>
      <a
        v-if="jleagueUrl"
        :href="jleagueUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="formation-list-page__jleague-link"
      >
        <AppIcon :icon="ExternalLink" />
        Jリーグの試合日程・キャンペーン情報（外部サイト・新規タブ）
      </a>
    </PageHeader>
    <div class="formation-list-page__body">
      <div class="formation-list-page__section-intro">
        <span class="formation-list-page__eyebrow">STEP 1</span>
        <h2 class="formation-list-page__section-title">比較したい2つを選ぶ</h2>
        <p class="formation-list-page__selection-status" role="status" aria-live="polite">
          {{ selectionStatus }}
        </p>
      </div>
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
import { computed, ref, watch } from "vue";
import { useRouter } from "vue-router";
import { ExternalLink, Goal } from "@lucide/vue";
import AppIcon from "@/components/AppIcon.vue";
import FormationCard from "@/components/FormationCard.vue";
import PageHeader from "@/components/PageHeader.vue";
import { formations } from "@/data/formations";

const router = useRouter();
const jleagueUrl = configuredJleagueUrl();

function configuredJleagueUrl(): string | undefined {
  const configured = import.meta.env.VITE_JLEAGUE_URL?.trim();
  if (!configured) return undefined;
  try {
    const url = new URL(configured);
    if (url.protocol !== "https:" || url.username || url.password) return undefined;
    return url.href;
  } catch {
    return undefined;
  }
}

const selectedIds = ref<string[]>([]);
const selectionStatus = computed(() => {
  if (selectedIds.value.length === 0) return "あと2つ選ぶと比較を始めます";
  if (selectedIds.value.length === 1) {
    const selected = formations.find((formation) => formation.id === selectedIds.value[0]);
    return `${selected?.name ?? "1つ"}を選択中。あと1つ選ぶと比較画面へ進みます`;
  }
  return "比較画面を開きます";
});

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
  border: 1px dashed var(--color-border-strong);
  border-radius: var(--radius-pill);
  padding: var(--space-sm) var(--space-md);
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  color: var(--color-text-muted);
  white-space: normal;
  gap: var(--space-xs);
  max-width: 100%;
  transition: background-color 0.15s ease;
}

.formation-list-page__jleague-link:hover {
  background: var(--color-surface-hover);
}

.formation-list-page__body {
  max-width: var(--width-wide);
  margin: 0 auto;
  padding: var(--space-xl) var(--gutter);
}

.formation-list-page__section-intro {
  margin-bottom: var(--space-lg);
}

.formation-list-page__eyebrow {
  display: inline-block;
  font-size: var(--font-xs);
  font-weight: var(--weight-bold);
  letter-spacing: 0.08em;
  color: var(--color-primary);
  margin-bottom: var(--space-xs);
}

.formation-list-page__section-title {
  margin: 0;
  font-size: var(--font-xl);
  font-weight: var(--weight-semibold);
  letter-spacing: -0.01em;
}

.formation-list-page__selection-status {
  margin-top: var(--space-sm);
  font-size: var(--font-sm);
  color: var(--color-text-sub);
}

.formation-list-page__grid {
  display: grid;
  /* 画面幅に応じて列数が増減する可変グリッド（screen-design.md参照） */
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: var(--space-md);
}

.formation-list-page__footer {
  display: inline-block;
  margin-top: var(--space-lg);
  background: var(--color-primary-soft);
  border: 1px solid var(--color-border);
  color: var(--color-primary);
  font-size: var(--font-xs);
  padding: var(--space-sm) var(--space-md);
  border-radius: var(--radius-pill);
}

@media (max-width: 640px) {
  .formation-list-page__body {
    padding: var(--space-lg) var(--gutter-mobile);
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
