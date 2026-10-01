<template>
  <div class="quiz-page">
    <PageHeader
      show-back-button
      title="理解度チェック"
      subtitle="配置と噛み合わせを答えて、解説で理解を確かめる"
    />
    <div class="quiz-page__body">
      <div class="quiz-page__column">
        <!-- データが足りず1問も作れない場合。クラッシュさせずに状況を伝える -->
        <p v-if="questions.length === 0" class="quiz-page__empty">
          出題できる問題がありません。フォーメーションのデータが追加されると出題できるようになります。
        </p>

        <template v-else-if="currentQuestion">
          <p class="quiz-page__progress">
            第 {{ currentIndex + 1 }} 問 / 全 {{ questions.length }} 問
            <span class="quiz-page__score">（正解 {{ correctCount }} 問）</span>
          </p>
          <progress
            class="quiz-page__progress-bar"
            :value="currentIndex + 1"
            :max="questions.length"
            aria-label="問題の進み具合"
          />

          <div
            ref="questionSection"
            class="quiz-page__question-section"
            tabindex="-1"
            :aria-label="`第${currentIndex + 1}問`"
          >
            <QuizQuestionCard
              :key="currentQuestion.id"
              :question="currentQuestion"
              :answered-choice-id="currentAnswer"
              @answer="onAnswer"
            />
          </div>

          <div v-if="currentAnswer !== null" class="quiz-page__actions">
            <button type="button" class="quiz-page__next-button" @click="goNext">
              {{ isLastQuestion ? "結果を見る" : "次の問題へ" }}
            </button>
          </div>
        </template>

        <div
          v-else
          ref="resultSection"
          class="quiz-page__result"
          tabindex="-1"
          aria-label="クイズの結果"
        >
          <h2 class="quiz-page__result-title">おつかれさま！</h2>
          <p class="quiz-page__result-score">
            {{ questions.length }} 問中 <strong>{{ correctCount }}</strong> 問 正解
          </p>
          <p class="quiz-page__result-comment">{{ resultComment }}</p>
          <div class="quiz-page__actions">
            <button type="button" class="quiz-page__retry-button" @click="restart()">
              もう一度挑戦する
            </button>
            <router-link to="/" class="quiz-page__result-link"
              >フォーメーションを比較する</router-link
            >
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, ref } from "vue";
import PageHeader from "@/components/PageHeader.vue";
import QuizQuestionCard from "@/components/QuizQuestionCard.vue";
import { formations } from "@/data/formations";
import { matchups } from "@/data/matchups";
import { buildQuiz } from "@/data/quiz";
import type { QuizQuestion } from "@/types/formation";

const questions = ref<QuizQuestion[]>([]);
const currentIndex = ref(0);
const questionSection = ref<HTMLDivElement | null>(null);
const resultSection = ref<HTMLDivElement | null>(null);
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

async function goNext(): Promise<void> {
  currentIndex.value += 1;
  await nextTick();
  (questionSection.value ?? resultSection.value)?.focus();
}

// 状態を個別に消すのではなく、すべて作り直す。
// 消し忘れた状態が次の挑戦へ持ち越されるのは、静かに誤る典型的な欠陥
async function restart(shouldFocus = true): Promise<void> {
  questions.value = buildQuiz(formations, matchups);
  currentIndex.value = 0;
  answers.value = {};
  if (shouldFocus) {
    await nextTick();
    questionSection.value?.focus();
  }
}

restart(false);
</script>

<style scoped>
.quiz-page__body {
  max-width: var(--width-wide);
  margin: 0 auto;
  padding: var(--space-lg) var(--gutter) var(--space-xl);
}

/* 本文の外枠は他画面と揃えて--width-wideだが、読み物としての1カラムは
   幅を絞ったほうが読みやすいため、内側だけ--width-narrowに収める */
.quiz-page__column {
  max-width: var(--width-narrow);
  margin: 0 auto;
}

.quiz-page__empty {
  border: 1px dashed var(--color-border);
  border-radius: var(--radius-lg);
  padding: var(--space-lg);
  font-size: var(--font-sm);
  line-height: var(--leading-relaxed);
  color: var(--color-text-sub);
  text-align: center;
}

.quiz-page__progress {
  margin: 0 0 var(--space-sm);
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  color: var(--color-text-sub);
}

.quiz-page__score {
  font-weight: var(--weight-normal);
}

.quiz-page__progress-bar {
  display: block;
  width: 100%;
  height: var(--space-sm);
  margin-bottom: var(--space-lg);
  accent-color: var(--color-primary);
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
  background: var(--color-primary);
  padding: 12px 24px;
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  color: var(--color-surface);
  cursor: pointer;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}

.quiz-page__next-button:hover,
.quiz-page__retry-button:hover {
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

.quiz-page__next-button:focus-visible,
.quiz-page__retry-button:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

.quiz-page__result {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  box-shadow: var(--shadow-md);
  padding: var(--space-xl) var(--space-lg);
  text-align: center;
}

.quiz-page__result-title {
  margin: 0 0 var(--space-sm);
  font-size: var(--font-lg);
  font-weight: var(--weight-semibold);
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
  line-height: var(--leading-relaxed);
  color: var(--color-text-sub);
}

.quiz-page__result .quiz-page__actions {
  justify-content: center;
}

.quiz-page__result-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 44px;
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  color: var(--color-primary);
}

@media (max-width: 640px) {
  .quiz-page__body {
    padding: var(--space-md) var(--gutter-mobile) var(--space-lg);
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
