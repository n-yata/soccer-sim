import { describe, expect, it } from "vitest";
import { mount } from "@vue/test-utils";
import { BookOpen } from "@lucide/vue";
import AppIcon from "./AppIcon.vue";

describe("AppIcon", () => {
  it("iconに渡したlucideコンポーネントのsvgが描画される", () => {
    const wrapper = mount(AppIcon, { props: { icon: BookOpen } });
    expect(wrapper.find("svg").exists()).toBe(true);
  });

  it("aria-hidden='true'とfocusable='false'が付与される", () => {
    const wrapper = mount(AppIcon, { props: { icon: BookOpen } });
    const svg = wrapper.find("svg");
    expect(svg.attributes("aria-hidden")).toBe("true");
    expect(svg.attributes("focusable")).toBe("false");
  });

  it("sizeを指定しない場合、既定値'md'のクラスが付く", () => {
    const wrapper = mount(AppIcon, { props: { icon: BookOpen } });
    expect(wrapper.find("svg").classes()).toContain("app-icon--md");
  });

  it("size='sm'/'lg'を指定すると対応するクラスに切り替わる", () => {
    const small = mount(AppIcon, { props: { icon: BookOpen, size: "sm" } });
    expect(small.find("svg").classes()).toContain("app-icon--sm");

    const large = mount(AppIcon, { props: { icon: BookOpen, size: "lg" } });
    expect(large.find("svg").classes()).toContain("app-icon--lg");
  });
});
