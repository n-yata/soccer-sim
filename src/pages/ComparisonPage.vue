<template>
  <div class="comparison-page">
    <template v-if="formationA && formationB && matchup">
      <div class="comparison-page__header">
        <button type="button" class="comparison-page__back-button" @click="goBack">← 戻る</button>
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
          <MatchupPitchDiagram
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
import ComparisonControls from "@/components/ComparisonControls.vue";
import MatchSimulationPanel from "@/components/MatchSimulationPanel.vue";
import MatchupPitchDiagram from "@/components/MatchupPitchDiagram.vue";
import RadarChart from "@/components/RadarChart.vue";
import TermAnnotatedText from "@/components/TermAnnotatedText.vue";
import { simulateMatch } from "@/composables/matchSimulation";
import { formations, getFormationById } from "@/data/formations";
import { getMatchup } from "@/data/matchups";
import { markPairViewed } from "@/data/learningProgress";
import { radarAxes } from "@/data/radarAxes";
import type { MatchSimulationResult } from "@/types/formation";

const route = useRoute();
const router = useRouter();

const formationA = computed(() => getFormationById(route.params.formationAId as string));
const formationB = computed(() => getFormationById(route.params.formationBId as string));
const matchup = computed(() => {
  if (!formationA.value || !formationB.value) return undefined;
  return getMatchup(formationA.value.id, formationB.value.id);
});

// FR-14: 試合シミュレーション結果。ボタン押下時にのみ計算する（表示するまで90分ループを
// 走らせる必要が無いため）。フォーメーションの組み合わせが変わったら古い結果を残さない
const simulationResult = ref<MatchSimulationResult | null>(null);

function runSimulation(): void {
  if (!formationA.value || !formationB.value || !matchup.value) return;
  simulationResult.value = simulateMatch(formationA.value, formationB.value, matchup.value);
}

watch(
  () => [formationA.value?.id, formationB.value?.id] as const,
  () => {
    simulationResult.value = null;
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
  if (!formationA.value || !formationB.value) return [];
  return [
    { label: formationA.value.name, colorVar: "--color-team-a", values: formationA.value.stats },
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

// vue-routerのhistoryモードはhistory.stateに前後のルートパスを持つため、
// アプリ内遷移の履歴があるときだけrouter.back()で遷移元（一覧画面/マトリクス画面の
// どちらか実際にいた方）へ戻す。履歴が無い（URL直打ち等）場合のみ一覧画面へ固定する
function goBack(): void {
  if (window.history.state?.back) {
    router.back();
  } else {
    router.push("/");
  }
}

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
  padding: 24px 40px 40px;
}

.comparison-page__header {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 16px;
}

.comparison-page__back-button {
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

.comparison-page__title {
  margin: 0;
  font-size: 24px;
  font-weight: 700;
  color: var(--color-text);
}

.comparison-page__glossary-link {
  margin-left: auto;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: #ffffff;
  box-shadow: var(--shadow-card);
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 700;
  color: #374151;
  white-space: nowrap;
}

.comparison-page__legend {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
  font-weight: bold;
}

.comparison-page__legend-item {
  border-radius: 999px;
  padding: 6px 14px;
  font-size: 13px;
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
  background: #f9fafb;
  border: 2px solid #9ca3af;
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
  background: #f9fafb;
  border-color: #9ca3af;
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
  gap: 24px;
  flex-wrap: wrap;
}

.comparison-page__pitch-overlay {
  position: relative;
  flex: 2 1 520px;
  max-width: 800px;
  border-radius: 8px;
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
  background: #ffffff;
  border-radius: 10px;
  box-shadow: var(--shadow-card);
  border: 1px solid var(--color-border);
  padding: 16px 20px;
}

.comparison-page__radar-title {
  margin: 0 0 8px;
  font-size: 15px;
  font-weight: 700;
  color: var(--color-text);
}

.comparison-page__advantages {
  display: flex;
  gap: 24px;
  margin-top: 24px;
}

.comparison-page__advantage-column {
  flex: 1;
  background: #ffffff;
  border-radius: 10px;
  box-shadow: var(--shadow-card);
  padding: 16px 20px;
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
  border-radius: 999px;
  background: linear-gradient(135deg, var(--color-primary), var(--color-primary-end));
  box-shadow: var(--shadow-card);
  padding: 12px 28px;
  font-size: 15px;
  font-weight: 700;
  color: #ffffff;
  cursor: pointer;
}

.comparison-page__simulate-button:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}
</style>
