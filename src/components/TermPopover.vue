<template>
  <span :id="id" role="tooltip" class="term-popover">
    <span class="term-popover__head">
      <span class="term-popover__term">{{ term.term }}</span>
      <span class="term-popover__reading">{{ term.reading }}</span>
    </span>
    <span class="term-popover__description">{{ term.description }}</span>
  </span>
</template>

<script setup lang="ts">
import type { SoccerTerm } from "@/types/formation";

// id は aria-describedby の参照先。親（TermAnnotatedText）が一意な値を採番して渡す
defineProps<{
  id: string;
  term: SoccerTerm;
}>();
</script>

<style scoped>
/*
  優位ポイントは <li>、総合判定理由は <p> の中に置かれるため、
  吹き出しもインライン要素（span）で組む。ブロック要素を混ぜると
  不正なHTML構造になり、ブラウザによって描画が崩れる
*/
.term-popover {
  position: absolute;
  z-index: 20;
  bottom: calc(100% + 8px);
  left: 0;
  display: block;
  width: max-content;
  max-width: min(280px, 72vw);
  box-sizing: border-box;
  border: 1px solid var(--color-border);
  border-radius: 10px;
  background: #ffffff;
  box-shadow: 0 6px 20px rgba(0, 0, 0, 0.16);
  padding: 10px 12px;
  text-align: left;
  white-space: normal;
  cursor: auto;
}

.term-popover__head {
  display: block;
  margin-bottom: 4px;
}

.term-popover__term {
  font-size: 13px;
  font-weight: 700;
  color: var(--color-text);
}

.term-popover__reading {
  margin-left: 6px;
  font-size: 11px;
  color: var(--color-text-sub);
}

.term-popover__description {
  display: block;
  font-size: 12px;
  line-height: 1.6;
  font-weight: 400;
  color: #374151;
}

/* 吹き出しの下向きしっぽ。枠線ぶんずらした白い三角を重ねて縁取りを作る */
.term-popover::before,
.term-popover::after {
  content: "";
  position: absolute;
  top: 100%;
  left: 16px;
  border: 7px solid transparent;
}

.term-popover::before {
  border-top-color: var(--color-border);
}

.term-popover::after {
  top: calc(100% - 1px);
  border-top-color: #ffffff;
}

.term-popover-fade-enter-active,
.term-popover-fade-leave-active {
  transition:
    opacity 0.15s ease,
    transform 0.15s ease;
}

.term-popover-fade-enter-from,
.term-popover-fade-leave-to {
  opacity: 0;
  transform: translateY(4px);
}

@media (prefers-reduced-motion: reduce) {
  .term-popover-fade-enter-active,
  .term-popover-fade-leave-active {
    transition: none;
  }
}
</style>
