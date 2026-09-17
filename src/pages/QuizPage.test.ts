import { describe, expect, it, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import QuizPage from "@/pages/QuizPage.vue";
import QuizQuestionCard from "@/components/QuizQuestionCard.vue";
import { buildQuiz } from "@/data/quiz";
import { formations } from "@/data/formations";
import { matchups } from "@/data/matchups";

const pushMock = vi.fn();
const backMock = vi.fn();

vi.mock("vue-router", () => ({
  useRouter: () => ({ push: pushMock, back: backMock }),
}));

const routerLinkStub = {
  props: ["to"],
  template: '<a :href="to"><slot /></a>',
};

function mountPage() {
  return mount(QuizPage, { global: { stubs: { RouterLink: routerLinkStub } } });
}

/** 現在の設問で、正解／不正解の選択肢を押す */
async function answerCurrent(wrapper: ReturnType<typeof mountPage>, correct: boolean) {
  const card = wrapper.findComponent(QuizQuestionCard);
  const question = card.props("question");
  const target = question.choices.find((c) => c.correct === correct);
  const button = card
    .findAll(".quiz-question-card__choice")
    .find((b) => b.text().includes(target!.label));
  await button!.trigger("click");
}

async function goNext(wrapper: ReturnType<typeof mountPage>) {
  await wrapper.find(".quiz-page__next-button").trigger("click");
}

/**
 * 画面が表示している全問数を読む。
 * テスト側に問題数を書くと、出題数の既定値を変えた瞬間にテストが嘘になる
 * （画面の表示と食い違ったまま緑になる）ため、画面の表示から取る
 */
function totalQuestions(wrapper: ReturnType<typeof mountPage>): number {
  const matched = wrapper.find(".quiz-page__progress").text().match(/全 (\d+) 問/);
  expect(matched, "進捗表示から全問数を読み取れること").not.toBeNull();
  return Number(matched![1]);
}

/** 全問を回答して結果画面まで進む。answerCorrectly で1問目の正誤を指定する */
async function playThrough(
  wrapper: ReturnType<typeof mountPage>,
  options: { firstAnswerCorrect?: boolean } = {},
): Promise<number> {
  const total = totalQuestions(wrapper);
  for (let i = 0; i < total; i += 1) {
    const correct = i === 0 ? (options.firstAnswerCorrect ?? true) : true;
    await answerCurrent(wrapper, correct);
    await goNext(wrapper);
  }
  return total;
}

describe("QuizPage", () => {
  beforeEach(() => {
    pushMock.mockClear();
    backMock.mockClear();
  });

  it("マウント時に1問目が表示される", () => {
    const wrapper = mountPage();

    expect(wrapper.findComponent(QuizQuestionCard).exists()).toBe(true);
    expect(wrapper.find(".quiz-page__progress").text()).toContain("第 1 問");
  });

  it("実際に出題される設問数を、進捗の分母として表示する", () => {
    const wrapper = mountPage();

    const displayed = totalQuestions(wrapper);
    expect(displayed).toBeGreaterThan(0);
    // 表示している分母と、実際に進める問題数が一致することは playThrough 側で担保する
    expect(displayed).toBe(buildQuiz(formations, matchups, { shuffle: (i) => [...i] }).length);
  });

  it("回答するまで「次の問題へ」は表示されない", () => {
    const wrapper = mountPage();

    expect(wrapper.find(".quiz-page__next-button").exists()).toBe(false);
  });

  it("回答すると正誤が表示され、「次の問題へ」が現れる", async () => {
    const wrapper = mountPage();

    await answerCurrent(wrapper, true);

    expect(wrapper.find(".quiz-question-card__verdict").text()).toBe("正解");
    expect(wrapper.find(".quiz-page__next-button").exists()).toBe(true);
  });

  it("正解すると正解数が増える", async () => {
    const wrapper = mountPage();

    expect(wrapper.find(".quiz-page__progress").text()).toContain("正解 0 問");
    await answerCurrent(wrapper, true);
    expect(wrapper.find(".quiz-page__progress").text()).toContain("正解 1 問");
  });

  it("誤答すると正解数は増えない", async () => {
    const wrapper = mountPage();

    await answerCurrent(wrapper, false);

    expect(wrapper.find(".quiz-page__progress").text()).toContain("正解 0 問");
  });

  it("「次の問題へ」で次の設問に進む", async () => {
    const wrapper = mountPage();
    const firstId = wrapper.findComponent(QuizQuestionCard).props("question").id;

    await answerCurrent(wrapper, true);
    await goNext(wrapper);

    expect(wrapper.find(".quiz-page__progress").text()).toContain("第 2 問");
    expect(wrapper.findComponent(QuizQuestionCard).props("question").id).not.toBe(firstId);
  });

  it("次の設問は未回答の状態で表示される（前の回答が持ち越されない）", async () => {
    const wrapper = mountPage();

    await answerCurrent(wrapper, true);
    await goNext(wrapper);

    expect(wrapper.findComponent(QuizQuestionCard).props("answeredChoiceId")).toBeNull();
    expect(wrapper.find(".quiz-question-card__result").exists()).toBe(false);
  });

  it("全問回答すると結果が表示され、正答数が出る", async () => {
    const wrapper = mountPage();

    const total = await playThrough(wrapper);

    const result = wrapper.find(".quiz-page__result");
    expect(result.exists()).toBe(true);
    expect(result.text()).toContain(`${total} 問中`);
    expect(result.find(".quiz-page__result-score strong").text()).toBe(String(total));
    expect(result.text()).toContain("全問正解");
    expect(wrapper.findComponent(QuizQuestionCard).exists()).toBe(false);
  });

  it("最終問題では「次の問題へ」ではなく「結果を見る」と表示される", async () => {
    const wrapper = mountPage();
    const total = totalQuestions(wrapper);

    for (let i = 0; i < total - 1; i += 1) {
      await answerCurrent(wrapper, true);
      await goNext(wrapper);
    }
    await answerCurrent(wrapper, true);

    expect(wrapper.find(".quiz-page__next-button").text()).toBe("結果を見る");
  });

  it("誤答も含めて最後まで進むと、正答数が実際の正解数と一致する", async () => {
    const wrapper = mountPage();

    // 1問目だけ誤答、残りは正解
    const total = await playThrough(wrapper, { firstAnswerCorrect: false });

    expect(wrapper.find(".quiz-page__result-score strong").text()).toBe(String(total - 1));
    expect(wrapper.find(".quiz-page__result").text()).not.toContain("全問正解");
  });

  // 状態のリセット漏れは静かに誤る典型。前回の回答が残ると正答数が嘘になる
  it("「もう一度挑戦する」で、1問目・正解0・未回答の状態へ完全に戻る", async () => {
    const wrapper = mountPage();

    await playThrough(wrapper);
    expect(wrapper.find(".quiz-page__result").exists()).toBe(true);

    await wrapper.find(".quiz-page__retry-button").trigger("click");

    expect(wrapper.find(".quiz-page__result").exists()).toBe(false);
    expect(wrapper.find(".quiz-page__progress").text()).toContain("第 1 問");
    expect(wrapper.find(".quiz-page__progress").text()).toContain("正解 0 問");
    expect(wrapper.findComponent(QuizQuestionCard).props("answeredChoiceId")).toBeNull();
    expect(wrapper.find(".quiz-question-card__result").exists()).toBe(false);
  });

  it("同じ設問に2回回答しても、回答は最初の1回で確定する", async () => {
    const wrapper = mountPage();
    const card = wrapper.findComponent(QuizQuestionCard);
    const question = card.props("question");

    await answerCurrent(wrapper, false);
    const wrongId = question.choices.find((c) => !c.correct)!.id;
    expect(card.props("answeredChoiceId")).toBe(wrongId);

    // disabled を無視して直接 emit しても、確定済みの回答は上書きされない
    await card.vm.$emit("answer", question.choices.find((c) => c.correct)!.id);

    expect(wrapper.findComponent(QuizQuestionCard).props("answeredChoiceId")).toBe(wrongId);
    expect(wrapper.find(".quiz-page__progress").text()).toContain("正解 0 問");
  });

  it("用語集画面へのリンクが'/quiz'ではなく'/glossary'を指す", () => {
    const wrapper = mountPage();

    expect(wrapper.find("a.quiz-page__glossary-link").attributes("href")).toBe("/glossary");
  });

  it("履歴が無い場合、「戻る」は一覧画面へ遷移する", async () => {
    window.history.replaceState({}, "");
    const wrapper = mountPage();

    await wrapper.find(".quiz-page__back-button").trigger("click");

    expect(pushMock).toHaveBeenCalledWith("/");
    expect(backMock).not.toHaveBeenCalled();
  });

  it("アプリ内遷移の履歴がある場合、「戻る」は履歴を1つ戻る", async () => {
    window.history.replaceState({ back: "/" }, "");
    const wrapper = mountPage();

    await wrapper.find(".quiz-page__back-button").trigger("click");

    expect(backMock).toHaveBeenCalledTimes(1);
    expect(pushMock).not.toHaveBeenCalled();
  });
});
