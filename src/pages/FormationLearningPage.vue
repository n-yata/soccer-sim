<template>
  <main class="formation-learning-page">
    <router-link to="/learn" class="formation-learning-page__back">← 学習一覧へ</router-link>
    <template v-if="formation && lesson">
      <PageHeader
        :title="`${formation.name}を学ぶ`"
        subtitle="配置だけでなく、動きと判断の理由を学ぼう"
      />
      <nav class="formation-learning-page__switcher" aria-label="学ぶ陣形を切り替える">
        <router-link
          v-for="item in formations"
          :key="item.id"
          :to="`/formations/${item.id}/learn`"
          :aria-current="item.id === formation.id ? 'page' : undefined"
        >
          {{ item.name }}
        </router-link>
      </nav>
      <section
        class="formation-learning-page__overview"
        aria-labelledby="formation-learning-overview"
      >
        <div class="formation-learning-page__pitch">
          <FormationMiniPitch
            :formation="formation"
            :label="`${formation.name}の全11人の基本配置。攻撃方向は上。`"
          />
          <p>全体の基本配置 · 攻撃方向 ↑</p>
          <router-link :to="boardLink" class="formation-learning-page__board-link">
            この陣形をボードで試す →
          </router-link>
        </div>
        <div>
          <h2 id="formation-learning-overview">この陣形で学ぶこと</h2>
          <p>{{ formation.description }}</p>
          <p class="formation-learning-page__objective">{{ lesson.objective }}</p>
          <h3>優位が続かない場面も見る</h3>
          <p>{{ lesson.caution }}</p>
        </div>
      </section>
      <section class="formation-learning-page__roles" aria-labelledby="formation-learning-roles">
        <h2 id="formation-learning-roles">場面に登場する役割</h2>
        <ul>
          <li
            v-for="player in lesson.scene.players.filter((player) => player.team === 'attack')"
            :key="player.id"
          >
            青{{ player.number }}：{{ player.label }}
            <span
              >（基本配置の{{
                formation.positions.find((position) => position.id === player.formationPositionId)
                  ?.label
              }}）</span
            >
          </li>
        </ul>
        <p>
          下の図は局面を横向きに切り出したもの。番号は教材内の識別用です。陣形だけで勝敗や優位が決まるわけではありません。
        </p>
      </section>
      <TacticalReplay :key="formation.id" :scene="lesson.scene" :description="lesson.objective" />
      <p class="formation-learning-page__board-cta">
        <router-link :to="boardLink" class="formation-learning-page__board-link">
          この陣形をボードで試す →
        </router-link>
      </p>
      <details class="formation-learning-page__terms">
        <summary>この教材の用語を確認する</summary>
        <dl>
          <div v-for="term in lessonTerms" :key="term.id">
            <dt>{{ term.term }}</dt>
            <dd>{{ term.description }}</dd>
          </div>
        </dl>
        <router-link to="/glossary">用語集ですべての言葉を見る →</router-link>
      </details>
    </template>
    <div v-else role="alert" class="formation-learning-page__error">
      <h1>陣形の教材が見つかりません</h1>
      <p>一覧から学びたいフォーメーションを選び直してください。</p>
    </div>
  </main>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useRoute } from "vue-router";
import FormationMiniPitch from "@/components/FormationMiniPitch.vue";
import PageHeader from "@/components/PageHeader.vue";
import TacticalReplay from "@/components/TacticalReplay.vue";
import { formations, getFormationById } from "@/data/formations";
import { getFormationLesson } from "@/data/formationLessons";
import { soccerTerms } from "@/data/soccerTerms";

const route = useRoute();
const formationId = computed(() =>
  typeof route.params.formationId === "string" ? route.params.formationId : "",
);
const formation = computed(() => getFormationById(formationId.value));
const lesson = computed(() => getFormationLesson(formationId.value));
// 学んだ陣形をそのまま自分で動かせるよう、ボードを青チームにこの陣形を選んだ状態で開く。
const boardLink = computed(() => ({ path: "/board", query: { blue: formationId.value } }));
const lessonTerms = computed(() => {
  if (!lesson.value) return [];
  const text = [
    lesson.value.objective,
    lesson.value.caution,
    lesson.value.scene.title,
    ...lesson.value.scene.steps.flatMap((step) => [
      step.title,
      step.explanation,
      step.observation,
      step.advantage,
    ]),
  ].join(" ");
  return soccerTerms.filter((term) => text.includes(term.term));
});
</script>

<style scoped>
.formation-learning-page__terms {
  margin-top: var(--space-lg);
}
.formation-learning-page__terms summary {
  display: list-item;
  min-height: 44px;
  line-height: 44px;
  cursor: pointer;
}
.formation-learning-page__terms dt {
  font-weight: var(--weight-semibold);
  margin-top: var(--space-md);
}
.formation-learning-page__terms dd {
  margin: var(--space-xs) 0 var(--space-md);
  line-height: var(--leading-normal);
  color: var(--color-text-sub);
}
.formation-learning-page__board-link {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  color: var(--color-primary);
}
.formation-learning-page__board-cta {
  margin: var(--space-md) 0 0;
}
.formation-learning-page__terms a {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  color: var(--color-primary);
}
.formation-learning-page {
  max-width: var(--width-wide);
  margin: 0 auto;
  padding: var(--space-lg) var(--gutter) var(--space-xl);
}
.formation-learning-page__back,
.formation-learning-page__switcher a {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  color: var(--color-primary);
}
.formation-learning-page__switcher {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-sm);
  margin: var(--space-lg) 0;
}
.formation-learning-page__switcher a {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-pill);
  padding: 0 var(--space-md);
  background: var(--color-surface);
  text-decoration: none;
}
.formation-learning-page__switcher a[aria-current="page"] {
  background: var(--color-primary);
  color: var(--color-surface);
}
.formation-learning-page__overview {
  display: grid;
  grid-template-columns: 180px minmax(0, 1fr);
  gap: var(--space-lg);
  align-items: center;
}
.formation-learning-page__pitch p {
  font-size: var(--font-xs);
  text-align: center;
}
.formation-learning-page h2 {
  font-size: var(--font-lg);
  margin: 0 0 var(--space-sm);
}
.formation-learning-page h3 {
  font-size: var(--font-md);
  margin: var(--space-md) 0 var(--space-xs);
}
.formation-learning-page p {
  line-height: var(--leading-normal);
  color: var(--color-text-sub);
}
.formation-learning-page .formation-learning-page__objective {
  color: var(--color-text);
  font-weight: var(--weight-semibold);
}
.formation-learning-page__roles {
  border-top: 1px solid var(--color-border);
  margin-top: var(--space-lg);
  padding: var(--space-lg) 0;
}
.formation-learning-page__roles ul {
  padding-left: var(--space-lg);
  line-height: var(--leading-normal);
}
.formation-learning-page__roles span {
  color: var(--color-text-sub);
}
.formation-learning-page a:focus-visible {
  outline: 3px solid var(--color-text);
  outline-offset: 3px;
}
@media (max-width: 640px) {
  .formation-learning-page {
    padding: var(--space-md) var(--gutter-mobile);
  }
  .formation-learning-page__overview {
    grid-template-columns: 1fr;
  }
  .formation-learning-page__pitch {
    width: 160px;
    margin: 0 auto;
  }
}
</style>
