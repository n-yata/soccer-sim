<template>
  <div class="comparison-page">
    <template v-if="formationA && formationB && matchup">
      <PageHeader
        show-back-button
        :title="`${formationA.name} vs ${formationB.name}`"
        subtitle="結論から配置と理由へ。2つの陣形の噛み合わせを読み解く"
      />
      <div class="comparison-page__body">
        <p
          class="comparison-page__verdict"
          :class="`comparison-page__verdict--${matchup.overallEdge}`"
        >
          <AppIcon :icon="verdictIcon" size="lg" class="comparison-page__verdict-icon" />
          {{ verdictHeadline }}<br />
          <span class="comparison-page__verdict-reason">
            <TermAnnotatedText :text="matchup.overallReason" />
          </span>
        </p>
        <div class="comparison-page__legend">
          <span class="comparison-page__legend-item comparison-page__legend-item--blue">
            A：{{ formationA.name }}
          </span>
          <span class="comparison-page__legend-item comparison-page__legend-item--red">
            B：{{ formationB.name }}
          </span>
        </div>
        <div class="comparison-page__main">
          <div class="comparison-page__pitch-overlay">
            <h2 class="comparison-page__section-heading">ピッチで配置を読む</h2>
            <p class="comparison-page__section-description">
              青がA、赤がB。選手の位置と間のスペースを見比べます。
            </p>
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

        <section class="comparison-page__explore" aria-labelledby="comparison-explore-title">
          <h2 id="comparison-explore-title" class="comparison-page__section-heading">
            別の組み合わせで比べる
          </h2>
          <p class="comparison-page__section-description">
            比較する陣形を切り替えたり、青と赤を入れ替えたりできます。
          </p>
          <ComparisonControls
            :formations="formations"
            :formation-a-id="formationA.id"
            :formation-b-id="formationB.id"
            @swap="swap"
            @select-a="onSelectA"
            @select-b="onSelectB"
          />
        </section>
      </div>
    </template>
    <template v-else>
      <div class="comparison-page__error">
        <p>指定された組み合わせを表示できません</p>
        <router-link to="/"> 一覧画面へ戻る </router-link>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { Scale, Trophy } from "@lucide/vue";
import AppIcon from "@/components/AppIcon.vue";
import ComparisonControls from "@/components/ComparisonControls.vue";
import MatchupPitchDiagram from "@/components/MatchupPitchDiagram.vue";
import PageHeader from "@/components/PageHeader.vue";
import RadarChart from "@/components/RadarChart.vue";
import TermAnnotatedText from "@/components/TermAnnotatedText.vue";
import { formations, getFormationById } from "@/data/formations";
import { getMatchup } from "@/data/matchups";
import { markPairViewed } from "@/data/learningProgress";
import { radarAxes } from "@/data/radarAxes";
const route = useRoute();
const router = useRouter();
const formationA = computed(() => getFormationById(route.params.formationAId as string));
const formationB = computed(() => getFormationById(route.params.formationBId as string));
const matchup = computed(() => {
  if (!formationA.value || !formationB.value) return undefined;
  return getMatchup(formationA.value.id, formationB.value.id);
});

// 総合判定の見出し。「どちらが有利か」を一目で示す（優位ポイントの箇条書きだけでは
// 結局どちらが有利なのか読み取りにくいというフィードバックを受けて追加）
const verdictHeadline = computed(() => {
  if (!matchup.value || !formationA.value || !formationB.value) return "";
  if (matchup.value.overallEdge === "even") return "互角";
  const winner = matchup.value.overallEdge === "A" ? formationA.value.name : formationB.value.name;
  return `${winner}がやや優位`;
});

// overallEdgeが"A"/"B"のときのみ優勝トロフィーを表示する（"even"は互角、それ以外は
// 未確定を意味しうるため、両方ともScaleにフォールバックする方が意図に忠実）
const verdictIcon = computed(() => {
  const edge = matchup.value?.overallEdge;
  return edge === "A" || edge === "B" ? Trophy : Scale;
});

// レーダーチャート用の系列データ。formationA/Bが両方揃っている（v-ifの範囲内）ことを
// 前提に、未定義の場合は空配列でチャート側に何も渡さない
const radarSeries = computed(() => {
  if (!formationA.value || !formationB.value) {
    return [];
  }
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
.comparison-page__body {
  padding: var(--space-lg) var(--gutter) var(--gutter);
  max-width: var(--width-wide);
  margin: 0 auto;
}

.comparison-page__error {
  padding: var(--space-lg) var(--gutter) var(--gutter);
  max-width: var(--width-wide);
  margin: 0 auto;
}

.comparison-page__explore {
  margin-top: var(--space-2xl);
  padding-top: var(--space-lg);
  border-top: 1px solid var(--color-border);
}

.comparison-page__section-heading {
  font-size: var(--font-lg);
  font-weight: var(--weight-semibold);
}

.comparison-page__section-description {
  margin: var(--space-xs) 0 var(--space-md);
  font-size: var(--font-sm);
  color: var(--color-text-sub);
}

.comparison-page__legend {
  display: flex;
  gap: var(--space-sm);
  margin-bottom: var(--space-lg);
  font-weight: var(--weight-medium);
}

.comparison-page__legend-item {
  border-radius: var(--radius-pill);
  padding: 8px 18px;
  font-size: var(--font-sm);
  font-weight: var(--weight-semibold);
  box-shadow: var(--shadow-sm);
}

.comparison-page__legend-item::before {
  content: "●";
  margin-right: 4px;
}

.comparison-page__legend-item--blue {
  color: var(--color-team-a-accent-text);
  background: var(--color-team-a-bg);
  border: 1px solid var(--color-team-a);
}

.comparison-page__legend-item--red {
  color: var(--color-team-b-accent-text);
  background: var(--color-team-b-bg);
  border: 1px solid var(--color-team-b);
}

.comparison-page__verdict {
  margin: 0 0 16px;
  padding: 12px 16px;
  border-radius: var(--radius-md);
  font-weight: var(--weight-bold);
  box-shadow: var(--shadow-md);
  background: var(--color-surface-sub);
  border: 1px solid var(--color-border);
  border-left: 4px solid var(--color-border-strong);
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
  border-left-color: var(--color-team-a);
  color: var(--color-team-a-strong-text);
}

.comparison-page__verdict--B {
  background: var(--color-team-b-bg);
  border-left-color: var(--color-team-b);
  color: var(--color-team-b-strong-text);
}

.comparison-page__verdict--even {
  background: var(--color-surface-sub);
  border-left-color: var(--color-border-strong);
}

.comparison-page__verdict-icon {
  vertical-align: -0.15em;
  margin-right: var(--space-xs);
}

.comparison-page__verdict-reason {
  display: block;
  font-weight: var(--weight-normal);
  font-size: var(--font-sm);
  color: var(--color-text-muted);
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
  border-radius: var(--radius-lg);
  overflow: hidden;
  box-shadow: var(--shadow-lg);
}

.comparison-page__pitch-overlay > .comparison-page__section-heading,
.comparison-page__pitch-overlay > .comparison-page__section-description {
  padding-inline: var(--space-md);
}

.comparison-page__pitch-overlay > .comparison-page__section-heading {
  padding-top: var(--space-md);
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
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
  border: 1px solid var(--color-border);
  padding: var(--space-lg);
}

.comparison-page__radar-title {
  margin: 0 0 var(--space-sm);
  font-size: var(--font-md);
  font-weight: var(--weight-semibold);
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
  box-shadow: var(--shadow-md);
  padding: var(--space-md) var(--space-lg);
  border: 1px solid var(--color-border);
}

.comparison-page__label {
  /* base.cssのマージンリセットでブラウザ既定のh2余白が消えるため明示する
     （直下のulとの間隔を確保。フォントサイズ等のトークン化は
     「コンポーネント層のトークン統一」フェーズで別途行う） */
  margin: 0 0 var(--space-sm);
}

.comparison-page__label--blue {
  color: var(--color-team-a);
}

.comparison-page__label--red {
  color: var(--color-team-b);
}

@media (max-width: 640px) {
  .comparison-page__body,
  .comparison-page__error {
    padding: var(--space-md) var(--space-md) var(--space-xl);
  }

  .comparison-page__pitch-overlay {
    max-width: 100%;
  }
}
</style>
