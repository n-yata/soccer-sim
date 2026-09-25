import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import SquadConditionControls from "./SquadConditionControls.vue";

describe("SquadConditionControls", () => {
  it("isActive=falseのとき、トグルボタンのみ表示されリロールボタンは表示されない", () => {
    const wrapper = mount(SquadConditionControls, { props: { isActive: false } });
    expect(wrapper.find(".squad-condition-controls__toggle").exists()).toBe(true);
    expect(wrapper.find(".squad-condition-controls__reroll").exists()).toBe(false);
    expect(wrapper.find(".squad-condition-controls__toggle").attributes("aria-pressed")).toBe(
      "false",
    );
  });

  it("isActive=trueのとき、トグルボタンとリロールボタンの両方が表示される", () => {
    const wrapper = mount(SquadConditionControls, { props: { isActive: true } });
    expect(wrapper.find(".squad-condition-controls__toggle").exists()).toBe(true);
    expect(wrapper.find(".squad-condition-controls__reroll").exists()).toBe(true);
    expect(wrapper.find(".squad-condition-controls__toggle").attributes("aria-pressed")).toBe(
      "true",
    );
  });

  it("トグルボタンのクリックでtoggleイベントがemitされる", async () => {
    const wrapper = mount(SquadConditionControls, { props: { isActive: false } });
    await wrapper.find(".squad-condition-controls__toggle").trigger("click");
    expect(wrapper.emitted("toggle")).toHaveLength(1);
  });

  it("リロールボタンのクリックでrerollイベントがemitされる", async () => {
    const wrapper = mount(SquadConditionControls, { props: { isActive: true } });
    await wrapper.find(".squad-condition-controls__reroll").trigger("click");
    expect(wrapper.emitted("reroll")).toHaveLength(1);
  });
});
