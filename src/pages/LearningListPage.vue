<template>
  <main class="learning-list-page">
    <PageHeader title="戦術を学ぶ" subtitle="陣形を選んで、選手の動きと判断の理由を見てみよう" />
    <div class="learning-list-page__body">
      <p class="learning-list-page__intro">
        各陣形の場面を5つの解説で再生します。有利になる条件だけでなく、相手の対応後に選び直す判断も学べます。
      </p>
      <div class="learning-list-page__grid">
        <router-link
          v-for="item in learningFormations"
          :key="item.formation.id"
          :to="`/formations/${item.formation.id}/learn`"
          class="learning-list-page__card"
          :aria-label="`${item.formation.name}を学ぶ：${item.lesson.scene.title}`"
        >
          <FormationMiniPitch :formation="item.formation" />
          <div class="learning-list-page__content">
            <h2>{{ item.formation.name }}</h2>
            <h3>{{ item.lesson.scene.title }}</h3>
            <p>{{ item.lesson.objective }}</p>
            <span class="learning-list-page__action">この陣形を学ぶ →</span>
          </div>
        </router-link>
      </div>
    </div>
  </main>
</template>

<script setup lang="ts">
import PageHeader from "@/components/PageHeader.vue";
import FormationMiniPitch from "@/components/FormationMiniPitch.vue";
import { formations } from "@/data/formations";
import { getFormationLesson } from "@/data/formationLessons";
const learningFormations = formations.flatMap((formation) => {
  const lesson = getFormationLesson(formation.id);
  return lesson ? [{ formation, lesson }] : [];
});
</script>

<style scoped>
.learning-list-page__body {
  max-width: var(--width-wide);
  margin: 0 auto;
  padding: var(--space-lg) var(--gutter) var(--space-2xl);
}
.learning-list-page__intro {
  color: var(--color-text-sub);
  margin-bottom: var(--space-lg);
}
.learning-list-page__grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: var(--space-lg);
}
.learning-list-page__card {
  display: flex;
  gap: var(--space-md);
  align-items: flex-start;
  padding: var(--space-lg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  color: var(--color-text);
  text-decoration: none;
}
.learning-list-page__card:hover {
  border-color: var(--color-primary);
}
.learning-list-page__card:focus-visible {
  outline: 3px solid var(--color-primary);
  outline-offset: 3px;
}
.learning-list-page__card :deep(svg) {
  width: 90px;
  height: 110px;
  flex: 0 0 90px;
}
.learning-list-page__content {
  min-width: 0;
}
.learning-list-page__content h2 {
  font-size: var(--font-xl);
  margin-bottom: var(--space-sm);
}
.learning-list-page__content h3 {
  font-size: var(--font-md);
  margin-bottom: var(--space-sm);
}
.learning-list-page__content p {
  font-size: var(--font-sm);
  color: var(--color-text-sub);
}
.learning-list-page__action {
  display: flex;
  align-items: center;
  min-height: 44px;
  margin-top: var(--space-sm);
  color: var(--color-primary);
  font-weight: var(--weight-semibold);
}
@media (max-width: 640px) {
  .learning-list-page__body {
    padding: var(--space-md);
  }
  .learning-list-page__grid {
    grid-template-columns: 1fr;
  }
  .learning-list-page__card {
    padding: var(--space-md);
  }
}
</style>
