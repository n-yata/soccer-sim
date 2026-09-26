import { beforeEach, describe, expect, it, vi } from "vitest";
import { mount } from "@vue/test-utils";
import AppHeader from "./AppHeader.vue";

const routeState = vi.hoisted(() => ({ name: "formation-list" as string | undefined }));
vi.mock("vue-router", () => ({
  useRoute: () => ({ name: routeState.name }),
}));

const routerLinkStub = {
  props: ["to"],
  template: "<a :href=\"typeof to === 'string' ? to : to.path\"><slot /></a>",
};

function mountHeader(showCupLink = true) {
  return mount(AppHeader, {
    props: { showCupLink },
    global: { stubs: { RouterLink: routerLinkStub } },
  });
}

describe("AppHeader", () => {
  beforeEach(() => {
    routeState.name = "formation-list";
  });

  it("showCupLinkがtrueのとき、カップ戦導線を表示する", () => {
    const wrapper = mountHeader(true);

    expect(wrapper.find("a[href='/cup']").exists()).toBe(true);
  });

  it("showCupLinkがfalseのとき、カップ戦導線を表示しない", () => {
    const wrapper = mountHeader(false);

    expect(wrapper.find("a[href='/cup']").exists()).toBe(false);
  });

  it("現在のルートに対応するナビリンクにaria-current='page'が付く", () => {
    routeState.name = "matrix";
    const wrapper = mountHeader();

    expect(wrapper.find("a.app-header__link[href='/matrix']").attributes("aria-current")).toBe(
      "page",
    );
    expect(
      wrapper.find("a.app-header__link[href='/']").attributes("aria-current"),
    ).toBeUndefined();
  });
});
