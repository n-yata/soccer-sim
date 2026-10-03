import { afterEach, describe, expect, it, vi } from "vitest";
import { mount } from "@vue/test-utils";
import BoardBall from "./BoardBall.vue";
import type { BoardBallPosition } from "@/data/boardBallStorage";

function mountBall() {
  return mount(BoardBall, { props: { position: { x: 50, y: 50 } } });
}

function stubCtm(svg: SVGSVGElement, isInvalid = false) {
  const identity = { inverse: () => identity } as unknown as DOMMatrix;
  svg.getScreenCTM = () => identity;
  svg.createSVGPoint = () => {
    const point = {
      x: 0,
      y: 0,
      matrixTransform: () => ({ x: isInvalid ? NaN : point.x, y: point.y }),
    };
    return point as unknown as DOMPoint;
  };
}

describe("ボードのボール操作", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it.each(["lostpointercapture", "released-buttons"])(
    "%sでドラッグを一度だけ確定し、次のドラッグを開始できる",
    async (ending) => {
      const wrapper = mountBall();
      stubCtm(wrapper.find("svg").element as SVGSVGElement);
      const ball = wrapper.find("g");
      await ball.trigger("pointerdown", { pointerId: 1, button: 0 });
      await ball.trigger("pointermove", { pointerId: 1, buttons: 1, clientX: 130, clientY: 80 });
      if (ending === "lostpointercapture")
        await ball.trigger("lostpointercapture", { pointerId: 1 });
      else await ball.trigger("pointermove", { pointerId: 1, buttons: 0 });
      await ball.trigger("pointerup", { pointerId: 1 });
      await ball.trigger("pointermove", { pointerId: 1, buttons: 1, clientX: 100, clientY: 50 });
      expect(wrapper.emitted("update-position")).toHaveLength(1);
      expect(wrapper.emitted("update-position-end")).toEqual([[{ x: 50, y: 50 }]]);
      await ball.trigger("pointerdown", { pointerId: 2, button: 0 });
      await ball.trigger("pointermove", { pointerId: 2, buttons: 1, clientX: 255, clientY: 155 });
      await ball.trigger("pointerup", { pointerId: 2 });
      expect(wrapper.emitted("update-position-end")![1]).toEqual([{ x: 100, y: 100 }]);
    },
  );

  it("画面幅に応じて44pxの操作領域を確保し、離脱時に監視を解放する", async () => {
    let resize = () => {};
    const observe = vi.fn();
    const disconnect = vi.fn();
    vi.stubGlobal(
      "ResizeObserver",
      class {
        constructor(callback: () => void) {
          resize = callback;
        }
        observe = observe;
        disconnect = disconnect;
      },
    );
    let width = 260;
    vi.spyOn(Element.prototype, "getBoundingClientRect").mockImplementation(
      () => ({ width }) as DOMRect,
    );
    const wrapper = mountBall();
    expect(observe).toHaveBeenCalledWith(wrapper.find("svg").element);
    resize();
    await wrapper.vm.$nextTick();
    expect(Number(wrapper.find(".board-ball__hit").attributes("r"))).toBe(22);
    width = 130;
    resize();
    await wrapper.vm.$nextTick();
    expect(Number(wrapper.find(".board-ball__hit").attributes("r"))).toBe(44);
    wrapper.unmount();
    expect(disconnect).toHaveBeenCalledTimes(1);
  });
  it("中央に表示し、矢印キーで移動してキーを離した時に確定する", async () => {
    const wrapper = mountBall();
    const ball = wrapper.find("[aria-label='ボール。矢印キーで移動できます']");
    expect(ball.attributes("tabindex")).toBe("0");
    expect(ball.attributes("transform")).toBe("translate(130 80)");
    await ball.trigger("keydown", { key: "ArrowRight" });
    const position = wrapper.emitted("update-position")![0][0] as BoardBallPosition;
    expect(position).toEqual({ x: 52.4, y: 50 });
    expect(wrapper.emitted("update-position-end")).toBeUndefined();
    await wrapper.setProps({ position });
    expect(ball.attributes("transform")).toBe("translate(136 80)");
    await ball.trigger("keyup", { key: "ArrowRight" });
    expect(wrapper.emitted("update-position-end")).toEqual([[position]]);
  });

  it("キー操作後にフォーカスが離れても一度だけ確定する", async () => {
    const wrapper = mountBall();
    const ball = wrapper.find("g");
    await ball.trigger("keydown", { key: "ArrowUp" });
    await ball.trigger("blur");
    await ball.trigger("keyup", { key: "ArrowUp" });
    expect(wrapper.emitted("update-position-end")).toEqual([[{ x: 50, y: 46 }]]);
  });

  it("ドラッグで移動し、範囲外は端に収めキャンセルでも確定する", async () => {
    const wrapper = mountBall();
    stubCtm(wrapper.find("svg").element as SVGSVGElement);
    const ball = wrapper.find("g");
    await ball.trigger("pointerdown", { pointerId: 1, button: 0 });
    await ball.trigger("pointermove", { pointerId: 1, buttons: 1, clientX: 300, clientY: -30 });
    expect(wrapper.emitted("update-position")).toEqual([[{ x: 100, y: 0 }]]);
    expect(wrapper.emitted("update-position-end")).toBeUndefined();
    await ball.trigger("pointercancel", { pointerId: 1 });
    expect(wrapper.emitted("update-position-end")).toEqual([[{ x: 100, y: 0 }]]);
    await ball.trigger("pointerup", { pointerId: 1 });
    expect(wrapper.emitted("update-position-end")).toHaveLength(1);
  });

  it("別ポインタ・右クリック・不正座標では移動しない", async () => {
    const wrapper = mountBall();
    stubCtm(wrapper.find("svg").element as SVGSVGElement, true);
    const ball = wrapper.find("g");
    await ball.trigger("pointerdown", { pointerId: 2, button: 2 });
    await ball.trigger("pointermove", { pointerId: 2, buttons: 1, clientX: 40, clientY: 50 });
    await ball.trigger("pointerdown", { pointerId: 1, button: 0 });
    await ball.trigger("pointermove", { pointerId: 2, buttons: 1, clientX: 40, clientY: 50 });
    await ball.trigger("pointermove", { pointerId: 1, buttons: 1, clientX: 40, clientY: 50 });
    await ball.trigger("pointerup", { pointerId: 1 });
    expect(wrapper.emitted("update-position")).toBeUndefined();
    expect(wrapper.emitted("update-position-end")).toBeUndefined();
  });

  it("キーボード操作でも端を越えず、関係ないキーでは変更しない", async () => {
    const wrapper = mountBall();
    await wrapper.setProps({ position: { x: 0, y: 100 } });
    const ball = wrapper.find("g");
    await ball.trigger("keydown", { key: "Enter" });
    expect(wrapper.emitted("update-position")).toBeUndefined();
    await ball.trigger("keydown", { key: "ArrowLeft" });
    await ball.trigger("keyup", { key: "ArrowLeft" });
    expect(wrapper.emitted("update-position-end")).toEqual([[{ x: 0, y: 100 }]]);
  });
});
