<template>
  <div class="halftime-modal-backdrop" role="presentation" @click.self="onCancel">
    <div class="halftime-modal" role="dialog" aria-modal="true" aria-label="ハーフタイム采配">
      <div class="halftime-modal__header">
        <h2 class="halftime-modal__title">🔧 ハーフタイム采配</h2>
        <button type="button" class="halftime-modal__close" aria-label="閉じる" @click="onCancel">✕</button>
      </div>
      <p class="halftime-modal__score">
        {{ formationA.name }} {{ halftimeResult.score.a }} - {{ halftimeResult.score.b }}
        {{ formationB.name }}（前半終了）
      </p>
      <p class="halftime-modal__hint">
        選手をドラッグして配置を変更できます（A/B両チーム）。変更内容は後半のシミュレーションに反映されます。
      </p>
      <FreeLayoutPitchDiagram
        :formation-a="draftFormationA"
        :formation-b="draftFormationB"
        @update-position="onUpdatePosition"
      />
      <div class="halftime-modal__actions">
        <button type="button" class="halftime-modal__reset" @click="onReset">↺ 配置をリセット</button>
        <button type="button" class="halftime-modal__confirm" @click="onConfirm">
          ▶ この配置で後半を開始する
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from "vue";
import FreeLayoutPitchDiagram from "@/components/FreeLayoutPitchDiagram.vue";
import type { Formation, MatchSimulationResult, Position } from "@/types/formation";

const props = defineProps<{
  formationA: Formation;
  formationB: Formation;
  halftimeResult: MatchSimulationResult;
}>();

const emit = defineEmits<{
  confirm: [positionsA: Position[], positionsB: Position[]];
  cancel: [];
}>();

function clonePositions(positions: Position[]): Position[] {
  return positions.map((position) => ({ ...position }));
}

const draftPositionsA = ref<Position[]>(clonePositions(props.formationA.positions));
const draftPositionsB = ref<Position[]>(clonePositions(props.formationB.positions));

const draftFormationA = computed<Formation>(() => ({
  ...props.formationA,
  positions: draftPositionsA.value,
}));
const draftFormationB = computed<Formation>(() => ({
  ...props.formationB,
  positions: draftPositionsB.value,
}));

function onUpdatePosition(team: "A" | "B", positionId: string, x: number, y: number): void {
  const target = team === "A" ? draftPositionsA : draftPositionsB;
  target.value = target.value.map((position) =>
    position.id === positionId ? { ...position, x, y } : position,
  );
}

function onReset(): void {
  draftPositionsA.value = clonePositions(props.formationA.positions);
  draftPositionsB.value = clonePositions(props.formationB.positions);
}

function onConfirm(): void {
  emit("confirm", draftPositionsA.value, draftPositionsB.value);
}

function onCancel(): void {
  emit("cancel");
}

// モーダルが開いている間だけdocumentにEscapeリスナを張る
// （TermAnnotatedText.vueと同じパターン。閉じたら確実に解除する）
function onDocumentKeydown(event: KeyboardEvent): void {
  if (event.key === "Escape") onCancel();
}

document.addEventListener("keydown", onDocumentKeydown);
onBeforeUnmount(() => {
  document.removeEventListener("keydown", onDocumentKeydown);
});

// 表示対象のフォーメーションが変わったら（通常は発生しないが、念のため）ドラフトを作り直す
watch(
  () => [props.formationA.id, props.formationB.id] as const,
  () => onReset(),
);
</script>

<style scoped>
.halftime-modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 100;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(15, 23, 42, 0.55);
  padding: 16px;
}

.halftime-modal {
  width: 100%;
  max-width: 560px;
  max-height: 90vh;
  overflow-y: auto;
  border-radius: var(--radius-card);
  background: #ffffff;
  box-shadow: var(--shadow-card);
  padding: 24px;
}

.halftime-modal__title {
  margin: 0;
  font-size: 18px;
  font-weight: 700;
  color: var(--color-text);
}

.halftime-modal__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 8px;
}

.halftime-modal__close {
  border: none;
  background: none;
  padding: 4px 8px;
  font-size: 16px;
  line-height: 1;
  color: var(--color-text-sub);
  cursor: pointer;
}

.halftime-modal__close:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

.halftime-modal__score {
  margin: 0 0 4px;
  font-size: 15px;
  font-weight: 700;
  color: var(--color-text);
}

.halftime-modal__hint {
  margin: 0 0 16px;
  font-size: 13px;
  color: var(--color-text-sub);
}

.halftime-modal__actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 16px;
}

.halftime-modal__reset,
.halftime-modal__confirm {
  border: none;
  border-radius: 999px;
  padding: 10px 20px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
}

.halftime-modal__reset {
  border: 1px solid var(--color-border);
  background: #ffffff;
  color: #374151;
}

.halftime-modal__confirm {
  background: linear-gradient(135deg, var(--color-primary), var(--color-primary-end));
  color: #ffffff;
  box-shadow: var(--shadow-card);
}

.halftime-modal__confirm:focus-visible,
.halftime-modal__reset:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}
</style>
