<template>
  <div class="halftime-modal-backdrop" role="presentation" @click.self="onCancel">
    <div
      ref="modalRef"
      class="halftime-modal"
      role="dialog"
      aria-modal="true"
      aria-label="ハーフタイム采配"
      @keydown.tab="onTabKeydown"
    >
      <div class="halftime-modal__header">
        <h2 class="halftime-modal__title">
          <AppIcon :icon="Wrench" />
          ハーフタイム采配
        </h2>
        <button
          ref="closeButtonRef"
          type="button"
          class="halftime-modal__close"
          aria-label="閉じる"
          @click="onCancel"
        >
          <AppIcon :icon="X" />
        </button>
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
        <button type="button" class="halftime-modal__reset" @click="onReset">
          <AppIcon :icon="RotateCcw" />
          配置をリセット
        </button>
        <button type="button" class="halftime-modal__confirm" @click="onConfirm">
          <AppIcon :icon="Play" />
          この配置で後半を開始する
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { Play, RotateCcw, Wrench, X } from "@lucide/vue";
import AppIcon from "@/components/AppIcon.vue";
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

// フォーカス管理（WCAG 2.4.3）: 開いた瞬間はモーダル外（背後の「配置を変更する」ボタン等）に
// フォーカスが残ったままになるため、閉じるボタンへ明示的に移す。閉じたときは、開く前に
// フォーカスされていた要素（＝モーダルを開いた起点のボタン）へ戻す
const modalRef = ref<HTMLElement | null>(null);
const closeButtonRef = ref<HTMLButtonElement | null>(null);
let previouslyFocusedElement: HTMLElement | null = null;

onMounted(() => {
  previouslyFocusedElement = document.activeElement as HTMLElement | null;
  closeButtonRef.value?.focus();
});

// previouslyFocusedElementが開いている間に別の理由でDOMから取り除かれていた場合、
// そこへの.focus()は何も起きない（例外にはならないが、フォーカスがどこにも移らず
// 迷子になる）。document.bodyへ一時的にtabindexを与えて確実にフォーカス先を作る
// （フォーカスを離したら元通りtabindexを外し、DOMに余分な属性を残さない）
function focusFallback(): void {
  const body = document.body;
  const hadTabIndex = body.hasAttribute("tabindex");
  if (!hadTabIndex) {
    body.setAttribute("tabindex", "-1");
    body.addEventListener("blur", () => body.removeAttribute("tabindex"), { once: true });
  }
  body.focus();
}

onBeforeUnmount(() => {
  document.removeEventListener("keydown", onDocumentKeydown);
  if (previouslyFocusedElement?.isConnected) {
    previouslyFocusedElement.focus();
  } else {
    focusFallback();
  }
});

// フォーカストラップ（WCAG 2.1.2 相当）: Tabキーでモーダルの外（背後のページ）へ
// フォーカスが抜けると、キーボードユーザーがモーダルを見失う。モーダル内の最初/最後の
// フォーカス可能要素で折り返す
function onTabKeydown(event: KeyboardEvent): void {
  const modal = modalRef.value;
  if (!modal) return;
  const focusable = Array.from(
    modal.querySelectorAll<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
    ),
  ).filter((el) => !el.hasAttribute("disabled"));
  if (focusable.length === 0) return;

  const first = focusable[0];
  const last = focusable[focusable.length - 1];
  if (event.shiftKey) {
    if (document.activeElement === first) {
      event.preventDefault();
      last.focus();
    }
  } else if (document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
}

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

.halftime-modal-fade-enter-active,
.halftime-modal-fade-leave-active {
  transition: background-color 0.2s ease;
}

.halftime-modal-fade-leave-active {
  /* leave中(200ms)もバックドロップがクリックを吸い続けると、確定直後に
     背面のボタンを押したつもりが消えかけのモーダルに吸われる */
  pointer-events: none;
}

.halftime-modal-fade-enter-active .halftime-modal,
.halftime-modal-fade-leave-active .halftime-modal {
  transition:
    opacity 0.2s ease,
    transform 0.2s ease;
}

.halftime-modal-fade-enter-from,
.halftime-modal-fade-leave-to {
  background-color: rgba(15, 23, 42, 0);
}

.halftime-modal-fade-enter-from .halftime-modal,
.halftime-modal-fade-leave-to .halftime-modal {
  opacity: 0;
  transform: scale(0.96) translateY(8px);
}

.halftime-modal__title {
  display: inline-flex;
  align-items: center;
  gap: var(--space-xs);
  margin: 0;
  font-size: var(--font-lg);
  font-weight: var(--weight-semibold);
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
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 44px;
  min-height: 44px;
  border: none;
  border-radius: var(--radius-sm);
  background: none;
  padding: 4px 8px;
  font-size: var(--font-md);
  color: var(--color-text-sub);
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.halftime-modal__close:hover {
  background: var(--color-surface-hover);
}

.halftime-modal__close:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

.halftime-modal__score {
  margin: 0 0 4px;
  font-size: var(--font-md);
  font-weight: var(--weight-semibold);
  color: var(--color-text);
}

.halftime-modal__hint {
  margin: 0 0 16px;
  font-size: var(--font-sm);
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
  display: inline-flex;
  align-items: center;
  gap: var(--space-xs);
  min-height: 44px;
  box-sizing: border-box;
  border: none;
  border-radius: 999px;
  padding: 10px 20px;
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  cursor: pointer;
  transition:
    background-color 0.15s ease,
    transform 0.15s ease;
}

.halftime-modal__reset {
  border: 1px solid var(--color-border);
  background: #ffffff;
  color: #374151;
}

.halftime-modal__reset:hover {
  background: var(--color-surface-hover);
}

.halftime-modal__confirm {
  background: linear-gradient(135deg, var(--color-primary), var(--color-primary-end));
  color: #ffffff;
  box-shadow: var(--shadow-card);
}

.halftime-modal__confirm:hover {
  transform: translateY(-1px);
}

.halftime-modal__confirm:focus-visible,
.halftime-modal__reset:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

@media (prefers-reduced-motion: reduce) {
  .halftime-modal-fade-enter-active,
  .halftime-modal-fade-leave-active,
  .halftime-modal-fade-enter-active .halftime-modal,
  .halftime-modal-fade-leave-active .halftime-modal {
    transition: none;
  }

  .halftime-modal__close,
  .halftime-modal__reset,
  .halftime-modal__confirm {
    transition: none;
  }

  .halftime-modal__confirm:hover {
    transform: none;
  }
}
</style>
