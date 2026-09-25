<template>
  <div class="formation-list-page">
    <header class="formation-list-page__header">
      <div class="formation-list-page__header-row">
        <div>
          <h1 class="formation-list-page__title">⚽ フォーメーションラボ</h1>
          <p class="formation-list-page__subtitle">比較したいフォーメーションを2つ選んでください</p>
        </div>
        <div class="formation-list-page__header-actions">
          <button type="button" class="formation-list-page__matrix-button" @click="goToMatrix">
            相性表を見る
          </button>
          <router-link to="/league" class="formation-list-page__league-link">
            🏆 リーグ戦
          </router-link>
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
        </div>
      </div>
    </header>
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
import { formations } from "@/data/formations";

const router = useRouter();
const selectedIds = ref<string[]>([]);

// カップ戦（composables/cupSimulation.ts）は8フォーメーション固定のノックアウト方式
// のみに対応する。データ追加でformationsが8件以外になった場合、導線を出したままだと
// 必ずエラー表示になる画面へ誘導してしまうため出し分ける
const CUP_REQUIRED_FORMATION_COUNT = 8;

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
.formation-list-page__header {
  background: linear-gradient(90deg, var(--color-primary), var(--color-primary-end));
  padding: 32px 40px;
  color: #ffffff;
}

.formation-list-page__header-row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.formation-list-page__title {
  margin: 0;
  font-size: 28px;
  font-weight: 700;
}

.formation-list-page__header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.formation-list-page__matrix-button {
  /* 半透明の白オーバーレイでは、緑背景に対し白文字がAA(4.5:1)未達になるため、
     既存の戻るボタン等と同じ「不透明な白背景+濃色テキスト」に統一する */
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: #ffffff;
  box-shadow: var(--shadow-card);
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 700;
  color: #374151;
  cursor: pointer;
}

.formation-list-page__matrix-button:hover {
  background: #f3f4f6;
}

.formation-list-page__subtitle {
  margin: 8px 0 0;
  font-size: 13px;
  font-weight: 600;
  color: #ffffff;
  /* text-shadowはWCAGのコントラスト比計算に算入されない。AA(4.5:1、13px)を
     満たすため、白文字と組み合わせて--color-primary/--color-primary-end自体を
     暗めの値に調整済み（tokens.css）。text-shadowは可読性の補助のみ */
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.35);
}

.formation-list-page__league-link,
.formation-list-page__cup-link,
.formation-list-page__glossary-link,
.formation-list-page__quiz-link {
  display: inline-block;
  border: 1px solid rgba(255, 255, 255, 0.6);
  border-radius: 999px;
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 700;
  color: #ffffff;
  white-space: nowrap;
}

.formation-list-page__body {
  padding: 32px 40px;
}

.formation-list-page__grid {
  display: grid;
  /* 最大3列の可変グリッド（狭幅画面では自動的に列数が減る。screen-design.md参照） */
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 16px;
  max-width: 640px;
}

.formation-list-page__footer {
  display: inline-block;
  margin-top: 20px;
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
  color: #166534;
  font-size: 12px;
  font-style: italic;
  padding: 8px 16px;
  border-radius: 999px;
}
</style>
