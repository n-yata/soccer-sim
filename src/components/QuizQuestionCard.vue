<template>
  <div class="quiz-question-card">
    <p class="quiz-question-card__prompt">
      <TermAnnotatedText :text="question.prompt" />
    </p>

    <div v-if="question.formation" class="quiz-question-card__pitch">
      <FormationMiniPitch
        :formation="question.formation"
        label="選手配置図。この配置がどのフォーメーションかを選択肢から選んでください"
      />
    </div>

    <ul class="quiz-question-card__choices">
      <li v-for="choice in question.choices" :key="choice.id">
        <button
          type="button"
          class="quiz-question-card__choice"
          :class="choiceClass(choice)"
          :disabled="isAnswered"
          @click="emit('answer', choice.id)"
        >
          <!--
            正誤は色だけで示さない。色覚特性や白黒印刷でも区別できるよう記号を添える
            （aria-hidden を付けて、読み上げは下の marker テキストに一本化する）
          -->
          <span v-if="isAnswered" class="quiz-question-card__marker" aria-hidden="true">
            {{ markerSymbol(choice) }}
          </span>
          <span>{{ choice.label }}</span>
          <span v-if="isAnswered && markerText(choice)" class="quiz-question-card__sr-only">
            {{ markerText(choice) }}
          </span>
        </button>
      </li>
    </ul>

    <!--
      role="status" で、回答後に現れる正誤と解説が支援技術へ通知されるようにする
      （視覚的にはボタンの下に出るだけなので、通知が無いと結果に気づけない）
    -->
    <div v-if="isAnswered" class="quiz-question-card__result" role="status">
      <p
        class="quiz-question-card__verdict"
        :class="
          isCorrect
            ? 'quiz-question-card__verdict--correct'
            : 'quiz-question-card__verdict--incorrect'
        "
      >
        {{ isCorrect ? "正解" : "不正解" }}
      </p>
      <p class="quiz-question-card__explanation">
        <TermAnnotatedText :text="question.explanation" />
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import FormationMiniPitch from "@/components/FormationMiniPitch.vue";
import TermAnnotatedText from "@/components/TermAnnotatedText.vue";
import type { QuizChoice, QuizQuestion } from "@/types/formation";

const props = defineProps<{
  question: QuizQuestion;
  // 回答済みの選択肢id。null なら未回答。親（QuizPage）が保持する
  answeredChoiceId: string | null;
}>();

const emit = defineEmits<{
  answer: [choiceId: string];
}>();

const isAnswered = computed(() => props.answeredChoiceId !== null);

const isCorrect = computed(() => {
  if (props.answeredChoiceId === null) return false;
  return props.question.choices.some((c) => c.id === props.answeredChoiceId && c.correct);
});

function isSelected(choice: QuizChoice): boolean {
  return choice.id === props.answeredChoiceId;
}

// 回答後は「正解がどれだったか」を必ず示す。選んだものが誤りだった場合に
// 正解が分からないままだと、間違いから学べない
function choiceClass(choice: QuizChoice): string[] {
  if (!isAnswered.value) return [];
  const classes: string[] = [];
  if (choice.correct) classes.push("quiz-question-card__choice--correct");
  if (isSelected(choice) && !choice.correct) classes.push("quiz-question-card__choice--incorrect");
  return classes;
}

function markerSymbol(choice: QuizChoice): string {
  if (choice.correct) return "○";
  if (isSelected(choice)) return "×";
  return "";
}

function markerText(choice: QuizChoice): string {
  if (choice.correct) return isSelected(choice) ? "（正解。あなたの回答）" : "（正解）";
  if (isSelected(choice)) return "（不正解。あなたの回答）";
  return "";
}
</script>

<style scoped>
.quiz-question-card {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-card);
  background: #ffffff;
  box-shadow: var(--shadow-card);
  padding: 20px;
}

.quiz-question-card__prompt {
  margin: 0 0 16px;
  font-size: var(--font-md);
  font-weight: var(--weight-semibold);
  line-height: var(--leading-relaxed);
  color: var(--color-text);
}

.quiz-question-card__pitch {
  width: 180px;
  margin: 0 auto 16px;
}

.quiz-question-card__choices {
  list-style: none;
  display: grid;
  gap: 8px;
  margin: 0;
  padding: 0;
}

.quiz-question-card__choice {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  min-height: 44px;
  box-sizing: border-box;
  border: 2px solid var(--color-border);
  border-radius: 10px;
  background: #ffffff;
  padding: 12px 14px;
  font-size: var(--font-sm);
  font-weight: var(--weight-medium);
  text-align: left;
  color: var(--color-text);
  cursor: pointer;
  transition:
    border-color 0.2s ease,
    background-color 0.2s ease,
    color 0.2s ease;
}

.quiz-question-card__choice:hover:not(:disabled) {
  border-color: var(--color-primary);
  background: #f0fdf4;
}

.quiz-question-card__choice:focus-visible {
  outline: 3px solid var(--color-accent);
  outline-offset: 2px;
}

.quiz-question-card__choice:disabled {
  cursor: default;
}

.quiz-question-card__choice--correct {
  border-color: #15803d;
  background: #f0fdf4;
  color: #14532d;
}

.quiz-question-card__choice--incorrect {
  border-color: #b91c1c;
  background: #fef2f2;
  color: #7f1d1d;
}

.quiz-question-card__marker {
  font-size: var(--font-md);
}

.quiz-question-card__result {
  margin-top: 16px;
  border-top: 1px solid var(--color-border);
  padding-top: 14px;
  animation: quiz-question-card-fade-in 0.3s ease-out both;
}

@keyframes quiz-question-card-fade-in {
  from {
    opacity: 0;
    transform: translateY(4px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@media (prefers-reduced-motion: reduce) {
  .quiz-question-card__choice {
    transition: none;
  }

  .quiz-question-card__result {
    animation: none;
  }
}

.quiz-question-card__verdict {
  margin: 0 0 6px;
  font-size: var(--font-md);
  font-weight: var(--weight-semibold);
}

.quiz-question-card__verdict--correct {
  color: #15803d;
}

.quiz-question-card__verdict--incorrect {
  color: #b91c1c;
}

.quiz-question-card__explanation {
  margin: 0;
  font-size: var(--font-sm);
  line-height: var(--leading-relaxed);
  color: #374151;
}

/* 視覚的には隠すが読み上げには残す */
.quiz-question-card__sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  margin: -1px;
  border: 0;
  padding: 0;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
}
</style>
