import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { nextTick } from "vue";
import HalftimeTacticsModal from "./HalftimeTacticsModal.vue";
import { getFormationById } from "@/data/formations";
import type { Formation, MatchSimulationResult } from "@/types/formation";

function buildHalftimeResult(): MatchSimulationResult {
  return {
    possession: { a: 55, b: 45 },
    shots: { a: 5, b: 3 },
    shotsOnTarget: { a: 2, b: 1 },
    score: { a: 1, b: 0 },
    timeline: [],
    summary: "",
  };
}

describe("HalftimeTacticsModal", () => {
  let triggerButton: HTMLButtonElement;
  // 途中で失敗したテストがモーダルをbodyに残し、Escapeの documentリスナも
  // 解除されないまま次のテストへ漏れるのを防ぐため、必ずafterEachでunmountする
  let mountedWrappers: ReturnType<typeof mount>[] = [];

  afterEach(() => {
    mountedWrappers.forEach((wrapper) => wrapper.unmount());
    mountedWrappers = [];
    triggerButton?.remove();
  });

  function mountWithTrigger() {
    triggerButton = document.createElement("button");
    document.body.appendChild(triggerButton);
    triggerButton.focus();

    const formationA = getFormationById("4-2-3-1") as Formation;
    const formationB = getFormationById("4-4-2") as Formation;
    const wrapper = mount(HalftimeTacticsModal, {
      attachTo: document.body,
      props: { formationA, formationB, halftimeResult: buildHalftimeResult() },
    });
    mountedWrappers.push(wrapper);
    return wrapper;
  }

  function getFocusable(modal: HTMLElement): HTMLElement[] {
    return Array.from(
      modal.querySelectorAll<HTMLElement>(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
      ),
    );
  }

  // フォーカス管理（WCAG 2.4.3）
  it("マウント時にフォーカスが閉じるボタンへ移る", () => {
    const wrapper = mountWithTrigger();
    expect(document.activeElement).toBe(wrapper.find(".halftime-modal__close").element);
  });

  it("アンマウント時に、開く前にフォーカスされていた要素へフォーカスが戻る", () => {
    const wrapper = mountWithTrigger();
    expect(document.activeElement).not.toBe(triggerButton);

    wrapper.unmount();

    expect(document.activeElement).toBe(triggerButton);
  });

  it("開く前にフォーカスされていた要素がDOMから取り除かれていた場合、document.bodyへフォールバックする（フォーカスの迷子を防ぐ）", () => {
    const wrapper = mountWithTrigger();
    triggerButton.remove();

    wrapper.unmount();

    expect(document.activeElement).toBe(document.body);
  });

  it("bodyへのフォールバック後、別の要素へフォーカスが移ると一時的なtabindexが除去される（DOMに余分な属性を残さない）", () => {
    const wrapper = mountWithTrigger();
    triggerButton.remove();
    wrapper.unmount();
    expect(document.body.hasAttribute("tabindex")).toBe(true);

    const other = document.createElement("button");
    document.body.appendChild(other);
    other.focus();

    expect(document.body.hasAttribute("tabindex")).toBe(false);
    other.remove();
  });

  it("最後のフォーカス可能要素でTabを押すと、最初の要素へ折り返す（フォーカストラップ）", async () => {
    const wrapper = mountWithTrigger();
    const modal = wrapper.find(".halftime-modal").element as HTMLElement;
    const focusable = getFocusable(modal);
    const first = focusable[0];
    const last = focusable[focusable.length - 1];

    last.focus();
    last.dispatchEvent(new KeyboardEvent("keydown", { key: "Tab", bubbles: true }));
    await nextTick();

    expect(document.activeElement).toBe(first);
  });

  it("最初のフォーカス可能要素でShift+Tabを押すと、最後の要素へ折り返す（フォーカストラップ）", async () => {
    const wrapper = mountWithTrigger();
    const modal = wrapper.find(".halftime-modal").element as HTMLElement;
    const focusable = getFocusable(modal);
    const first = focusable[0];
    const last = focusable[focusable.length - 1];

    first.focus();
    first.dispatchEvent(new KeyboardEvent("keydown", { key: "Tab", shiftKey: true, bubbles: true }));
    await nextTick();

    expect(document.activeElement).toBe(last);
  });

  // 既存の基本挙動（役割・Escape・操作）の確認
  it("role=dialog・aria-modal=trueが設定されている", () => {
    const wrapper = mountWithTrigger();
    const modal = wrapper.find(".halftime-modal");
    expect(modal.attributes("role")).toBe("dialog");
    expect(modal.attributes("aria-modal")).toBe("true");
  });

  it("閉じるボタンのクリックでcancelがemitされる", async () => {
    const wrapper = mountWithTrigger();
    await wrapper.find(".halftime-modal__close").trigger("click");
    expect(wrapper.emitted("cancel")).toHaveLength(1);
  });

  // 閉じるボタンは記号のみ（テキストラベル無し）でアクセシブルネームをaria-labelに
  // 依存しているため、アイコン化後もこの属性が失われていないことを固定する
  it("閉じるボタンにaria-label='閉じる'が維持されている", () => {
    const wrapper = mountWithTrigger();
    expect(wrapper.find(".halftime-modal__close").attributes("aria-label")).toBe("閉じる");
  });

  it("Escapeキーでcancelがemitされる", () => {
    const wrapper = mountWithTrigger();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    expect(wrapper.emitted("cancel")).toHaveLength(1);
  });

  it("「この配置で後半を開始する」ボタンで、A/Bの現在の配置がconfirmとしてemitされる", async () => {
    const wrapper = mountWithTrigger();
    await wrapper.find(".halftime-modal__confirm").trigger("click");

    const emitted = wrapper.emitted("confirm");
    expect(emitted).toHaveLength(1);
    const formationA = getFormationById("4-2-3-1") as Formation;
    const formationB = getFormationById("4-4-2") as Formation;
    expect(emitted![0][0]).toEqual(formationA.positions);
    expect(emitted![0][1]).toEqual(formationB.positions);
  });
});
