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

function mountHeader() {
  return mount(AppHeader, {
    global: { stubs: { RouterLink: routerLinkStub } },
  });
}

describe("AppHeader", () => {
  beforeEach(() => {
    routeState.name = "formation-list";
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
