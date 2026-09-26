<template>
  <div class="comparison-page">
    <template v-if="formationA && formationB && matchup">
      <div class="comparison-page__header">
        <BackButton fallback-to="/" />
        <h1 class="comparison-page__title">{{ formationA.name }} vs {{ formationB.name }}</h1>
        <router-link to="/glossary" class="comparison-page__glossary-link"> 📖 用語集 </router-link>
      </div>
      <div class="comparison-page__legend">
        <span class="comparison-page__legend-item comparison-page__legend-item--blue">
          {{ formationA.name }}
        </span>
        <span class="comparison-page__legend-item comparison-page__legend-item--red">
          {{ formationB.name }}
        </span>
      </div>
      <ComparisonControls
        :formations="formations"
        :formation-a-id="formationA.id"
        :formation-b-id="formationB.id"
        @swap="swap"
        @select-a="onSelectA"
        @select-b="onSelectB"
      />
      <FreeLayoutControls
        :is-active="isFreeLayoutMode"
        @toggle="toggleFreeLayoutMode"
        @reset="resetFreeLayout"
      />
      <SquadConditionControls
        :is-active="squadConditionSeed !== null"
        @toggle="toggleSquadCondition"
        @reroll="rerollSquadCondition"
      />
      <p
        class="comparison-page__verdict"
        :class="`comparison-page__verdict--${matchup.overallEdge}`"
      >
        {{ verdictHeadline }}<br />
        <span class="comparison-page__verdict-reason">
          <TermAnnotatedText :text="matchup.overallReason" />
        </span>
      </p>
      <div class="comparison-page__main">
        <div class="comparison-page__pitch-overlay">
          <FreeLayoutPitchDiagram
            v-if="isFreeLayoutMode && effectiveFormationA"
            :formation-a="effectiveFormationA"
            :formation-b="formationB"
            @update-position="onUpdatePosition"
          />
          <MatchupPitchDiagram
            v-else
            :key="`${formationA.id}-${formationB.id}`"
            :formation-a="formationA"
            :formation-b="formationB"
          />
        </div>
        <div class="comparison-page__radar">
          <h2 class="comparison-page__radar-title">フォーメーション特性</h2>
          <RadarChart :axes="radarAxes" :max-value="100" :series="radarSeries" />
        </div>
      </div>
      <div class="comparison-page__advantages">
        <div class="comparison-page__advantage-column comparison-page__advantage-column--blue">
          <h2 class="comparison-page__label comparison-page__label--blue">
            {{ formationA.name }}の優位ポイント
          </h2>
          <ul>
            <li v-for="(point, index) in matchup.advantagesForA" :key="index">
              <TermAnnotatedText :text="point" />
            </li>
          </ul>
        </div>
        <div class="comparison-page__advantage-column comparison-page__advantage-column--red">
          <h2 class="comparison-page__label comparison-page__label--red">
            {{ formationB.name }}の優位ポイント
          </h2>
          <ul>
            <li v-for="(point, index) in matchup.advantagesForB" :key="index">
              <TermAnnotatedText :text="point" />
            </li>
          </ul>
        </div>
      </div>

      <div class="comparison-page__simulation">
        <button
          v-if="!simulationResult"
          type="button"
          class="comparison-page__simulate-button"
          @click="runSimulation"
        >
          ⚽ 試合をシミュレートする
        </button>
        <MatchSimulationPanel
          v-if="simulationResult"
          :result="simulationResult"
          :formation-a-name="formationA.name"
          :formation-b-name="formationB.name"
        />
      </div>
    </template>
    <template v-else>
      <p>指定された組み合わせを表示できません</p>
      <router-link to="/"> 一覧画面へ戻る </router-link>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import BackButton from "@/components/BackButton.vue";
import ComparisonControls from "@/components/ComparisonControls.vue";
import FreeLayoutControls from "@/components/FreeLayoutControls.vue";
import FreeLayoutPitchDiagram from "@/components/FreeLayoutPitchDiagram.vue";
import MatchSimulationPanel from "@/components/MatchSimulationPanel.vue";
import MatchupPitchDiagram from "@/components/MatchupPitchDiagram.vue";
import RadarChart from "@/components/RadarChart.vue";
import SquadConditionControls from "@/components/SquadConditionControls.vue";
import TermAnnotatedText from "@/components/TermAnnotatedText.vue";
import { simulateMatch } from "@/composables/matchSimulation";
import { applySquadVariance } from "@/composables/squadCondition";
import { formations, getFormationById } from "@/data/formations";
import { getMatchup } from "@/data/matchups";
import { generateMatchup } from "@/data/matchupGenerator";
import { getTags } from "@/data/formationTags";
import { estimateStats } from "@/data/radarScoreEstimator";
import { markPairViewed } from "@/data/learningProgress";
import { radarAxes } from "@/data/radarAxes";
import type { MatchSimulationResult, Position } from "@/types/formation";

const route = useRoute();
const router = useRouter();

const formationA = computed(() => getFormationById(route.params.formationAId as string));
const formationB = computed(() => getFormationById(route.params.formationBId as string));

// 自由配置モード: Aチームのみドラッグで配置を変更できる一時状態。永続化しない
// （組み合わせ切替・トグルOFF・画面離脱でリセットする）
const isFreeLayoutMode = ref(false);
const freePositionsA = ref<Position[] | null>(null);

function clonePositions(positions: Position[]): Position[] {
  return positions.map((position) => ({ ...position }));
}

function toggleFreeLayoutMode(): void {
  if (isFreeLayoutMode.value) {
    isFreeLayoutMode.value = false;
    freePositionsA.value = null;
    return;
  }
  if (!formationA.value) return;
  isFreeLayoutMode.value = true;
  freePositionsA.value = clonePositions(formationA.value.positions);
  // 自由配置モードに入る前のformationA.statsで計算された試合シミュレーション結果は、
  // これから変更されうるAチームの表示（タグ・優位ポイント・レーダー）と食い違うため破棄する
  simulationResult.value = null;
}

function resetFreeLayout(): void {
  if (!formationA.value) return;
  freePositionsA.value = clonePositions(formationA.value.positions);
}

function onUpdatePosition(positionId: string, x: number, y: number): void {
  if (!freePositionsA.value) return;
  freePositionsA.value = freePositionsA.value.map((position) =>
    position.id === positionId ? { ...position, x, y } : position,
  );
  // 配置を動かした時点で、表示中のシミュレーション結果は古いAチームの配置に基づくため破棄する
  simulationResult.value = null;
}

// 自由配置モード中はfreePositionsAを反映したFormationを、そうでなければ静的なformationAを
// そのまま使う。matchup/レーダースコアの算出はこちらを入力にする
const effectiveFormationA = computed(() => {
  if (!formationA.value) return undefined;
  if (!freePositionsA.value) return formationA.value;
  return { ...formationA.value, positions: freePositionsA.value };
});

// 自由配置モードでない限り既存のgetMatchup（静的キャッシュのIDルックアップ）を使う。
// 自由配置モード中のみ、変更後の配置でgenerateMatchupを都度呼び直す
const matchup = computed(() => {
  if (!effectiveFormationA.value || !formationB.value) return undefined;
  if (!freePositionsA.value) return getMatchup(effectiveFormationA.value.id, formationB.value.id);
  return generateMatchup(effectiveFormationA.value, formationB.value);
});

// 自由配置モード中のAチームのレーダースコア概算。タグ構成の差分から元のstatsを基準に算出する
const effectiveStatsA = computed(() => {
  if (!formationA.value) return undefined;
  if (!effectiveFormationA.value || !freePositionsA.value) return formationA.value.stats;
  return estimateStats(
    getTags(effectiveFormationA.value),
    getTags(formationA.value),
    formationA.value.stats,
  );
});

// FR-14: 試合シミュレーション結果。ボタン押下時にのみ計算する（表示するまで90分ループを
// 走らせる必要が無いため）。フォーメーションの組み合わせが変わったら古い結果を残さない
const simulationResult = ref<MatchSimulationResult | null>(null);

// 選手個体差（スカッドコンディション）: nullは無効を表す。有効時のみsimulateMatchに渡す
// 実効statsの算出に使う。永続化せず、レーダーチャート・優位ポイントには一切影響させない
// （design.md「実装対象の機能」参照）。シードの「引き方」はUIの関心事、「シードから
// 実効statsを作る」のはcomposables/squadCondition.tsの関心事、という責務分離を保つ
const squadConditionSeed = ref<number | null>(null);

function generateSeed(): number {
  return Math.floor(Math.random() * 0xffffffff);
}

function toggleSquadCondition(): void {
  squadConditionSeed.value = squadConditionSeed.value === null ? generateSeed() : null;
  // 古いスカッド条件に基づく結果を残さない
  simulationResult.value = null;
}

function rerollSquadCondition(): void {
  if (squadConditionSeed.value === null) return;
  squadConditionSeed.value = generateSeed();
  simulationResult.value = null;
}

function runSimulation(): void {
  if (!formationA.value || !formationB.value || !matchup.value) return;
  if (squadConditionSeed.value === null) {
    simulationResult.value = simulateMatch(formationA.value, formationB.value, matchup.value);
    return;
  }
  // A/Bで異なる乱数列にするため、Bのシードは+1でオフセットする
  const squadA = {
    ...formationA.value,
    stats: applySquadVariance(formationA.value.stats, squadConditionSeed.value),
  };
  const squadB = {
    ...formationB.value,
    stats: applySquadVariance(formationB.value.stats, squadConditionSeed.value + 1),
  };
  simulationResult.value = simulateMatch(squadA, squadB, matchup.value);
}

watch(
  () => [formationA.value?.id, formationB.value?.id] as const,
  () => {
    simulationResult.value = null;
    // 組み合わせが変わったら自由配置モード・選手個体差の一時状態も破棄する（永続化しない要件）
    isFreeLayoutMode.value = false;
    freePositionsA.value = null;
    squadConditionSeed.value = null;
  },
);

// 総合判定の見出し。「どちらが有利か」を一目で示す（優位ポイントの箇条書きだけでは
// 結局どちらが有利なのか読み取りにくいというフィードバックを受けて追加）
const verdictHeadline = computed(() => {
  if (!matchup.value || !formationA.value || !formationB.value) return "";
  if (matchup.value.overallEdge === "even") return "互角";
  const winner = matchup.value.overallEdge === "A" ? formationA.value.name : formationB.value.name;
  return `${winner}がやや優位`;
});

// レーダーチャート用の系列データ。formationA/Bが両方揃っている（v-ifの範囲内）ことを
// 前提に、未定義の場合は空配列でチャート側に何も渡さない
const radarSeries = computed(() => {
  if (!formationA.value || !formationB.value || !effectiveStatsA.value) return [];
  return [
    { label: formationA.value.name, colorVar: "--color-team-a", values: effectiveStatsA.value },
    { label: formationB.value.name, colorVar: "--color-team-b", values: formationB.value.stats },
  ];
});

// FR-13: 表示できた組み合わせを「確認済み」として記録する。
// A/B入れ替え・切替（FR-09）は router.replace による同一コンポーネント内の
// パラメータ変更なので、onMounted だと初回しか記録されない。watch + immediate で拾う。
// 組み合わせが解決できなかった場合（存在しないID・マッチアップ未定義）は
// 学習として成立していないため記録しない
// 監視対象はIDの組。matchup オブジェクトを直接見ると、getMatchup が呼び出し順に応じて
// 新しいオブジェクトを返す仕様のため、同じ組み合わせでも参照差で発火しうる
watch(
  () => [formationA.value?.id, formationB.value?.id, matchup.value !== undefined] as const,
  ([idA, idB, hasMatchup]) => {
    if (!idA || !idB || !hasMatchup) return;
    markPairViewed(idA, idB);
  },
  { immediate: true },
);

// 比較画面から比較画面への移動は「同じ画面の表示内容を変える」操作のため、
// pushではなくreplaceを使う。pushにすると、履歴に比較画面が積み重なり、
// ブラウザバックで一覧画面へ戻るまでに何度も比較画面を経由することになる
function swap(): void {
  if (!formationA.value || !formationB.value) return;
  router.replace(`/compare/${formationB.value.id}/${formationA.value.id}`);
}

function onSelectA(id: string): void {
  if (!formationB.value) return;
  router.replace(`/compare/${id}/${formationB.value.id}`);
}

function onSelectB(id: string): void {
  if (!formationA.value) return;
  router.replace(`/compare/${formationA.value.id}/${id}`);
}
</script>

<style scoped>
.comparison-page {
  padding: var(--space-lg) var(--space-2xl) var(--space-2xl);
}

.comparison-page__header {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  margin-bottom: var(--space-md);
  flex-wrap: wrap;
}

.comparison-page__title {
  margin: 0;
  font-size: var(--font-xl);
  font-weight: 700;
  color: var(--color-text);
}

.comparison-page__glossary-link {
  margin-left: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);
  background: var(--color-surface);
  box-shadow: var(--shadow-card);
  padding: var(--space-sm) var(--space-md);
  font-size: var(--font-sm);
  font-weight: 700;
  color: var(--color-text-muted);
  white-space: nowrap;
}

.comparison-page__legend {
  display: flex;
  gap: var(--space-sm);
  margin-bottom: var(--space-md);
  font-weight: bold;
}

.comparison-page__legend-item {
  border-radius: var(--radius-pill);
  padding: 6px 14px;
  font-size: var(--font-sm);
}

.comparison-page__legend-item::before {
  content: "●";
  margin-right: 4px;
}

.comparison-page__legend-item--blue {
  color: #1d4ed8;
  background: var(--color-team-a-bg);
  border: 1px solid var(--color-team-a);
}

.comparison-page__legend-item--red {
  color: #b91c1c;
  background: var(--color-team-b-bg);
  border: 1px solid var(--color-team-b);
}

.comparison-page__verdict {
  margin: 0 0 16px;
  padding: 12px 16px;
  border-radius: 8px;
  font-weight: bold;
  box-shadow: var(--shadow-card);
  background: var(--color-surface-sub);
  border: 2px solid var(--color-border-strong);
  animation: comparison-verdict-pop-in 0.5s ease-out both;
  animation-delay: 0.7s;
}

@keyframes comparison-verdict-pop-in {
  0% {
    transform: scale(0.6);
    opacity: 0;
  }
  70% {
    transform: scale(1.08);
    opacity: 1;
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}

.comparison-page__verdict--A {
  background: var(--color-team-a-bg);
  border-color: var(--color-team-a);
  color: #1e3a5f;
}

.comparison-page__verdict--A::before,
.comparison-page__verdict--B::before {
  content: "🏆 ";
}

.comparison-page__verdict--B {
  background: var(--color-team-b-bg);
  border-color: var(--color-team-b);
  color: #5f1e1e;
}

.comparison-page__verdict--even {
  background: var(--color-surface-sub);
  border-color: var(--color-border-strong);
}

.comparison-page__verdict--even::before {
  content: "⚖️ ";
}

.comparison-page__verdict-reason {
  display: block;
  font-weight: normal;
  font-size: 0.9em;
  color: #444444;
  margin-top: 4px;
}

.comparison-page__main {
  display: flex;
  align-items: flex-start;
  gap: var(--space-lg);
  flex-wrap: wrap;
}

.comparison-page__pitch-overlay {
  position: relative;
  flex: 2 1 520px;
  max-width: 800px;
  border-radius: var(--radius-sm);
  overflow: hidden;
  box-shadow: var(--shadow-card);
}

@media (prefers-reduced-motion: reduce) {
  .comparison-page__verdict {
    animation: none;
  }
}

.comparison-page__radar {
  flex: 1 1 320px;
  max-width: 360px;
  background: var(--color-surface);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-card);
  border: 1px solid var(--color-border);
  padding: var(--space-md) var(--space-lg);
}

.comparison-page__radar-title {
  margin: 0 0 var(--space-sm);
  font-size: var(--font-md);
  font-weight: 700;
  color: var(--color-text);
}

.comparison-page__advantages {
  display: flex;
  gap: var(--space-lg);
  margin-top: var(--space-lg);
  flex-wrap: wrap;
}

.comparison-page__advantage-column {
  flex: 1 1 260px;
  background: var(--color-surface);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-card);
  padding: var(--space-md) var(--space-lg);
  border: 2px solid var(--color-border);
}

.comparison-page__advantage-column--blue {
  border-color: var(--color-team-a);
}

.comparison-page__advantage-column--red {
  border-color: var(--color-team-b);
}

.comparison-page__label--blue {
  color: var(--color-team-a);
}

.comparison-page__label--red {
  color: var(--color-team-b);
}

.comparison-page__simulation {
  margin-top: 24px;
  text-align: center;
}

.comparison-page__simulate-button {
  border: none;
  border-radius: var(--radius-pill);
  background: linear-gradient(135deg, var(--color-primary), var(--color-primary-end));
  box-shadow: var(--shadow-card);
  padding: 12px 28px;
  font-size: var(--font-md);
  font-weight: 700;
  color: #ffffff;
  cursor: pointer;
}

.comparison-page__simulate-button:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

@media (max-width: 640px) {
  .comparison-page {
    padding: var(--space-md) var(--space-md) var(--space-xl);
  }

  .comparison-page__pitch-overlay {
    max-width: 100%;
  }

  .comparison-page__glossary-link {
    margin-left: 0;
  }
}
</style>
