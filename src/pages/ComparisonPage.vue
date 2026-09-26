<template>
  <div class="comparison-page">
    <template v-if="formationA && formationB && matchup">
      <PageHeader show-back-button :title="`${formationA.name} vs ${formationB.name}`">
        <router-link to="/glossary" class="comparison-page__glossary-link"> 📖 用語集 </router-link>
      </PageHeader>
      <div class="comparison-page__body">
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
              v-if="isFreeLayoutMode && effectiveFormationA && effectiveFormationB"
              :formation-a="effectiveFormationA"
              :formation-b="effectiveFormationB"
              @update-position="onUpdatePosition"
              @update-position-end="onUpdatePositionEnd"
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
            v-if="!simulationResult && !halftimeResult"
            type="button"
            class="comparison-page__simulate-button"
            @click="runSimulation"
          >
            ⚽ 試合をシミュレートする
          </button>
          <template v-if="halftimeResult && !simulationResult">
            <MatchSimulationPanel
              :result="halftimeResult"
              :formation-a-name="formationA.name"
              :formation-b-name="formationB.name"
            />
            <div class="comparison-page__halftime-actions">
              <button type="button" class="comparison-page__halftime-tactics-button" @click="openHalftimeTactics">
                🔧 配置を変更する
              </button>
              <button type="button" class="comparison-page__halftime-continue-button" @click="proceedWithoutChange">
                ▶ 後半を開始する
              </button>
            </div>
            <Transition name="halftime-modal-fade">
              <HalftimeTacticsModal
                v-if="isHalftimeModalOpen && effectiveFormationA && effectiveFormationB"
                :formation-a="effectiveFormationA"
                :formation-b="effectiveFormationB"
                :halftime-result="halftimeResult"
                @confirm="onHalftimeConfirm"
                @cancel="closeHalftimeTactics"
              />
            </Transition>
          </template>
          <MatchSimulationPanel
            v-if="simulationResult"
            :result="simulationResult"
            :formation-a-name="formationA.name"
            :formation-b-name="formationB.name"
          />
        </div>
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
import { computed, ref, shallowRef, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import ComparisonControls from "@/components/ComparisonControls.vue";
import FreeLayoutControls from "@/components/FreeLayoutControls.vue";
import FreeLayoutPitchDiagram from "@/components/FreeLayoutPitchDiagram.vue";
import HalftimeTacticsModal from "@/components/HalftimeTacticsModal.vue";
import MatchSimulationPanel from "@/components/MatchSimulationPanel.vue";
import MatchupPitchDiagram from "@/components/MatchupPitchDiagram.vue";
import PageHeader from "@/components/PageHeader.vue";
import RadarChart from "@/components/RadarChart.vue";
import SquadConditionControls from "@/components/SquadConditionControls.vue";
import TermAnnotatedText from "@/components/TermAnnotatedText.vue";
import { startMatch, resumeMatch, type MatchProgress } from "@/composables/matchSimulation";
import { applySquadVariance } from "@/composables/squadCondition";
import { formations, getFormationById } from "@/data/formations";
import { getMatchup } from "@/data/matchups";
import { generateMatchup } from "@/data/matchupGenerator";
import { getTags } from "@/data/formationTags";
import { estimateStats } from "@/data/radarScoreEstimator";
import { markPairViewed } from "@/data/learningProgress";
import { applyOverrides, clearFormationOverride, savePositionOverride } from "@/data/freeLayoutStorage";
import { radarAxes } from "@/data/radarAxes";
import type { Formation, MatchSimulationResult, Position } from "@/types/formation";

const route = useRoute();
const router = useRouter();

const formationA = computed(() => getFormationById(route.params.formationAId as string));
const formationB = computed(() => getFormationById(route.params.formationBId as string));

// 自由配置モード: A・B両チームともドラッグで配置を変更できる一時状態（表示用のref自体は
// 永続化しない。組み合わせ切替・トグルOFF・画面離脱でリセットする）。
// ただし配置そのものはフォーメーションID単位でdata/freeLayoutStorage.tsへ永続化しており、
// 再度自由配置モードをONにすると復元される（FR-15永続化。「一時状態のref」と
// 「フォーメーションに紐づく保存データ」は別物であることに注意）
const isFreeLayoutMode = ref(false);
const freePositionsA = ref<Position[] | null>(null);
const freePositionsB = ref<Position[] | null>(null);

function clonePositions(positions: Position[]): Position[] {
  return positions.map((position) => ({ ...position }));
}

function toggleFreeLayoutMode(): void {
  if (isFreeLayoutMode.value) {
    isFreeLayoutMode.value = false;
    freePositionsA.value = null;
    freePositionsB.value = null;
    return;
  }
  if (!formationA.value || !formationB.value) return;
  isFreeLayoutMode.value = true;
  // 保存済みの配置があれば復元し、無ければcanonicalな配置がそのまま返る
  freePositionsA.value = applyOverrides(formationA.value.positions, formationA.value.id);
  freePositionsB.value = applyOverrides(formationB.value.positions, formationB.value.id);
  // 自由配置モードに入る前のstatsで計算された試合シミュレーション結果は、
  // これから変更されうるA/Bチームの表示（タグ・優位ポイント・レーダー）と食い違うため破棄する
  resetMatchState();
}

function resetFreeLayout(): void {
  if (!formationA.value || !formationB.value) return;
  clearFormationOverride(formationA.value.id);
  clearFormationOverride(formationB.value.id);
  freePositionsA.value = clonePositions(formationA.value.positions);
  freePositionsB.value = clonePositions(formationB.value.positions);
}

// ドラッグ中(pointermoveのたびに高頻度で発火)の表示更新のみを行う。永続化はしない
// （pointermoveごとにlocalStorageへ同期書き込みすると、1回のドラッグで数十〜数百回の
// read-modify-writeが走りジャンクの原因になるため、永続化はonUpdatePositionEndに寄せる）
function onUpdatePosition(team: "A" | "B", positionId: string, x: number, y: number): void {
  const freePositions = team === "A" ? freePositionsA : freePositionsB;
  if (!freePositions.value) return;
  freePositions.value = freePositions.value.map((position) =>
    position.id === positionId ? { ...position, x, y } : position,
  );
  // 配置を動かした時点で、表示中のシミュレーション結果は古い配置に基づくため破棄する
  resetMatchState();
}

// ドラッグ確定時（pointerup/pointercancel）に1回だけ発火し、永続化する
function onUpdatePositionEnd(team: "A" | "B", positionId: string, x: number, y: number): void {
  const formation = team === "A" ? formationA.value : formationB.value;
  if (!formation) return;
  savePositionOverride(formation.id, positionId, x, y);
}

// 自由配置モード中はfreePositionsA/Bを反映したFormationを、そうでなければ静的な
// formationA/Bをそのまま使う。matchup/レーダースコアの算出はこちらを入力にする
const effectiveFormationA = computed(() => {
  if (!formationA.value) return undefined;
  if (!freePositionsA.value) return formationA.value;
  return { ...formationA.value, positions: freePositionsA.value };
});

const effectiveFormationB = computed(() => {
  if (!formationB.value) return undefined;
  if (!freePositionsB.value) return formationB.value;
  return { ...formationB.value, positions: freePositionsB.value };
});

// 自由配置モードでない限り既存のgetMatchup（静的キャッシュのIDルックアップ）を使う。
// A・Bいずれかが自由配置モード中なら、変更後の配置でgenerateMatchupを都度呼び直す
const matchup = computed(() => {
  if (!effectiveFormationA.value || !effectiveFormationB.value) return undefined;
  if (!freePositionsA.value && !freePositionsB.value) {
    return getMatchup(effectiveFormationA.value.id, effectiveFormationB.value.id);
  }
  return generateMatchup(effectiveFormationA.value, effectiveFormationB.value);
});

// 自由配置モード中のA/Bチームのレーダースコア概算。タグ構成の差分から元のstatsを基準に算出する
const effectiveStatsA = computed(() => {
  if (!formationA.value) return undefined;
  if (!effectiveFormationA.value || !freePositionsA.value) return formationA.value.stats;
  return estimateStats(
    getTags(effectiveFormationA.value),
    getTags(formationA.value),
    formationA.value.stats,
  );
});

const effectiveStatsB = computed(() => {
  if (!formationB.value) return undefined;
  if (!effectiveFormationB.value || !freePositionsB.value) return formationB.value.stats;
  return estimateStats(
    getTags(effectiveFormationB.value),
    getTags(formationB.value),
    formationB.value.stats,
  );
});

// FR-14: 試合シミュレーション結果（90分ぶんの最終結果）。ボタン押下時にのみ計算する
// （表示するまで90分ループを走らせる必要が無いため）。フォーメーションの組み合わせが
// 変わったら古い結果を残さない
const simulationResult = ref<MatchSimulationResult | null>(null);

// ハーフタイム采配: 前半(1-45分)の部分結果と、後半を続けるための不透明な進行状態。
// どちらも「試合終了(simulationResult確定)」または「組み合わせ変更」でリセットする
// MatchProgressは乱数クロージャ・累積配列を持つ不透明な内部状態であり、Vueのdeepな
// リアクティブトラッキングは不要（毎分のpush等をVueに追跡させる意味が無い）
const matchProgress = shallowRef<MatchProgress | null>(null);
const halftimeResult = ref<MatchSimulationResult | null>(null);
const isHalftimeModalOpen = ref(false);

// 選手個体差（スカッドコンディション）: nullは無効を表す。有効時のみ試合シミュレーションに渡す
// 実効statsの算出に使う。永続化せず、レーダーチャート・優位ポイント・matchup（タグ導出）には
// 一切影響させない（design.md「実装対象の機能」参照）。シードの「引き方」はUIの関心事、
// 「シードから実効statsを作る」のはcomposables/squadCondition.tsの関心事、という責務分離を保つ
const squadConditionSeed = ref<number | null>(null);

function resetMatchState(): void {
  simulationResult.value = null;
  matchProgress.value = null;
  halftimeResult.value = null;
  isHalftimeModalOpen.value = false;
}

function generateSeed(): number {
  return Math.floor(Math.random() * 0xffffffff);
}

function toggleSquadCondition(): void {
  squadConditionSeed.value = squadConditionSeed.value === null ? generateSeed() : null;
  // 古いスカッド条件に基づく結果（ハーフタイムの途中経過も含む）を残さない
  resetMatchState();
}

function rerollSquadCondition(): void {
  if (squadConditionSeed.value === null) return;
  squadConditionSeed.value = generateSeed();
  resetMatchState();
}

// squadConditionSeedが有効なら、シード（Bはoffset分ずらして異なる乱数列にする）から
// 決定的に算出した実効statsを持つFormationを返す。無効ならformationをそのまま返す
// （参照も変えない。「スカッド未使用ならFR-14/FR-19と完全に同じ結果になる」を、
// この関数が恒等になることで担保する）
function withSquadVariance(formation: Formation, seed: number | null, offset: number): Formation {
  if (seed === null) return formation;
  return { ...formation, stats: applySquadVariance(formation.stats, seed + offset) };
}

function runSimulation(): void {
  // 自由配置モード(FR-15)でA/Bの配置を動かしている場合、その変更後の配置
  // (effectiveFormationA/B)を使う。matchup.valueも同じeffectiveFormationA/Bから
  // 算出されているため、前半の入力とmatchup（総合判定）の基準を揃える
  if (!effectiveFormationA.value || !effectiveFormationB.value || !matchup.value) return;
  const a = withSquadVariance(effectiveFormationA.value, squadConditionSeed.value, 0);
  const b = withSquadVariance(effectiveFormationB.value, squadConditionSeed.value, 1);
  const { progress, result } = startMatch(a, b, matchup.value, 45);
  matchProgress.value = progress;
  halftimeResult.value = result;
}

function openHalftimeTactics(): void {
  isHalftimeModalOpen.value = true;
}

function closeHalftimeTactics(): void {
  isHalftimeModalOpen.value = false;
}

function samePositions(a: readonly Position[], b: readonly Position[]): boolean {
  if (a.length !== b.length) return false;
  return a.every((position, index) => position.x === b[index].x && position.y === b[index].y);
}

// 配置が実際に変わっていなければ既存の静的matchupをそのまま使う。
// 「変更しなければFR-14と完全に同じ結果になる」を、generateMatchupの再計算結果が
// getMatchupの事前計算結果と厳密に一致する保証に頼らず、入力を変えないことで担保する
function onHalftimeConfirm(positionsA: Position[], positionsB: Position[]): void {
  // 前半の入力はeffectiveFormationA/B（自由配置モードの変更を含む）だったため、
  // 「変更が無い」の基準もformationA/B.valueではなくeffectiveFormationA/B.valueにする
  if (!effectiveFormationA.value || !effectiveFormationB.value || !matchProgress.value || !matchup.value) return;
  const changedA = !samePositions(positionsA, effectiveFormationA.value.positions);
  const changedB = !samePositions(positionsB, effectiveFormationB.value.positions);
  const baseA: Formation = changedA ? { ...effectiveFormationA.value, positions: positionsA } : effectiveFormationA.value;
  const baseB: Formation = changedB ? { ...effectiveFormationB.value, positions: positionsB } : effectiveFormationB.value;
  // matchup（タグ・総合判定）は配置のみで決まるため、スカッド適用前のFormationから算出する
  const nextMatchup = changedA || changedB ? generateMatchup(baseA, baseB) : matchup.value;
  const nextA = withSquadVariance(baseA, squadConditionSeed.value, 0);
  const nextB = withSquadVariance(baseB, squadConditionSeed.value, 1);

  simulationResult.value = resumeMatch(matchProgress.value, nextA, nextB, nextMatchup);
  matchProgress.value = null;
  halftimeResult.value = null;
  isHalftimeModalOpen.value = false;
}

function proceedWithoutChange(): void {
  if (!effectiveFormationA.value || !effectiveFormationB.value || !matchProgress.value || !matchup.value) return;
  const nextA = withSquadVariance(effectiveFormationA.value, squadConditionSeed.value, 0);
  const nextB = withSquadVariance(effectiveFormationB.value, squadConditionSeed.value, 1);
  simulationResult.value = resumeMatch(matchProgress.value, nextA, nextB, matchup.value);
  matchProgress.value = null;
  halftimeResult.value = null;
  // モーダルを開いたまま「後半を開始する」ボタン（背後）へキーボード操作で到達した場合、
  // モーダルを開いたフラグだけが残らないようにする（他のリセット経路と揃える）
  isHalftimeModalOpen.value = false;
}

watch(
  () => [formationA.value?.id, formationB.value?.id] as const,
  () => {
    resetMatchState();
    // 組み合わせが変わったら自由配置モード・選手個体差の一時状態も破棄する。
    // 自由配置の保存データ自体（data/freeLayoutStorage.ts）はフォーメーションIDに紐づき、
    // 組み合わせの切替では消さない（FR-15永続化の要件）。ここで破棄するのはあくまで
    // 「その場の表示用の一時状態」であり、次に自由配置モードをONにすれば保存データから復元される
    isFreeLayoutMode.value = false;
    freePositionsA.value = null;
    freePositionsB.value = null;
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
  if (!formationA.value || !formationB.value || !effectiveStatsA.value || !effectiveStatsB.value) {
    return [];
  }
  return [
    { label: formationA.value.name, colorVar: "--color-team-a", values: effectiveStatsA.value },
    { label: formationB.value.name, colorVar: "--color-team-b", values: effectiveStatsB.value },
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
  padding: var(--space-lg) var(--space-2xl) var(--space-2xl);
}

.comparison-page__error {
  padding: var(--space-lg) var(--space-2xl) var(--space-2xl);
}

.comparison-page__glossary-link {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  box-sizing: border-box;
  border: 1px solid rgba(255, 255, 255, 0.6);
  border-radius: var(--radius-pill);
  padding: var(--space-sm) var(--space-md);
  font-size: var(--font-sm);
  font-weight: 700;
  color: #ffffff;
  white-space: nowrap;
  text-decoration: none;
  transition: background-color 0.15s ease;
}

.comparison-page__glossary-link:hover {
  background: rgba(255, 255, 255, 0.15);
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
  min-height: 44px;
  box-sizing: border-box;
  border: none;
  border-radius: var(--radius-pill);
  background: linear-gradient(135deg, var(--color-primary), var(--color-primary-end));
  box-shadow: var(--shadow-card);
  padding: 12px 28px;
  font-size: var(--font-md);
  font-weight: 700;
  color: #ffffff;
  cursor: pointer;
  transition: transform 0.15s ease;
}

.comparison-page__simulate-button:hover {
  transform: translateY(-1px);
}

.comparison-page__simulate-button:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

.comparison-page__halftime-actions {
  display: flex;
  justify-content: center;
  gap: 12px;
  margin-top: 12px;
}

.comparison-page__halftime-tactics-button,
.comparison-page__halftime-continue-button {
  min-height: 44px;
  box-sizing: border-box;
  border: none;
  border-radius: var(--radius-pill);
  box-shadow: var(--shadow-card);
  padding: 10px 20px;
  font-size: var(--font-sm);
  font-weight: 700;
  cursor: pointer;
  transition:
    background-color 0.15s ease,
    transform 0.15s ease;
}

.comparison-page__halftime-tactics-button {
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text-muted);
}

.comparison-page__halftime-tactics-button:hover {
  background: var(--color-surface-hover);
}

.comparison-page__halftime-continue-button {
  background: linear-gradient(135deg, var(--color-primary), var(--color-primary-end));
  color: #ffffff;
}

.comparison-page__halftime-continue-button:hover {
  transform: translateY(-1px);
}

.comparison-page__halftime-tactics-button:focus-visible,
.comparison-page__halftime-continue-button:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

@media (max-width: 640px) {
  .comparison-page__body,
  .comparison-page__error {
    padding: var(--space-md) var(--space-md) var(--space-xl);
  }

  .comparison-page__pitch-overlay {
    max-width: 100%;
  }

  .comparison-page__halftime-actions {
    flex-wrap: wrap;
  }
}

@media (prefers-reduced-motion: reduce) {
  .comparison-page__simulate-button,
  .comparison-page__halftime-tactics-button,
  .comparison-page__halftime-continue-button,
  .comparison-page__glossary-link {
    transition: none;
  }

  .comparison-page__simulate-button:hover,
  .comparison-page__halftime-continue-button:hover {
    transform: none;
  }
}
</style>
