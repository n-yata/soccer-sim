<template>
  <svg
    viewBox="0 0 100 100"
    class="formation-mini-pitch"
    :role="label ? 'img' : undefined"
    :aria-label="label"
    :aria-hidden="label ? undefined : 'true'"
  >
    <rect x="0" y="0" width="100" height="100" class="formation-mini-pitch__field" />
    <line x1="0" y1="50" x2="100" y2="50" class="formation-mini-pitch__line" />
    <circle cx="50" cy="50" r="9" class="formation-mini-pitch__line-shape" />
    <circle
      v-for="position in formation.positions"
      :key="position.id"
      :cx="position.x"
      :cy="100 - position.y"
      r="3.2"
      class="formation-mini-pitch__player"
    />
  </svg>
</template>

<script setup lang="ts">
import type { Formation } from "@/types/formation";

// cy = 100 - y でピッチ座標系（左下原点・yが大きいほど攻撃方向）を
// SVG座標系（左上原点・下方向が正）に変換し、攻撃方向を画面の上に描画する
//
// label: 省略時は装飾扱い（aria-hidden）。一覧カードでは名称・説明文が隣にテキストで
// 存在するため、図を読み上げても冗長になるだけなので省略する。
// クイズの陣形識別（FR-12）では図そのものが設問の内容であり、読み上げから
// 完全に消えると設問が成立しないため、呼び出し側がラベルを与える。
defineProps<{
  formation: Formation;
  label?: string;
}>();
</script>

<style scoped>
.formation-mini-pitch {
  width: 100%;
  height: auto;
  display: block;
}

.formation-mini-pitch__field {
  fill: var(--color-pitch);
}

.formation-mini-pitch__line,
.formation-mini-pitch__line-shape {
  fill: none;
  stroke: #ffffff;
  stroke-opacity: 0.7;
  stroke-width: 0.8;
}

.formation-mini-pitch__player {
  fill: var(--color-text);
  stroke: #ffffff;
  stroke-width: 1;
}
</style>
