import { beforeEach, describe, expect, it, vi } from "vitest";
import { mount } from "@vue/test-utils";
import BackButton from "./BackButton.vue";

const pushMock = vi.fn();
const backMock = vi.fn();

vi.mock("vue-router", () => ({
  useRouter: () => ({ push: pushMock, back: backMock }),
}));

describe("BackButton", () => {
  beforeEach(() => {
    pushMock.mockClear();
    backMock.mockClear();
  });

  it("履歴が無い場合、fallbackToへrouter.pushする", async () => {
    window.history.replaceState({}, "");
    const wrapper = mount(BackButton, { props: { fallbackTo: "/matrix" } });

    await wrapper.find("button").trigger("click");

    expect(pushMock).toHaveBeenCalledWith("/matrix");
    expect(backMock).not.toHaveBeenCalled();
  });

  it("fallbackTo未指定時、履歴が無ければ'/'へrouter.pushする", async () => {
    window.history.replaceState({}, "");
    const wrapper = mount(BackButton);

    await wrapper.find("button").trigger("click");

    expect(pushMock).toHaveBeenCalledWith("/");
  });

  it("アプリ内遷移の履歴がある場合、router.back()で戻る", async () => {
    window.history.replaceState({ back: "/" }, "");
    const wrapper = mount(BackButton, { props: { fallbackTo: "/matrix" } });

    await wrapper.find("button").trigger("click");

    expect(backMock).toHaveBeenCalledTimes(1);
    expect(pushMock).not.toHaveBeenCalled();
  });
});
