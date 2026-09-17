import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import FreeLayoutControls from "./FreeLayoutControls.vue";

describe("FreeLayoutControls", () => {
  it("isActive=falseのとき、トグルボタンのみ表示されリセットボタンは表示されない", () => {
    const wrapper = mount(FreeLayoutControls, { props: { isActive: false } });
    expect(wrapper.find(".free-layout-controls__toggle").exists()).toBe(true);
    expect(wrapper.find(".free-layout-controls__reset").exists()).toBe(false);
    expect(wrapper.find(".free-layout-controls__toggle").attributes("aria-pressed")).toBe("false");
  });

  it("isActive=trueのとき、トグルボタンとリセットボタンの両方が表示される", () => {
    const wrapper = mount(FreeLayoutControls, { props: { isActive: true } });
    expect(wrapper.find(".free-layout-controls__toggle").exists()).toBe(true);
    expect(wrapper.find(".free-layout-controls__reset").exists()).toBe(true);
    expect(wrapper.find(".free-layout-controls__toggle").attributes("aria-pressed")).toBe("true");
  });

  it("トグルボタンのクリックでtoggleイベントがemitされる", async () => {
    const wrapper = mount(FreeLayoutControls, { props: { isActive: false } });
    await wrapper.find(".free-layout-controls__toggle").trigger("click");
    expect(wrapper.emitted("toggle")).toHaveLength(1);
  });

  it("リセットボタンのクリックでresetイベントがemitされる", async () => {
    const wrapper = mount(FreeLayoutControls, { props: { isActive: true } });
    await wrapper.find(".free-layout-controls__reset").trigger("click");
    expect(wrapper.emitted("reset")).toHaveLength(1);
  });
});
