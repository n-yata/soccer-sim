<template>
  <header class="app-header">
    <div class="app-header__bar">
      <router-link to="/" class="app-header__brand" @click="closeMenu">
        <AppIcon :icon="Goal" size="md" />
        フォーメーションラボ
      </router-link>
      <button
        type="button"
        class="app-header__toggle"
        :aria-expanded="isMenuOpen"
        aria-controls="app-header-nav"
        @click="isMenuOpen = !isMenuOpen"
      >
        <AppIcon :icon="Menu" />
        <span class="app-header__toggle-label">メニュー</span>
      </button>
      <nav
        id="app-header-nav"
        aria-label="主な画面"
        class="app-header__nav"
        :class="{ 'app-header__nav--open': isMenuOpen }"
      >
        <router-link
          to="/"
          class="app-header__link"
          :aria-current="isActive('formation-list')"
          @click="closeMenu"
        >
          フォーメーションを選ぶ
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
          to="/board"
          class="app-header__link"
          :aria-current="isActive('free-layout-board')"
          @click="closeMenu"
        >
          自由配置ボード
        </router-link>
        <router-link
          to="/quiz"
          class="app-header__link"
          :aria-current="isActive('quiz')"
          @click="closeMenu"
        >
          <AppIcon :icon="PencilLine" />
          理解度チェック
        </router-link>
        <router-link
          to="/glossary"
          class="app-header__link"
          :aria-current="isActive('glossary')"
          @click="closeMenu"
        >
          <AppIcon :icon="BookOpen" />
          用語集
        </router-link>
      </nav>
    </div>
  </header>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { useRoute } from "vue-router";
import { BookOpen, Goal, Menu, PencilLine } from "@lucide/vue";
import AppIcon from "./AppIcon.vue";

const route = useRoute();
const isMenuOpen = ref(false);

function isActive(name: string): "page" | "location" | undefined {
  if (name === "formation-list" && route.name === "comparison") return "location";
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
  padding: 0 var(--gutter);
  position: sticky;
  top: 0;
  z-index: 10;
}

.app-header__bar {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  max-width: var(--width-wide);
  margin: 0 auto;
  padding: var(--space-sm) 0;
}

.app-header__brand {
  display: inline-flex;
  min-height: 44px;
  align-items: center;
  gap: var(--space-xs);
  font-size: var(--font-md);
  font-weight: var(--weight-semibold);
  color: var(--color-text);
  text-decoration: none;
  white-space: nowrap;
}

.app-header__toggle {
  display: none;
  align-items: center;
  gap: var(--space-xs);
  min-height: 44px;
  margin-left: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  background: var(--color-surface);
  padding: var(--space-xs) var(--space-sm);
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  color: var(--color-text-muted);
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.app-header__toggle:hover {
  background: var(--color-surface-hover);
}

.app-header__nav {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  margin-left: auto;
  flex-wrap: wrap;
}

.app-header__link {
  display: inline-flex;
  min-height: 44px;
  align-items: center;
  gap: var(--space-xs);
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  color: var(--color-text-sub);
  text-decoration: none;
  white-space: nowrap;
  padding: var(--space-xs) 0;
  border-bottom: 2px solid transparent;
  transition:
    color 0.15s ease,
    border-bottom-color 0.15s ease;
}

.app-header__link:hover {
  color: var(--color-text);
}

.app-header__link[aria-current] {
  color: var(--color-primary);
  border-bottom-color: var(--color-primary);
}

@media (max-width: 640px) {
  .app-header {
    padding: 0 var(--gutter-mobile);
  }

  .app-header__bar {
    padding: var(--space-sm) 0;
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

  .app-header__link {
    min-height: 44px;
    width: 100%;
  }
}

@media (prefers-reduced-motion: reduce) {
  .app-header__toggle,
  .app-header__link {
    transition: none;
  }
}
</style>
