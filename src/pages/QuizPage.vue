<template>
  <div class="quiz-page">
    <div class="quiz-page__header">
      <button type="button" class="quiz-page__back-button" @click="goBack">← 戻る</button>
      <h1 class="quiz-page__title">理解度チェック</h1>
      <router-link to="/glossary" class="quiz-page__glossary-link"> 📖 用語集 </router-link>
    </div>

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
</template>

<script setup lang="ts">
import { computed, ref } from "vue";
import { useRouter } from "vue-router";
import QuizQuestionCard from "@/components/QuizQuestionCard.vue";
import { formations } from "@/data/formations";
import { matchups } from "@/data/matchups";
import { buildQuiz } from "@/data/quiz";
import type { QuizQuestion } from "@/types/formation";

const router = useRouter();

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

// vue-routerのhistoryモードはhistory.stateに前後のルートパスを持つため、
// アプリ内遷移の履歴があるときだけrouter.back()で遷移元へ戻す。
// 履歴が無い（URL直打ち等）場合のみ一覧画面へ固定する
function goBack(): void {
  if (window.history.state?.back) {
    router.back();
  } else {
    router.push("/");
  }
}
</script>

<style scoped>
.quiz-page {
  max-width: 640px;
  margin: 0 auto;
  padding: 24px 20px 40px;
}

.quiz-page__header {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 16px;
}

.quiz-page__back-button {
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: #ffffff;
  box-shadow: var(--shadow-card);
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 700;
  color: #374151;
  cursor: pointer;
}

.quiz-page__title {
  margin: 0;
  font-size: 24px;
  font-weight: 700;
  color: var(--color-text);
}

.quiz-page__glossary-link {
  margin-left: auto;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: #ffffff;
  box-shadow: var(--shadow-card);
  padding: 8px 16px;
  font-size: 13px;
  font-weight: 700;
  color: #374151;
  text-decoration: none;
}

.quiz-page__empty {
  border: 1px dashed var(--color-border);
  border-radius: var(--radius-card);
  padding: 24px;
  font-size: 14px;
  line-height: 1.8;
  color: var(--color-text-sub);
  text-align: center;
}

.quiz-page__progress {
  margin: 0 0 12px;
  font-size: 13px;
  font-weight: 700;
  color: var(--color-text-sub);
}

.quiz-page__score {
  font-weight: 400;
}

.quiz-page__actions {
  display: flex;
  align-items: center;
  gap: 16px;
  margin-top: 16px;
}

.quiz-page__next-button,
.quiz-page__retry-button {
  border: 0;
  border-radius: 999px;
  background: linear-gradient(90deg, var(--color-primary), var(--color-primary-end));
  padding: 12px 24px;
  font-size: 14px;
  font-weight: 700;
  color: #ffffff;
  cursor: pointer;
}

.quiz-page__next-button:focus-visible,
.quiz-page__retry-button:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

.quiz-page__result {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  background: #ffffff;
  box-shadow: var(--shadow-card);
  padding: 32px 24px;
  text-align: center;
}

.quiz-page__result-title {
  margin: 0 0 12px;
  font-size: 20px;
  font-weight: 700;
  color: var(--color-text);
}

.quiz-page__result-score {
  margin: 0 0 8px;
  font-size: 16px;
  color: var(--color-text);
}

.quiz-page__result-score strong {
  font-size: 28px;
  color: var(--color-primary);
}

.quiz-page__result-comment {
  margin: 0 0 8px;
  font-size: 13px;
  line-height: 1.8;
  color: var(--color-text-sub);
}

.quiz-page__result .quiz-page__actions {
  justify-content: center;
}

.quiz-page__result-link {
  font-size: 13px;
  font-weight: 700;
  color: var(--color-primary);
}
</style>
