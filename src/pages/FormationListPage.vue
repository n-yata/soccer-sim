<template>
  <div class="formation-list-page">
    <PageHeader
      title="陣形の違いを、ピッチで見よう"
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
    <div ref="selectionRoot" class="formation-list-page__body">
      <div class="formation-list-page__section-intro">
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
          :data-formation-id="formation.id"
          @select="toggleSelection"
        />
      </div>
      <div class="formation-list-page__selection-tray" aria-label="比較対象の選択">
        <div>
          <strong>{{ selectedIds.length ? selectedNames : "まずは気になる陣形を選ぼう" }}</strong>
          <p>
            {{
              selectedIds.length
                ? "もう1つ選ぶと、ピッチと戦術解説を表示します"
                : "2つ選択すると自動的に比較画面へ進みます"
            }}
          </p>
        </div>
        <button
          v-if="selectedIds.length"
          type="button"
          class="formation-list-page__clear-selection"
          @click="clearSelection"
        >
          選択を解除
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from "vue";
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
const selectionRoot = ref<HTMLElement>();
async function clearSelection(): Promise<void> {
  const firstId = selectedIds.value[0];
  selectedIds.value = [];
  await nextTick();
  const cards = selectionRoot.value?.querySelectorAll<HTMLElement>(".formation-card");
  Array.from(cards ?? [])
    .find((card) => card.dataset.formationId === firstId)
    ?.focus();
}
const selectedNames = computed(() =>
  selectedIds.value
    .map((id) => formations.find((formation) => formation.id === id)?.name)
    .filter(Boolean)
    .join(" / "),
);
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
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: var(--space-md);
}

.formation-list-page__selection-tray {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: var(--space-sm);
  margin-top: var(--space-lg);
  background: var(--color-surface);
  border: 1px solid var(--color-primary);
  color: var(--color-primary);
  padding: var(--space-md) var(--space-lg);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
}

.formation-list-page__selection-tray p {
  font-size: var(--font-sm);
  color: var(--color-text-sub);
  margin-top: var(--space-xs);
}

.formation-list-page__clear-selection {
  min-height: 44px;
  padding: var(--space-sm) var(--space-md);
  border: 1px solid var(--color-border-strong);
  background: var(--color-surface);
  border-radius: var(--radius-md);
  cursor: pointer;
}

@media (max-width: 900px) {
  .formation-list-page__grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .formation-list-page__body {
    padding: var(--space-lg) var(--gutter-mobile);
  }

  .formation-list-page__grid {
    grid-template-columns: 1fr;
  }
}

@media (prefers-reduced-motion: reduce) {
  .formation-list-page__jleague-link {
    transition: none;
  }
}
</style>
