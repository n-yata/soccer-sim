<template>
  <!-- 装飾用途が既定。意味を持つ場合は呼び出し元のbutton/aにaria-labelを置く -->
  <component :is="icon" class="app-icon" :class="`app-icon--${size}`" aria-hidden="true" focusable="false" />
</template>

<script setup lang="ts">
import type { LucideIcon } from "@lucide/vue";

withDefaults(defineProps<{ icon: LucideIcon; size?: "sm" | "md" | "lg" }>(), {
  size: "md",
});
</script>

<style scoped>
.app-icon {
  flex: none;
}

.app-icon--sm {
  width: var(--icon-sm);
  height: var(--icon-sm);
}

.app-icon--md {
  width: var(--icon-md);
  height: var(--icon-md);
}

.app-icon--lg {
  width: var(--icon-lg);
  height: var(--icon-lg);
}
</style>
