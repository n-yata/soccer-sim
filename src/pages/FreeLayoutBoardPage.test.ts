import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { mount } from "@vue/test-utils";
import FreeLayoutBoardPage from "./FreeLayoutBoardPage.vue";
import FreeLayoutPitchDiagram from "@/components/FreeLayoutPitchDiagram.vue";
import BackButton from "@/components/BackButton.vue";
import { formations } from "@/data/formations";
import { applyOverrides, savePositionOverride } from "@/data/freeLayoutStorage";
import { router } from "@/router";

function mountBoard() {
  return mount(FreeLayoutBoardPage);
}

describe("自由配置ボード", () => {
  it("ボールを操作・保存でき、陣形変更やチームリセットから独立する", async () => {
    const wrapper = mountBoard();
    const ball = wrapper.find("[aria-label='ボール。矢印キーで移動できます']");
    const playerX = wrapper.find("circle.blue").attributes("cx");
    await ball.trigger("keydown", { key: "ArrowRight" });
    expect(ball.attributes("transform")).toBe("translate(136 80)");
    expect(wrapper.find("circle.blue").attributes("cx")).toBe(playerX);
    await ball.trigger("keyup", { key: "ArrowRight" });
    await wrapper.find("#board-formation-a").setValue(formations[1].id);
    await wrapper.find("[data-testid='reset-a']").trigger("click");
    expect(ball.attributes("transform")).toBe("translate(136 80)");
    wrapper.unmount();
    const restored = mountBoard();
    expect(
      restored.find("[aria-label='ボール。矢印キーで移動できます']").attributes("transform"),
    ).toBe("translate(136 80)");
    await restored.find("[data-testid='reset-ball']").trigger("click");
    restored.unmount();
    expect(
      mountBoard().find("[aria-label='ボール。矢印キーで移動できます']").attributes("transform"),
    ).toBe("translate(130 80)");
  });

  it("ボールの操作途中で中央に戻しても古い位置を再保存しない", async () => {
    const wrapper = mountBoard();
    await wrapper
      .find("[aria-label='ボール。矢印キーで移動できます']")
      .trigger("keydown", { key: "ArrowRight" });
    await wrapper.find("[data-testid='reset-ball']").trigger("click");
    await wrapper
      .find("[aria-label='ボール。矢印キーで移動できます']")
      .trigger("keyup", { key: "ArrowRight" });
    wrapper.unmount();
    expect(
      mountBoard().find("[aria-label='ボール。矢印キーで移動できます']").attributes("transform"),
    ).toBe("translate(130 80)");
  });
  beforeEach(() => localStorage.clear());
  afterEach(() => vi.restoreAllMocks());

  it("比較ID不要の独立ルートで両チーム各11人を表示する", () => {
    expect(router.resolve("/board").name).toBe("free-layout-board");
    const wrapper = mountBoard();
    expect(wrapper.find("h1").text()).toBe("自由配置ボード");
    expect(wrapper.findAll("circle.blue")).toHaveLength(11);
    expect(wrapper.findAll("circle.red")).toHaveLength(11);
  });

  it("キーボードで青・赤を動かし、操作確定後の配置を再訪で復元する", async () => {
    const wrapper = mountBoard();
    const write = vi.spyOn(Storage.prototype, "setItem");
    const blue = wrapper.find("circle.blue");
    const red = wrapper.find("circle.red");
    const blueX = Number(blue.attributes("cx"));
    const redX = Number(red.attributes("cx"));
    await blue.trigger("keydown", { key: "ArrowRight" });
    expect(Number(blue.attributes("cx"))).toBeCloseTo(blueX + 6);
    expect(write).not.toHaveBeenCalled();
    await blue.trigger("keyup", { key: "ArrowRight" });
    await red.trigger("keydown", { key: "ArrowLeft" });
    await red.trigger("keyup", { key: "ArrowLeft" });
    expect(Number(red.attributes("cx"))).toBeCloseTo(redX - 6);
    wrapper.unmount();
    const restored = mountBoard();
    expect(Number(restored.find("circle.blue").attributes("cx"))).toBeCloseTo(blueX + 6);
    expect(Number(restored.find("circle.red").attributes("cx"))).toBeCloseTo(redX - 6);
    restored.unmount();
  });

  it("同じ陣形を選んでもチームの保存・リセットを分離する", async () => {
    const wrapper = mountBoard();
    await wrapper.find("#board-formation-b").setValue(formations[0].id);
    const blue = wrapper.find("circle.blue");
    const red = wrapper.find("circle.red");
    const redX = red.attributes("cx");
    const blueX = blue.attributes("cx");
    await blue.trigger("keydown", { key: "ArrowRight" });
    await blue.trigger("keyup", { key: "ArrowRight" });
    expect(red.attributes("cx")).toBe(redX);
    await wrapper.find("[data-testid='reset-b']").trigger("click");
    expect(Number(wrapper.find("circle.blue").attributes("cx"))).toBeCloseTo(Number(blueX) + 6);
    await wrapper.find("[data-testid='reset-a']").trigger("click");
    expect(wrapper.find("circle.blue").attributes("cx")).toBe(blueX);
    wrapper.unmount();
    const restored = mountBoard();
    expect(restored.find("circle.blue").attributes("cx")).toBe(blueX);
  });

  it("陣形を切り替えて戻すと配置を復元し、比較画面の保存に影響しない", async () => {
    const formation = formations[0];
    savePositionOverride(formation.id, formation.positions[0].id, 10, 20);
    const wrapper = mountBoard();
    const blue = wrapper.find("circle.blue");
    const originalX = Number(blue.attributes("cx"));
    await blue.trigger("keydown", { key: "ArrowRight" });
    await blue.trigger("keyup", { key: "ArrowRight" });
    await wrapper.find("#board-formation-a").setValue(formations[1].id);
    expect(wrapper.findComponent(FreeLayoutPitchDiagram).props("formationA").id).toBe(
      formations[1].id,
    );
    await wrapper.find("#board-formation-a").setValue(formation.id);
    expect(Number(wrapper.find("circle.blue").attributes("cx"))).toBeCloseTo(originalX + 6);
    await wrapper.find("[data-testid='reset-a']").trigger("click");
    expect(applyOverrides(formation.positions, formation.id)[0]).toMatchObject({ x: 10, y: 20 });
    expect(formation.positions[0].y).toBe(5);
  });

  it("不正な保存データや保存失敗があっても操作でき、ピッチ外へ移動しない", async () => {
    localStorage.setItem("formation-lab.board-layout-overrides.v1", "invalid-json");
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("quota");
    });
    const wrapper = mountBoard();
    const blue = wrapper.find("circle.blue");
    for (let i = 0; i < 30; i++) await blue.trigger("keydown", { key: "ArrowLeft" });
    await blue.trigger("keyup", { key: "ArrowLeft" });
    const position = wrapper.findComponent(FreeLayoutPitchDiagram).props("formationA").positions[0];
    expect(position.y).toBe(0);
    expect(Number(blue.attributes("cx"))).toBeGreaterThanOrEqual(0);
    await wrapper.find("[data-testid='reset-a']").trigger("click");
    expect(wrapper.findComponent(FreeLayoutPitchDiagram).props("formationA").positions[0].y).toBe(
      5,
    );
  });

  it("キーを押している途中でリセットしても古い座標を再保存しない", async () => {
    const wrapper = mountBoard();
    const blue = wrapper.find("circle.blue");
    const originalX = blue.attributes("cx");
    await blue.trigger("keydown", { key: "ArrowRight" });
    await wrapper.find("[data-testid='reset-a']").trigger("click");
    await wrapper.find("circle.blue").trigger("keyup", { key: "ArrowRight" });
    wrapper.unmount();
    const restored = mountBoard();
    expect(restored.find("circle.blue").attributes("cx")).toBe(originalX);
    restored.unmount();
  });

  it("戻るボタンを置かず、ピッチの説明として操作説明を関連付ける", () => {
    const wrapper = mountBoard();
    expect(wrapper.findComponent(BackButton).exists()).toBe(false);
    const pitch = wrapper.get(".board-page__pitch");
    expect(pitch.attributes("aria-describedby")).toBe("board-instructions");
    expect(wrapper.get("#board-instructions").text()).toContain("矢印キー");
    wrapper.unmount();
  });

  it("青の陣形を選び替えると青だけが新しい陣形の配置になり、赤とボールは変わらない", async () => {
    const wrapper = mountBoard();
    const pitch = () => wrapper.findComponent(FreeLayoutPitchDiagram);
    // 参照のまま持つと、赤の配置をその場で書き換える不具合でも同一オブジェクト同士の比較になり通ってしまうため、値で取り出す。
    const redSnapshot = () => {
      const red = pitch().props("formationB");
      return { id: red.id, positions: red.positions.map(({ id, x, y }) => ({ id, x, y })) };
    };
    const redBefore = redSnapshot();
    const ball = () => wrapper.find("[aria-label='ボール。矢印キーで移動できます']");
    // 中央のままだと「陣形変更でボールが中央へ戻る」不具合を見分けられないため、先に動かしておく。
    await ball().trigger("keydown", { key: "ArrowRight" });
    await ball().trigger("keyup", { key: "ArrowRight" });
    const ballBefore = ball().attributes("transform");
    expect(ballBefore).toBe("translate(136 80)");
    const target = formations.find((formation) => formation.id === "3-5-2")!;
    expect(pitch().props("formationA").id).not.toBe(target.id);

    await wrapper.find("#board-formation-a").setValue(target.id);

    const blue = pitch().props("formationA");
    expect(blue.id).toBe(target.id);
    expect(blue.positions.map(({ id, x, y }) => ({ id, x, y }))).toEqual(
      target.positions.map(({ id, x, y }) => ({ id, x, y })),
    );
    expect(wrapper.findAll("circle.blue")).toHaveLength(11);
    expect(redSnapshot()).toEqual(redBefore);
    expect(ball().attributes("transform")).toBe(ballBefore);
    wrapper.unmount();
  });
});
