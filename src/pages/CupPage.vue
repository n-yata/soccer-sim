<template>
  <div class="cup-page">
    <div class="cup-page__header">
      <BackButton class="cup-page__back-button" fallback-to="/" />
      <h1 class="cup-page__title">カップ戦</h1>
    </div>

    <template v-if="cup">
      <p class="cup-page__subtitle">
        全{{ formations.length }}フォーメーションによる一発勝負のノックアウト方式です
      </p>

      <p class="cup-page__champion">🏆 優勝: {{ cup.championName }}</p>

      <section v-for="round in rounds" :key="round.title" class="cup-page__round">
        <h2 class="cup-page__round-title">{{ round.title }}</h2>
        <ul class="cup-page__matches">
          <li
            v-for="match in round.matches"
            :key="`${match.formationAId}_vs_${match.formationBId}`"
          >
            <router-link
              :to="{
                name: 'comparison',
                params: { formationAId: match.formationAId, formationBId: match.formationBId },
              }"
              class="cup-page__match-link"
              :class="{ 'cup-page__match-link--penalties': match.wentToPenalties }"
            >
              <span :class="{ 'cup-page__winner': match.winnerId === match.formationAId }">
                <span v-if="match.winnerId === match.formationAId" aria-hidden="true">🏆 </span>
                {{ match.formationAName }}
                <span v-if="match.winnerId === match.formationAId" class="cup-page__sr-only"
                  >（勝者）</span
                >
              </span>
              <span class="cup-page__match-score">
                {{ match.scoreA }} - {{ match.scoreB }}
                <template v-if="match.wentToPenalties">
                  (PK {{ match.penaltyScoreA }}-{{ match.penaltyScoreB }})
                </template>
              </span>
              <span :class="{ 'cup-page__winner': match.winnerId === match.formationBId }">
                <span v-if="match.winnerId === match.formationBId" aria-hidden="true">🏆 </span>
                {{ match.formationBName }}
                <span v-if="match.winnerId === match.formationBId" class="cup-page__sr-only"
                  >（勝者）</span
                >
              </span>
            </router-link>
          </li>
        </ul>
      </section>
    </template>
    <template v-else>
      <p>カップ戦を集計できませんでした</p>
      <router-link to="/"> 一覧画面へ戻る </router-link>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import BackButton from "@/components/BackButton.vue";
import { formations } from "@/data/formations";
import { getMatchup } from "@/data/matchups";
import { runCupSimulation } from "@/composables/cupSimulation";
import type { CupMatch, CupSimulationResult } from "@/types/formation";

// formationsは静的データで実行中に変化しないため、カップ戦の結果は1回計算すれば十分
// （LeaguePage.vueのleagueと同じ方針）。
//
// runCupSimulationは8件以外・マッチアップ欠落（データ不整合）時にErrorを投げる設計のため、
// ここでcatchしてnullへ倒す（LeaguePage.vue/ComparisonPage.vueと同じ「劣化表示」方針）
const cup = computed<CupSimulationResult | null>(() => {
  try {
    return runCupSimulation(formations, getMatchup);
  } catch (error) {
    // formations.length !== 8（要件変更・データ追加）とマッチアップ欠落（データ不整合）の
    // いずれも「カップ戦を集計できませんでした」の劣化表示に丸めるが、原因調査の手がかりが
    // 消えないようコンソールには残す
    console.error("カップ戦の集計に失敗しました", error);
    return null;
  }
});

const rounds = computed<{ title: string; matches: CupMatch[] }[]>(() => {
  if (!cup.value) return [];
  return [
    { title: "準々決勝", matches: cup.value.quarterfinals },
    { title: "準決勝", matches: cup.value.semifinals },
    { title: "決勝", matches: [cup.value.final] },
  ];
});
</script>

<style scoped>
.cup-page {
  padding: var(--space-lg) var(--space-2xl) var(--space-2xl);
}

.cup-page__header {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  margin-bottom: var(--space-sm);
}

.cup-page__title {
  margin: 0;
  font-size: var(--font-xl);
  font-weight: 700;
  color: var(--color-text);
}

.cup-page__subtitle {
  margin: 0 0 var(--space-sm);
  font-size: var(--font-sm);
  color: var(--color-text-sub);
}

.cup-page__champion {
  margin: 0 0 var(--space-lg);
  font-size: var(--font-lg);
  font-weight: 700;
  color: var(--color-primary);
}

.cup-page__round {
  margin-bottom: var(--space-lg);
}

.cup-page__round-title {
  margin: 0 0 var(--space-sm);
  font-size: 16px;
  font-weight: 700;
  color: var(--color-text);
}

.cup-page__matches {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: var(--space-sm);
}

.cup-page__match-link {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-md);
  min-height: 44px;
  box-sizing: border-box;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  background: var(--color-surface);
  box-shadow: var(--shadow-card);
  padding: 10px 16px;
  font-size: var(--font-sm);
  font-weight: 700;
  color: var(--color-text);
  text-decoration: none;
  transition: background-color 0.15s ease;
}

.cup-page__match-link:hover {
  background: var(--color-surface-hover);
}

.cup-page__match-link:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

.cup-page__match-link--penalties {
  border-style: dashed;
}

.cup-page__match-score {
  color: var(--color-text-sub);
  white-space: nowrap;
}

.cup-page__winner {
  /* 色のみに依存しないよう（WCAG 1.4.1）、太字化とアイコンを併用する。
     アイコンはCSS生成コンテンツ(::before)にすると読み上げがAT依存で揺れるため、
     マークアップ側にaria-hidden付きの絵文字＋視覚的に隠したテキストを置く
     （quiz画面の正誤マーカーと同じパターン） */
  color: var(--color-primary);
  font-weight: 700;
}

.cup-page__sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  margin: -1px;
  border: 0;
  padding: 0;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
}

@media (max-width: 640px) {
  .cup-page {
    padding: var(--space-md) var(--space-md) var(--space-xl);
  }

  .cup-page__match-link {
    flex-wrap: wrap;
    gap: var(--space-xs) var(--space-md);
  }
}

@media (max-width: 480px) {
  .cup-page__header {
    flex-wrap: wrap;
  }

  .cup-page__title {
    font-size: var(--font-lg);
  }
}

@media (prefers-reduced-motion: reduce) {
  .cup-page__match-link {
    transition: none;
  }
}
</style>
