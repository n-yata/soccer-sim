<template>
  <div class="league-page">
    <div class="league-page__header">
      <BackButton fallback-to="/" />
      <h1 class="league-page__title">リーグ戦</h1>
    </div>

    <template v-if="league">
      <p class="league-page__subtitle">
        全{{ formations.length }}フォーメーションが総当たり1回戦（全{{
          league.matches.length
        }}試合）を戦った結果です
      </p>

      <div class="league-page__table-wrapper">
        <table class="league-page__table">
          <thead>
            <tr>
              <th scope="col">順位</th>
              <th scope="col">フォーメーション</th>
              <th scope="col">試合数</th>
              <th scope="col">勝</th>
              <th scope="col">分</th>
              <th scope="col">敗</th>
              <th scope="col">得点</th>
              <th scope="col">失点</th>
              <th scope="col">得失点差</th>
              <th scope="col">勝ち点</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="standing in league.standings" :key="standing.formationId">
              <td class="league-page__rank">{{ standing.rank }}</td>
              <td class="league-page__name">{{ standing.formationName }}</td>
              <td>{{ standing.played }}</td>
              <td>{{ standing.win }}</td>
              <td>{{ standing.draw }}</td>
              <td>{{ standing.lose }}</td>
              <td>{{ standing.goalsFor }}</td>
              <td>{{ standing.goalsAgainst }}</td>
              <td>{{ formatSigned(standing.goalDifference) }}</td>
              <td class="league-page__points">{{ standing.points }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <h2 class="league-page__matches-title">全対戦結果</h2>
      <ul class="league-page__matches">
        <li v-for="match in league.matches" :key="`${match.formationAId}_vs_${match.formationBId}`">
          <router-link
            :to="{
              name: 'comparison',
              params: { formationAId: match.formationAId, formationBId: match.formationBId },
            }"
            class="league-page__match-link"
          >
            <span>{{ match.formationAName }}</span>
            <span class="league-page__match-score">{{ match.scoreA }} - {{ match.scoreB }}</span>
            <span>{{ match.formationBName }}</span>
          </router-link>
        </li>
      </ul>
    </template>
    <template v-else>
      <p>リーグ戦を集計できませんでした</p>
      <router-link to="/"> 一覧画面へ戻る </router-link>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import BackButton from "@/components/BackButton.vue";
import { formations } from "@/data/formations";
import { getMatchup } from "@/data/matchups";
import { runLeagueSimulation } from "@/composables/leagueSimulation";
import type { LeagueSimulationResult } from "@/types/formation";

// formationsは静的データで実行中に変化しないため、リーグ戦の結果は1回計算すれば十分
// （MatrixPage.vueのprogress同様、マウント時に確定させてよい。computed自体は遅延評価だが、
// 依存するformations/getMatchupが変化しないため実質的に一度しか再計算されない）
//
// runLeagueSimulationはマッチアップ欠落（データ不整合）時にErrorを投げる設計のため、
// ここでcatchしてnullへ倒す。ComparisonPage.vue/MatrixPage.vueが不整合を「劣化表示」で
// 受ける既存方針と揃えるため（キャッチしないとレンダー中の例外がアプリ全体を落とす）
const league = computed<LeagueSimulationResult | null>(() => {
  try {
    return runLeagueSimulation(formations, getMatchup);
  } catch {
    return null;
  }
});

function formatSigned(value: number): string {
  return value > 0 ? `+${value}` : `${value}`;
}
</script>

<style scoped>
.league-page {
  padding: var(--space-lg) var(--space-2xl) var(--space-2xl);
}

.league-page__header {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  margin-bottom: var(--space-sm);
}

.league-page__title {
  margin: 0;
  font-size: var(--font-xl);
  font-weight: 700;
  color: var(--color-text);
}

.league-page__subtitle {
  margin: 0 0 var(--space-md);
  font-size: var(--font-sm);
  color: var(--color-text-sub);
}

.league-page__table-wrapper {
  overflow-x: auto;
  margin-bottom: var(--space-xl);
}

.league-page__table {
  border-collapse: collapse;
  width: 100%;
  min-width: 640px;
}

.league-page__table th,
.league-page__table td {
  border-bottom: 1px solid var(--color-border);
  padding: 8px 12px;
  font-size: 13px;
  text-align: center;
  white-space: nowrap;
}

.league-page__table th {
  font-weight: 700;
  color: var(--color-text);
}

.league-page__name {
  text-align: left;
  font-weight: 700;
  color: var(--color-text);
}

.league-page__rank {
  font-weight: 700;
  color: var(--color-primary);
}

.league-page__points {
  font-weight: 700;
}

.league-page__matches-title {
  margin: 0 0 var(--space-sm);
  font-size: var(--font-lg);
  font-weight: 700;
  color: var(--color-text);
}

.league-page__matches {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: var(--space-sm);
}

.league-page__match-link {
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

.league-page__match-link:hover {
  background: var(--color-surface-hover);
}

.league-page__match-link:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

.league-page__match-score {
  color: var(--color-text-sub);
}

@media (max-width: 640px) {
  .league-page {
    padding: var(--space-md) var(--space-md) var(--space-xl);
  }

  .league-page__match-link {
    flex-wrap: wrap;
    gap: var(--space-xs) var(--space-md);
  }
}

@media (max-width: 480px) {
  .league-page__header {
    flex-wrap: wrap;
  }

  .league-page__title {
    font-size: var(--font-lg);
  }
}

@media (prefers-reduced-motion: reduce) {
  .league-page__match-link {
    transition: none;
  }
}
</style>
