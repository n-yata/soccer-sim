<template>
  <span ref="rootEl" class="term-annotated-text">
    <template v-for="(segment, index) in segments" :key="index">
      <span v-if="segment.kind === 'plain'">{{ segment.text }}</span>
      <span v-else class="term-annotated-text__slot">
        <button
          type="button"
          class="term-annotated-text__term"
          :aria-expanded="openIndex === index"
          :aria-describedby="openIndex === index ? popoverId(index) : undefined"
          @click="toggle(index)"
        >
          {{ segment.text }}
        </button>
        <Transition name="term-popover-fade">
          <TermPopover v-if="openIndex === index" :id="popoverId(index)" :term="segment.term" />
        </Transition>
      </span>
    </template>
  </span>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, useId, watch } from "vue";
import TermPopover from "@/components/TermPopover.vue";
import { annotateText } from "@/data/termAnnotation";

const props = defineProps<{
  text: string;
}>();

// aria-describedby は文書内で一意なidを要求する。本コンポーネントは1画面に複数個
// （優位ポイントの各行・総合判定理由）置かれるため、インスタンスごとに一意な接頭辞を得る。
// <script setup> 内の変数はインスタンスごとに初期化されるため、自前のカウンタでは
// 採番できない（全インスタンスが同じ番号になる）
const instanceId = useId();

const rootEl = ref<HTMLElement | null>(null);
const openIndex = ref<number | null>(null);

const segments = computed(() => annotateText(props.text));

function popoverId(index: number): string {
  return `${instanceId}-popover-${index}`;
}

function close(): void {
  openIndex.value = null;
}

function toggle(index: number): void {
  openIndex.value = openIndex.value === index ? null : index;
}

// 本文の外側がクリックされたら閉じる。イベントの伝播を止める（@click.stop）方式にすると、
// pointerdown が先に document へ届いて閉じ→click で開き直す、という往復が起きて
// 「同じ用語をもう一度押して閉じる」が効かなくなる。包含判定で判断する
function onDocumentPointerDown(event: PointerEvent): void {
  const root = rootEl.value;
  if (!root) return;
  if (event.target instanceof Node && root.contains(event.target)) return;
  close();
}

function onDocumentKeydown(event: KeyboardEvent): void {
  if (event.key === "Escape") close();
}

// リスナは開いている間だけ張る。常時張ると、画面上の TermAnnotatedText の数だけ
// document のイベントを拾い続けることになる
watch(openIndex, (current, previous) => {
  const wasOpen = previous !== null;
  const isOpen = current !== null;
  if (isOpen === wasOpen) return;

  if (isOpen) {
    document.addEventListener("pointerdown", onDocumentPointerDown);
    document.addEventListener("keydown", onDocumentKeydown);
  } else {
    document.removeEventListener("pointerdown", onDocumentPointerDown);
    document.removeEventListener("keydown", onDocumentKeydown);
  }
});

// 表示する文が差し替わると、開いていたindexは別の用語（または平文）を指してしまう。
// A/B入れ替え・切替（FR-09）で実際に起きるため、文が変わったら必ず閉じる
watch(
  () => props.text,
  () => close(),
);

onBeforeUnmount(() => {
  document.removeEventListener("pointerdown", onDocumentPointerDown);
  document.removeEventListener("keydown", onDocumentKeydown);
});
</script>

<style scoped>
.term-annotated-text {
  /* 親の <li> / <p> の行送りをそのまま使う */
  display: inline;
}

/*
  ポップオーバーの位置決めの基準。inline-block にすると用語が行末で折り返せなくなるため
  inline のままにし、position: relative だけを与える
*/
.term-annotated-text__slot {
  position: relative;
  display: inline;
}

.term-annotated-text__term {
  border: 0;
  border-bottom: 1px dotted var(--color-primary);
  border-radius: 2px;
  background: none;
  padding: 0;
  font: inherit;
  color: var(--color-primary);
  font-weight: var(--weight-semibold);
  cursor: help;
  transition: background-color 0.15s ease;
}

.term-annotated-text__term:hover {
  background: #f0fdf4;
}

.term-annotated-text__term:focus-visible {
  outline: 2px solid var(--color-accent);
  outline-offset: 2px;
}

@media (prefers-reduced-motion: reduce) {
  .term-annotated-text__term {
    transition: none;
  }
}
</style>
