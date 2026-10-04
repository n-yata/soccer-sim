import { beforeEach, describe, expect, it, vi } from "vitest";
import { mount } from "@vue/test-utils";
import AppHeader from "./AppHeader.vue";

const routeState = vi.hoisted(() => ({ name: "formation-list" as string | undefined }));
vi.mock("vue-router", () => ({
  useRoute: () => ({ name: routeState.name }),
}));

const routerLinkStub = {
  props: ["to"],
  template: "<a @click.prevent :href=\"typeof to === 'string' ? to : to.path\"><slot /></a>",
};

function mountHeader() {
  return mount(AppHeader, {
    global: { stubs: { RouterLink: routerLinkStub } },
  });
}

describe("AppHeader", () => {
  it("Escapeでメニューを閉じ、開閉ボタンへフォーカスを戻す", async () => {
    const wrapper = mount(AppHeader, {
      attachTo: document.body,
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    try {
      await wrapper.get("button").trigger("click");
      await wrapper.get("nav").trigger("keydown", { key: "Escape" });
      expect(wrapper.get("button").attributes("aria-expanded")).toBe("false");
      expect(document.activeElement).toBe(wrapper.get("button").element);
    } finally {
      wrapper.unmount();
    }
  });
  it.each(["learning-list", "formation-learning"])(
    "%sでは学習メニューを現在地として示し、クリックで閉じる",
    async (routeName) => {
      routeState.name = routeName;
      const wrapper = mountHeader();
      try {
        await wrapper.get("button").trigger("click");
        const link = wrapper.get('a[href="/learn"]');
        expect(link.text()).toBe("戦術を学ぶ");
        expect(link.attributes("aria-current")).toBe(
          routeName === "learning-list" ? "page" : "location",
        );
        expect(wrapper.get('a[href="/"]').attributes("aria-current")).toBeUndefined();
        await link.trigger("click");
        expect(wrapper.get("button").attributes("aria-expanded")).toBe("false");
      } finally {
        wrapper.unmount();
      }
    },
  );

  it("自由配置ボードを独立項目として表示し、選択するとメニューを閉じる", async () => {
    routeState.name = "free-layout-board";
    const wrapper = mountHeader();
    await wrapper.find("button").trigger("click");
    const link = wrapper.find("a[href='/board']");
    expect(link.text()).toBe("自由配置ボード");
    expect(link.attributes("aria-current")).toBe("page");
    await link.trigger("click");
    expect(wrapper.find("button").attributes("aria-expanded")).toBe("false");
  });
  beforeEach(() => {
    routeState.name = "formation-list";
  });

  it("現在のルートに対応するナビリンクにaria-current='page'が付く", () => {
    routeState.name = "matrix";
    const wrapper = mountHeader();

    expect(wrapper.find("a.app-header__link[href='/matrix']").attributes("aria-current")).toBe(
      "page",
    );
    expect(wrapper.find("a.app-header__link[href='/']").attributes("aria-current")).toBeUndefined();
  });

  it("比較画面ではフォーメーション選択を現在のセクションとして示す", () => {
    routeState.name = "comparison";
    const wrapper = mountHeader();
    expect(wrapper.find("a.app-header__link[href='/']").attributes("aria-current")).toBe(
      "location",
    );
    expect(
      wrapper.find("a.app-header__link[href='/matrix']").attributes("aria-current"),
    ).toBeUndefined();
  });
});
