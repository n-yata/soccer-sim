import { describe, expect, it } from "vitest";
import { mount } from "@vue/test-utils";
import QuizQuestionCard from "@/components/QuizQuestionCard.vue";
import FormationMiniPitch from "@/components/FormationMiniPitch.vue";
import { formations } from "@/data/formations";
import type { QuizQuestion } from "@/types/formation";

const edgeQuestion: QuizQuestion = {
  id: "edge-sample",
  kind: "edge",
  prompt: "4-4-2 と 4-2-3-1 が対戦したとき、総合的に優位なのはどちらでしょう？",
  choices: [
    { id: "A", label: "4-4-2がやや優位", correct: false },
    { id: "B", label: "4-2-3-1がやや優位", correct: true },
    { id: "even", label: "互角", correct: false },
  ],
  explanation: "4-2-3-1は中盤が実質5枚と4-4-2の4枚を上回り、中盤の主導権を握りやすい",
};

const formationQuestion: QuizQuestion = {
  id: "formation-sample",
  kind: "formation",
  prompt: "この選手配置は、どのフォーメーションでしょう？",
  choices: [
    { id: "4-4-2", label: "4-4-2", correct: true },
    { id: "4-3-3", label: "4-3-3", correct: false },
  ],
  explanation: "4-4-2の説明文",
  formation: formations[0],
};

function mountCard(question: QuizQuestion, answeredChoiceId: string | null = null) {
  return mount(QuizQuestionCard, { props: { question, answeredChoiceId } });
}

describe("QuizQuestionCard", () => {
  it("設問文と選択肢をすべて表示する", () => {
    const wrapper = mountCard(edgeQuestion);

    expect(wrapper.find(".quiz-question-card__prompt").text()).toContain(
      "総合的に優位なのはどちらでしょう",
    );
    const labels = wrapper.findAll(".quiz-question-card__choice").map((b) => b.text());
    expect(labels).toHaveLength(3);
    expect(labels.join("|")).toContain("4-2-3-1がやや優位");
    expect(labels.join("|")).toContain("互角");
  });

  it("未回答のうちは正誤も解説も表示しない", () => {
    const wrapper = mountCard(edgeQuestion);

    expect(wrapper.find(".quiz-question-card__result").exists()).toBe(false);
    expect(wrapper.text()).not.toContain(edgeQuestion.explanation);
  });

  it("未回答のうちは選択肢が押せる", () => {
    const wrapper = mountCard(edgeQuestion);

    const buttons = wrapper.findAll(".quiz-question-card__choice");
    expect(buttons.every((b) => b.attributes("disabled") === undefined)).toBe(true);
  });

  it("選択肢を押すと、その選択肢idで answer を emit する", async () => {
    const wrapper = mountCard(edgeQuestion);

    await wrapper.findAll(".quiz-question-card__choice")[1].trigger("click");

    expect(wrapper.emitted("answer")).toEqual([["B"]]);
  });

  it("回答済みなら、すべての選択肢が押せなくなる（再回答できない）", () => {
    const wrapper = mountCard(edgeQuestion, "B");

    const buttons = wrapper.findAll(".quiz-question-card__choice");
    expect(buttons.every((b) => b.attributes("disabled") !== undefined)).toBe(true);
  });

  it("正解を選ぶと「正解」と解説が表示される", () => {
    const wrapper = mountCard(edgeQuestion, "B");

    const result = wrapper.find(".quiz-question-card__result");
    expect(result.exists()).toBe(true);
    expect(wrapper.find(".quiz-question-card__verdict").text()).toBe("正解");
    expect(result.text()).toContain("中盤の主導権を握りやすい");
  });

  it("誤答を選ぶと「不正解」と解説が表示される", () => {
    const wrapper = mountCard(edgeQuestion, "A");

    expect(wrapper.find(".quiz-question-card__verdict").text()).toBe("不正解");
    expect(wrapper.find(".quiz-question-card__result").text()).toContain(
      "中盤の主導権を握りやすい",
    );
  });

  // 誤答したとき、正解がどれだったか分からないままだと間違いから学べない
  it("誤答しても、正解の選択肢が分かる形で示される", () => {
    const wrapper = mountCard(edgeQuestion, "A");

    const buttons = wrapper.findAll(".quiz-question-card__choice");
    const correctButton = buttons.find((b) => b.text().includes("4-2-3-1がやや優位"));
    const chosenButton = buttons.find((b) => b.text().includes("4-4-2がやや優位"));

    expect(correctButton!.classes()).toContain("quiz-question-card__choice--correct");
    expect(chosenButton!.classes()).toContain("quiz-question-card__choice--incorrect");
  });

  // 色だけに頼ると、色覚特性のある利用者や白黒表示で区別できない
  it("正誤を色以外でも区別できる（記号と読み上げ用テキスト）", () => {
    const wrapper = mountCard(edgeQuestion, "A");

    const buttons = wrapper.findAll(".quiz-question-card__choice");
    const correctButton = buttons.find((b) => b.text().includes("4-2-3-1がやや優位"));
    const chosenButton = buttons.find((b) => b.text().includes("4-4-2がやや優位"));

    expect(correctButton!.find(".quiz-question-card__marker").text()).toBe("○");
    expect(correctButton!.text()).toContain("（正解）");
    expect(chosenButton!.find(".quiz-question-card__marker").text()).toBe("×");
    expect(chosenButton!.text()).toContain("（不正解。あなたの回答）");
  });

  it("正解を選んだ場合、その選択肢が「正解。あなたの回答」と示される", () => {
    const wrapper = mountCard(edgeQuestion, "B");

    const chosen = wrapper
      .findAll(".quiz-question-card__choice")
      .find((b) => b.text().includes("4-2-3-1がやや優位"));
    expect(chosen!.text()).toContain("（正解。あなたの回答）");
  });

  it("回答結果は role=status で支援技術に通知される", () => {
    const wrapper = mountCard(edgeQuestion, "B");

    expect(wrapper.find(".quiz-question-card__result").attributes("role")).toBe("status");
  });

  describe("陣形識別の設問", () => {
    it("ミニピッチ図を表示する", () => {
      const wrapper = mountCard(formationQuestion);

      const pitch = wrapper.findComponent(FormationMiniPitch);
      expect(pitch.exists()).toBe(true);
      expect(pitch.props("formation")?.id).toBe(formations[0].id);
    });

    // 図そのものが設問の内容なので、読み上げから消えると解答できない
    it("ミニピッチ図が読み上げ対象になっている（装飾扱いにしない）", () => {
      const wrapper = mountCard(formationQuestion);

      const svg = wrapper.findComponent(FormationMiniPitch).find("svg");
      expect(svg.attributes("aria-hidden")).toBeUndefined();
      expect(svg.attributes("role")).toBe("img");
      expect(svg.attributes("aria-label")).toContain("選手配置図");
    });

    it("フォーメーション名は設問文に含めない（答えが漏れない）", () => {
      const wrapper = mountCard(formationQuestion);

      expect(wrapper.find(".quiz-question-card__prompt").text()).not.toContain("4-4-2");
    });
  });

  it("陣形識別以外の設問ではミニピッチ図を表示しない", () => {
    const wrapper = mountCard(edgeQuestion);

    expect(wrapper.findComponent(FormationMiniPitch).exists()).toBe(false);
  });

  // FR-11 と組み合わせ、解説文中の用語をその場で引ける
  it("解説文中のサッカー用語を、説明を開けるボタンとして表示する", () => {
    const wrapper = mountCard(edgeQuestion, "B");

    const labels = wrapper
      .findAll("button.term-annotated-text__term")
      .map((b) => b.text());
    expect(labels).toContain("中盤");
  });
});
