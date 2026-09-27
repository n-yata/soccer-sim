<template>
  <div class="quiz-page">
    <PageHeader show-back-button title="理解度チェック" />
    <div class="quiz-page__body">
      <!-- データが足りず1問も作れない場合。クラッシュさせずに状況を伝える -->
      <p v-if="questions.length === 0" class="quiz-page__empty">
        出題できる問題がありません。フォーメーションのデータが追加されると出題できるようになります。
      </p>

      <template v-else-if="currentQuestion">
        <p class="quiz-page__progress">
          第 {{ currentIndex + 1 }} 問 / 全 {{ questions.length }} 問
          <span class="quiz-page__score">（正解 {{ correctCount }} 問）</span>
        </p>

        <QuizQuestionCard
          :key="currentQuestion.id"
          :question="currentQuestion"
          :answered-choice-id="currentAnswer"
          @answer="onAnswer"
        />

        <div v-if="currentAnswer !== null" class="quiz-page__actions">
          <button type="button" class="quiz-page__next-button" @click="goNext">
            {{ isLastQuestion ? "結果を見る" : "次の問題へ" }}
          </button>
        </div>
      </template>

      <div v-else class="quiz-page__result">
        <h2 class="quiz-page__result-title">おつかれさま！</h2>
        <p class="quiz-page__result-score">
          {{ questions.length }} 問中 <strong>{{ correctCount }}</strong> 問 正解
        </p>
        <p class="quiz-page__result-comment">{{ resultComment }}</p>
        <div class="quiz-page__actions">
          <button type="button" class="quiz-page__retry-button" @click="restart">
            もう一度挑戦する
          </button>
          <router-link to="/" class="quiz-page__result-link">一覧画面へ戻る</router-link>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import PageHeader from "@/components/PageHeader.vue";
import QuizQuestionCard from "@/components/QuizQuestionCard.vue";
import { formations } from "@/data/formations";
import { matchups } from "@/data/matchups";
import { buildQuiz } from "@/data/quiz";
import type { QuizQuestion } from "@/types/formation";

const questions = ref<QuizQuestion[]>([]);
const currentIndex = ref(0);
// 設問id -> 選んだ選択肢id。配列のindexではなくidで持つことで、
// 再挑戦で出題順が変わっても前回の回答が混ざらない
const answers = ref<Record<string, string>>({});

const currentQuestion = computed<QuizQuestion | undefined>(
  () => questions.value[currentIndex.value],
);

const currentAnswer = computed<string | null>(() => {
  const question = currentQuestion.value;
  if (!question) return null;
  return answers.value[question.id] ?? null;
});

const isLastQuestion = computed(() => currentIndex.value === questions.value.length - 1);

const correctCount = computed(
  () =>
    questions.value.filter((question) => {
      const answeredId = answers.value[question.id];
      if (answeredId === undefined) return false;
      return question.choices.some((choice) => choice.id === answeredId && choice.correct);
    }).length,
);

const resultComment = computed(() => {
  const total = questions.value.length;
  if (total === 0) return "";
  const ratio = correctCount.value / total;
  if (ratio === 1) return "全問正解。フォーメーションの噛み合わせをしっかり掴めています";
  if (ratio >= 0.6) return "いい調子。間違えた問題の解説をもう一度読んでみましょう";
  return "比較画面で解説を読み直してから、もう一度挑戦してみましょう";
});

function onAnswer(choiceId: string): void {
  const question = currentQuestion.value;
  if (!question) return;
  // 1問につき確定は1回だけ。確定後の上書きを防ぐ（ボタンのdisabledだけに頼らない）
  if (answers.value[question.id] !== undefined) return;
  answers.value = { ...answers.value, [question.id]: choiceId };
}

function goNext(): void {
  currentIndex.value += 1;
}

// 状態を個別に消すのではなく、すべて作り直す。
// 消し忘れた状態が次の挑戦へ持ち越されるのは、静かに誤る典型的な欠陥
function restart(): void {
  questions.value = buildQuiz(formations, matchups);
  currentIndex.value = 0;
  answers.value = {};
}

restart();
</script>

<style scoped>
.quiz-page__body {
  max-width: 640px;
  margin: 0 auto;
  padding: var(--space-lg) var(--space-md) var(--space-xl);
}

.quiz-page__empty {
  border: 1px dashed var(--color-border);
  border-radius: var(--radius-card);
  padding: var(--space-lg);
  font-size: 14px;
  line-height: 1.8;
  color: var(--color-text-sub);
  text-align: center;
}

.quiz-page__progress {
  margin: 0 0 var(--space-sm);
  font-size: var(--font-sm);
  font-weight: 700;
  color: var(--color-text-sub);
}

.quiz-page__score {
  font-weight: 400;
}

.quiz-page__actions {
  display: flex;
  align-items: center;
  gap: var(--space-md);
  margin-top: var(--space-md);
  flex-wrap: wrap;
}

.quiz-page__next-button,
.quiz-page__retry-button {
  min-height: 44px;
  box-sizing: border-box;
  border: 0;
  border-radius: var(--radius-pill);
  background: linear-gradient(90deg, var(--color-primary), var(--color-primary-end));
  padding: 12px 24px;
  font-size: 14px;
  font-weight: 700;
  color: #ffffff;
  cursor: pointer;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}

.quiz-page__next-button:hover,
.quiz-page__retry-button:hover {
  transform: translateY(-1px);
  box-shadow: var(--shadow-card);
}

.quiz-page__next-button:focus-visible,
.quiz-page__retry-button:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

.quiz-page__result {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  background: var(--color-surface);
  box-shadow: var(--shadow-card);
  padding: var(--space-xl) var(--space-lg);
  text-align: center;
}

.quiz-page__result-title {
  margin: 0 0 var(--space-sm);
  font-size: 20px;
  font-weight: 700;
  color: var(--color-text);
}

.quiz-page__result-score {
  margin: 0 0 var(--space-sm);
  font-size: var(--font-md);
  color: var(--color-text);
}

.quiz-page__result-score strong {
  font-size: var(--font-2xl);
  color: var(--color-primary);
}

.quiz-page__result-comment {
  margin: 0 0 var(--space-sm);
  font-size: var(--font-sm);
  line-height: 1.8;
  color: var(--color-text-sub);
}

.quiz-page__result .quiz-page__actions {
  justify-content: center;
}

.quiz-page__result-link {
  font-size: var(--font-sm);
  font-weight: 700;
  color: var(--color-primary);
}

@media (max-width: 480px) {
  .quiz-page__body {
    padding: var(--space-md) var(--space-sm) var(--space-lg);
  }

  .quiz-page__actions {
    flex-direction: column;
    align-items: stretch;
  }

  .quiz-page__next-button,
  .quiz-page__retry-button {
    width: 100%;
  }
}

@media (prefers-reduced-motion: reduce) {
  .quiz-page__next-button,
  .quiz-page__retry-button {
    transition: none;
  }

  .quiz-page__next-button:hover,
  .quiz-page__retry-button:hover {
    transform: none;
  }
}
</style>
