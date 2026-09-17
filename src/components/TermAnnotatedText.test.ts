import { describe, expect, it } from "vitest";
import { mount } from "@vue/test-utils";
import { h } from "vue";
import TermAnnotatedText from "@/components/TermAnnotatedText.vue";

// 実データ（soccerTerms）に実在する用語を使う。annotateText 側の切り出しは
// termAnnotation.test.ts が担当し、ここでは描画と操作を検証する
const TEXT_WITH_TERMS = "相手のスペースを突き、プレッシングで奪う";
const TEXT_WITHOUT_TERMS = "これはただの文章です";

function mountText(text: string) {
  return mount(TermAnnotatedText, {
    props: { text },
    attachTo: document.body,
  });
}

describe("TermAnnotatedText", () => {
  it("用語をボタンとして描画する", () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    const labels = wrapper.findAll("button").map((b) => b.text());
    expect(labels).toContain("スペース");
    expect(labels).toContain("プレッシング");

    wrapper.unmount();
  });

  it("用語を含まない文はボタンを作らず、本文をそのまま表示する", () => {
    const wrapper = mountText(TEXT_WITHOUT_TERMS);

    expect(wrapper.findAll("button")).toHaveLength(0);
    expect(wrapper.text()).toBe(TEXT_WITHOUT_TERMS);

    wrapper.unmount();
  });

  it("本文の全文が欠落せずに表示される", () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    // 用語ボタンと平文を連結すると元の文に戻る（区間の切り出しで文字が落ちない）
    expect(wrapper.text().replace(/\s/g, "")).toBe(TEXT_WITH_TERMS.replace(/\s/g, ""));

    wrapper.unmount();
  });

  it("初期状態では説明が表示されていない", () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    expect(wrapper.find('[role="tooltip"]').exists()).toBe(false);
    expect(wrapper.find("button").attributes("aria-expanded")).toBe("false");

    wrapper.unmount();
  });

  it("用語を押すと、その用語の説明が表示される", async () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    const spaceButton = wrapper.findAll("button").find((b) => b.text() === "スペース");
    await spaceButton!.trigger("click");

    const tooltip = wrapper.find('[role="tooltip"]');
    expect(tooltip.exists()).toBe(true);
    expect(tooltip.text()).toContain("相手の選手がいない広い場所");
    expect(spaceButton!.attributes("aria-expanded")).toBe("true");

    wrapper.unmount();
  });

  it("aria-describedby が表示中の説明のidを指す", async () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    const button = wrapper.find("button");
    await button.trigger("click");

    const describedBy = button.attributes("aria-describedby");
    expect(describedBy).toBeTruthy();
    expect(wrapper.find('[role="tooltip"]').attributes("id")).toBe(describedBy);

    wrapper.unmount();
  });

  it("同じ用語をもう一度押すと説明が閉じる", async () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    const button = wrapper.find("button");
    await button.trigger("click");
    expect(wrapper.find('[role="tooltip"]').exists()).toBe(true);

    await button.trigger("click");
    expect(wrapper.find('[role="tooltip"]').exists()).toBe(false);
    expect(button.attributes("aria-expanded")).toBe("false");

    wrapper.unmount();
  });

  it("別の用語を押すと、同時に開く説明は1つだけになる", async () => {
    const wrapper = mountText(TEXT_WITH_TERMS);
    const buttons = wrapper.findAll("button");

    await buttons[0].trigger("click");
    await buttons[1].trigger("click");

    expect(wrapper.findAll('[role="tooltip"]')).toHaveLength(1);
    expect(buttons[0].attributes("aria-expanded")).toBe("false");
    expect(buttons[1].attributes("aria-expanded")).toBe("true");

    wrapper.unmount();
  });

  it("Escape キーで説明が閉じる", async () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    await wrapper.find("button").trigger("click");
    expect(wrapper.find('[role="tooltip"]').exists()).toBe(true);

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    await wrapper.vm.$nextTick();

    expect(wrapper.find('[role="tooltip"]').exists()).toBe(false);

    wrapper.unmount();
  });

  it("Escape 以外のキーでは閉じない", async () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    await wrapper.find("button").trigger("click");
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
    await wrapper.vm.$nextTick();

    expect(wrapper.find('[role="tooltip"]').exists()).toBe(true);

    wrapper.unmount();
  });

  it("本文の外側を押すと説明が閉じる", async () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    await wrapper.find("button").trigger("click");
    expect(wrapper.find('[role="tooltip"]').exists()).toBe(true);

    const outside = document.createElement("div");
    document.body.appendChild(outside);
    outside.dispatchEvent(new Event("pointerdown", { bubbles: true }));
    await wrapper.vm.$nextTick();

    expect(wrapper.find('[role="tooltip"]').exists()).toBe(false);

    outside.remove();
    wrapper.unmount();
  });

  it("本文の内側（説明そのもの）を押しても閉じない", async () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    await wrapper.find("button").trigger("click");
    const tooltip = wrapper.find('[role="tooltip"]');
    tooltip.element.dispatchEvent(new Event("pointerdown", { bubbles: true }));
    await wrapper.vm.$nextTick();

    expect(wrapper.find('[role="tooltip"]').exists()).toBe(true);

    wrapper.unmount();
  });

  // FR-09 の A/B 入れ替え・切替で実際に起きる。開いたindexが別の用語を指すのを防ぐ
  it("表示する文が差し替わると説明が閉じる", async () => {
    const wrapper = mountText(TEXT_WITH_TERMS);

    await wrapper.find("button").trigger("click");
    expect(wrapper.find('[role="tooltip"]').exists()).toBe(true);

    await wrapper.setProps({ text: "中盤で受ける" });

    expect(wrapper.find('[role="tooltip"]').exists()).toBe(false);

    wrapper.unmount();
  });

  // 比較画面では優位ポイントの各行・総合判定理由に同時に複数置かれる。
  // aria-describedby は文書内で一意なidを要求するため、同一アプリ内で衝突しないことを見る
  // （mount を2回呼ぶと別アプリになり useId の採番が振り出しに戻るので、
  //  1つの親の下に2つ並べた実際の使われ方で検証する）
  it("同一画面に複数置いても説明のidが衝突しない", async () => {
    const Host = {
      render: () =>
        h("div", [
          h(TermAnnotatedText, { text: TEXT_WITH_TERMS }),
          h(TermAnnotatedText, { text: TEXT_WITH_TERMS }),
        ]),
    };
    const wrapper = mount(Host, { attachTo: document.body });

    const instances = wrapper.findAllComponents(TermAnnotatedText);
    expect(instances).toHaveLength(2);

    // 1つずつ開いてidを採取する（実際の操作では、別インスタンスの用語を押した時点で
    // 外側クリック判定により先に開いていたほうが閉じるため、同時には開かない）
    const ids: (string | undefined)[] = [];
    for (const instance of instances) {
      const button = instance.find("button");
      await button.trigger("click");
      ids.push(instance.find('[role="tooltip"]').attributes("id"));
      await button.trigger("click");
    }

    expect(ids[0]).toBeTruthy();
    expect(ids[1]).toBeTruthy();
    expect(ids[0]).not.toBe(ids[1]);

    wrapper.unmount();
  });
});
