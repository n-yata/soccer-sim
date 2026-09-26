<template>
  <header class="app-header">
    <div class="app-header__bar">
      <router-link to="/" class="app-header__brand" @click="closeMenu">
        ⚽ フォーメーションラボ
      </router-link>
      <button
        type="button"
        class="app-header__toggle"
        :aria-expanded="isMenuOpen"
        aria-controls="app-header-nav"
        @click="isMenuOpen = !isMenuOpen"
      >
        <span aria-hidden="true">☰</span>
        <span class="app-header__toggle-label">メニュー</span>
      </button>
      <nav
        id="app-header-nav"
        class="app-header__nav"
        :class="{ 'app-header__nav--open': isMenuOpen }"
      >
        <router-link
          to="/"
          class="app-header__link"
          :aria-current="isActive('formation-list')"
          @click="closeMenu"
        >
          一覧
        </router-link>
        <router-link
          to="/matrix"
          class="app-header__link"
          :aria-current="isActive('matrix')"
          @click="closeMenu"
        >
          相性表
        </router-link>
        <router-link
          to="/league"
          class="app-header__link"
          :aria-current="isActive('league')"
          @click="closeMenu"
        >
          🏆 リーグ戦
        </router-link>
        <router-link
          v-if="showCupLink"
          to="/cup"
          class="app-header__link"
          :aria-current="isActive('cup')"
          @click="closeMenu"
        >
          🥇 カップ戦
        </router-link>
        <router-link
          to="/quiz"
          class="app-header__link"
          :aria-current="isActive('quiz')"
          @click="closeMenu"
        >
          ✏️ 理解度チェック
        </router-link>
        <router-link
          to="/glossary"
          class="app-header__link"
          :aria-current="isActive('glossary')"
          @click="closeMenu"
        >
          📖 用語集
        </router-link>
      </nav>
    </div>
  </header>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { useRoute } from "vue-router";

// カップ戦導線の出し分け（formations.length === CUP_REQUIRED_FORMATION_COUNT）はデータへの
// 判断であり、components/はdata/配下の静的データ定義に直接依存できない
// （repository-structure.md「components/の依存関係」）。呼び出し元（App.vue）が判定して渡す
defineProps<{ showCupLink: boolean }>();

const route = useRoute();
const isMenuOpen = ref(false);

function isActive(name: string): "page" | undefined {
  return route.name === name ? "page" : undefined;
}

function closeMenu(): void {
  isMenuOpen.value = false;
}
</script>

<style scoped>
.app-header {
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  position: sticky;
  top: 0;
  z-index: 10;
}

.app-header__bar {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  padding: var(--space-sm) var(--space-2xl);
}

.app-header__brand {
  font-size: var(--font-md);
  font-weight: 700;
  color: var(--color-text);
  text-decoration: none;
  white-space: nowrap;
}

.app-header__toggle {
  display: none;
  align-items: center;
  gap: var(--space-xs);
  margin-left: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  background: var(--color-surface);
  padding: var(--space-xs) var(--space-sm);
  font-size: var(--font-sm);
  font-weight: 700;
  color: var(--color-text-muted);
  cursor: pointer;
}

.app-header__nav {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  margin-left: auto;
  flex-wrap: wrap;
}

.app-header__link {
  font-size: var(--font-sm);
  font-weight: 700;
  color: var(--color-text-sub);
  text-decoration: none;
  white-space: nowrap;
  padding: var(--space-xs) 0;
  border-bottom: 2px solid transparent;
}

.app-header__link:hover {
  color: var(--color-text);
}

.app-header__link[aria-current="page"] {
  color: var(--color-primary);
  border-bottom-color: var(--color-primary);
}

@media (max-width: 640px) {
  .app-header__bar {
    padding: var(--space-sm) var(--space-md);
    flex-wrap: wrap;
  }

  .app-header__toggle {
    display: inline-flex;
  }

  .app-header__nav {
    display: none;
    width: 100%;
    flex-direction: column;
    align-items: flex-start;
    gap: var(--space-sm);
    margin-left: 0;
    padding-top: var(--space-sm);
  }

  .app-header__nav--open {
    display: flex;
  }
}
</style>
