<template>
  <div class="matrix-page">
    <div class="matrix-page__header">
      <button type="button" class="matrix-page__back-button" @click="goBack">← 戻る</button>
      <h1 class="matrix-page__title">相性マトリクス</h1>
    </div>
    <p class="matrix-page__subtitle">
      行のフォーメーションが列のフォーメーションに対して有利かを一目で確認できます
    </p>
    <div class="matrix-page__legend">
      <span class="matrix-page__legend-item matrix-page__legend-item--row">行が有利</span>
      <span class="matrix-page__legend-item matrix-page__legend-item--col">列が有利</span>
      <span class="matrix-page__legend-item matrix-page__legend-item--even">互角</span>
      <span class="matrix-page__legend-item matrix-page__legend-item--viewed">✓ 確認済み</span>
    </div>

    <!--
      FR-13: どこまで見たかを可視化する。KPI の「全フォーメーションを1周確認し終えた時点」を
      利用者自身が判断できるようにする
    -->
    <div class="matrix-page__progress">
      <p class="matrix-page__progress-text">
        確認済み <strong>{{ viewedCount }}</strong> / 全 {{ totalPairs }} 組み合わせ
        <span v-if="isComplete" class="matrix-page__progress-done">🎉 すべて確認しました</span>
      </p>
      <div class="matrix-page__progress-actions">
        <button
          v-if="!isConfirmingClear"
          type="button"
          class="matrix-page__clear-button"
          :disabled="viewedCount === 0"
          @click="isConfirmingClear = true"
        >
          進捗を消去
        </button>
        <!--
          window.confirm は使わない。ブラウザのモーダルは自動テストとブラウザ自動操作を
          止めてしまうため、インラインの2段階確認にする
        -->
        <template v-else>
          <span class="matrix-page__clear-confirm-text">進捗を消去しますか？</span>
          <button type="button" class="matrix-page__clear-confirm" @click="onClearProgress">
            消去する
          </button>
          <button type="button" class="matrix-page__clear-cancel" @click="isConfirmingClear = false">
            やめる
          </button>
        </template>
      </div>
    </div>

    <div class="matrix-page__table-wrapper">
      <table class="matrix-page__table">
        <thead>
          <tr>
            <th scope="col"></th>
            <th v-for="col in formations" :key="`col-${col.id}`" scope="col">
              {{ col.name }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in formations" :key="`row-${row.id}`">
            <th scope="row">{{ row.name }}</th>
            <td v-for="col in formations" :key="`cell-${row.id}-${col.id}`">
              <span
                v-if="row.id === col.id"
                class="matrix-page__cell matrix-page__cell--diagonal"
                aria-hidden="true"
              ></span>
              <span
                v-else-if="!hasMatchup(row.id, col.id)"
                class="matrix-page__cell matrix-page__cell--unknown"
                role="img"
                :aria-label="`${row.name} vs ${col.name}: データ未定義`"
              ></span>
              <router-link
                v-else
                :to="`/compare/${row.id}/${col.id}`"
                class="matrix-page__cell"
                :class="buildCellClass(row.id, col.id)"
                :aria-label="formatCellLabel(row, col)"
              >
                <!--
                  確認済みは色ではなくチェック印で示す。セルの色は既に
                  「行有利 / 列有利 / 互角」に使われており、そこへ色を重ねると
                  どちらの意味なのか判別できなくなる
                -->
                <span
                  v-if="isViewed(row.id, col.id)"
                  class="matrix-page__cell-check"
                  aria-hidden="true"
                  >✓</span
                >
              </router-link>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { useRouter } from "vue-router";
import { formations } from "@/data/formations";
import { getMatchup } from "@/data/matchups";
import {
  buildPairKey,
  clearProgress,
  countAllPairs,
  loadProgress,
} from "@/data/learningProgress";
import type { Formation, LearningProgress, Matchup } from "@/types/formation";

const router = useRouter();

// FR-13: 進捗はマウント時に一度読み、以降は画面内の状態として扱う。
// 消去操作でのみ変化するため、描画のたびに localStorage を読み直す必要はない
const progress = ref<LearningProgress>(loadProgress());
const isConfirmingClear = ref(false);

const totalPairs = computed(() => countAllPairs(formations));

// N×Nのセル描画のたびに配列を線形探索(includes)すると、フォーメーション追加で
// 拡張する設計(NFR-03)ではNが増えるほど効いてくる。Set化して判定をO(1)にする
const viewedSet = computed(() => new Set(progress.value.viewedPairs));

// 分子は「現在のフォーメーションで実在する組み合わせ」に限る。
// 保存済みキーをそのまま数えると、データから消えたフォーメーションの記録が
// 残っている場合に分子が分母を超える
const viewedCount = computed(
  () =>
    formations.reduce((count, row, rowIndex) => {
      const pairsInRow = formations
        .slice(rowIndex + 1)
        .filter((col) => viewedSet.value.has(buildPairKey(row.id, col.id))).length;
      return count + pairsInRow;
    }, 0),
);

const isComplete = computed(() => totalPairs.value > 0 && viewedCount.value === totalPairs.value);

function isViewed(rowId: string, colId: string): boolean {
  return viewedSet.value.has(buildPairKey(rowId, colId));
}

function onClearProgress(): void {
  progress.value = clearProgress();
  isConfirmingClear.value = false;
}

// フォーメーションを追加してもmatchups.tsへの対応レコード追加を忘れる可能性がある
// （FR-07の「データ追加のみで拡張可能」を実行した直後など）。この場合、本物の
// 「互角」判定と区別できず「マトリクスは互角と表示するが遷移先は表示不能」という
// 静かな不整合が起きるため、edgeが無い（=matchup未定義）ことを独立した状態として扱う
function resolveEdge(rowId: string, colId: string): Matchup["overallEdge"] | undefined {
  return getMatchup(rowId, colId)?.overallEdge;
}

function hasMatchup(rowId: string, colId: string): boolean {
  return resolveEdge(rowId, colId) !== undefined;
}

function buildCellClass(rowId: string, colId: string): string {
  const edge = resolveEdge(rowId, colId);
  if (edge === "A") return "matrix-page__cell--row";
  if (edge === "B") return "matrix-page__cell--col";
  return "matrix-page__cell--even";
}

function formatCellLabel(row: Formation, col: Formation): string {
  const edge = resolveEdge(row.id, col.id);
  // チェック印は aria-hidden なので、確認済みかどうかはラベル側で伝える
  const viewed = isViewed(row.id, col.id) ? "、確認済み" : "、未確認";
  if (edge === "A") return `${row.name} vs ${col.name}: ${row.name}がやや優位${viewed}`;
  if (edge === "B") return `${row.name} vs ${col.name}: ${col.name}がやや優位${viewed}`;
  return `${row.name} vs ${col.name}: 互角${viewed}`;
}

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
</script>

<style scoped>
.matrix-page {
  padding: 24px 40px 40px;
}

.matrix-page__header {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 8px;
}

.matrix-page__back-button {
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

.matrix-page__title {
  margin: 0;
  font-size: 24px;
  font-weight: 700;
  color: var(--color-text);
}

.matrix-page__subtitle {
  margin: 0 0 16px;
  font-size: 13px;
  color: var(--color-text-sub);
}

.matrix-page__legend {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
  font-weight: bold;
}

.matrix-page__legend-item {
  border-radius: 999px;
  padding: 6px 14px;
  font-size: 13px;
}

.matrix-page__legend-item::before {
  content: "●";
  margin-right: 4px;
}

.matrix-page__legend-item--row {
  color: #1d4ed8;
  background: var(--color-team-a-bg);
  border: 1px solid var(--color-team-a);
}

.matrix-page__legend-item--col {
  color: #b91c1c;
  background: var(--color-team-b-bg);
  border: 1px solid var(--color-team-b);
}

.matrix-page__legend-item--even {
  color: var(--color-text-sub);
  background: #f9fafb;
  border: 1px solid var(--color-border);
}

.matrix-page__legend-item--viewed {
  color: #374151;
  background: #ffffff;
  border: 1px solid var(--color-border);
}

/* 「✓ 確認済み」はラベル自体に記号を持つので、共通の ● は付けない */
.matrix-page__legend-item--viewed::before {
  content: none;
}

.matrix-page__progress {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px 20px;
  margin-bottom: 16px;
}

.matrix-page__progress-text {
  margin: 0;
  font-size: 13px;
  color: var(--color-text-sub);
}

.matrix-page__progress-text strong {
  font-size: 18px;
  color: var(--color-primary);
}

.matrix-page__progress-done {
  margin-left: 8px;
  font-weight: 700;
  color: var(--color-primary);
}

.matrix-page__progress-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.matrix-page__clear-button,
.matrix-page__clear-confirm,
.matrix-page__clear-cancel {
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: #ffffff;
  padding: 6px 14px;
  font-size: 12px;
  font-weight: 700;
  color: #374151;
  cursor: pointer;
}

.matrix-page__clear-button:disabled {
  color: #9ca3af;
  cursor: default;
}

.matrix-page__clear-confirm {
  border-color: #b91c1c;
  color: #b91c1c;
}

.matrix-page__clear-confirm-text {
  font-size: 12px;
  font-weight: 700;
  color: var(--color-text);
}

.matrix-page__clear-button:focus-visible,
.matrix-page__clear-confirm:focus-visible,
.matrix-page__clear-cancel:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

.matrix-page__cell-check {
  font-size: 20px;
  font-weight: 700;
  line-height: 1;
  color: #111827;
  opacity: 0.55;
}

.matrix-page__table-wrapper {
  overflow-x: auto;
}

.matrix-page__table {
  border-collapse: separate;
  border-spacing: 6px;
}

.matrix-page__table th {
  font-size: 12px;
  font-weight: 700;
  color: var(--color-text);
  padding: 4px 8px;
  white-space: nowrap;
}

.matrix-page__cell {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  border-radius: 8px;
  box-sizing: border-box;
  text-decoration: none;
}

.matrix-page__cell--diagonal {
  background: repeating-linear-gradient(
    45deg,
    #f3f4f6,
    #f3f4f6 4px,
    #e5e7eb 4px,
    #e5e7eb 8px
  );
  border: 1px solid var(--color-border);
}

.matrix-page__cell--row {
  background: var(--color-team-a-bg);
  border: 2px solid var(--color-team-a);
}

.matrix-page__cell--col {
  background: var(--color-team-b-bg);
  border: 2px solid var(--color-team-b);
}

.matrix-page__cell--even {
  background: #f9fafb;
  border: 2px solid #9ca3af;
}

.matrix-page__cell--unknown {
  background: repeating-linear-gradient(45deg, #fef3c7, #fef3c7 4px, #fde68a 4px, #fde68a 8px);
  border: 1px dashed #d97706;
}

a.matrix-page__cell:hover {
  filter: brightness(0.96);
}

a.matrix-page__cell:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}
</style>
