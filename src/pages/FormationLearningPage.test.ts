import { afterEach, describe, expect, it, vi } from "vitest";
import { flushPromises, mount } from "@vue/test-utils";
import { createMemoryHistory, createRouter } from "vue-router";
import FormationLearningPage from "./FormationLearningPage.vue";
import FormationListPage from "./FormationListPage.vue";
import { formations } from "@/data/formations";
import { getFormationLesson } from "@/data/formationLessons";

const wrappers: ReturnType<typeof mount>[] = [];
afterEach(() => wrappers.splice(0).forEach((wrapper) => wrapper.unmount()));

async function open(id: string) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: FormationListPage },
      { path: "/formations/:formationId/learn", component: FormationLearningPage },
    ],
  });
  await router.push(`/formations/${id}/learn`);
  await router.isReady();
  const wrapper = mount(FormationLearningPage, { global: { plugins: [router] } });
  wrappers.push(wrapper);
  return { wrapper, router };
}

describe("陣形学習画面", () => {
  it("教材に登場する専門用語の説明をその場で確認できる", async () => {
    const { wrapper } = await open("4-1-4-1");
    expect(wrapper.get("summary").text()).toContain("用語を確認");
    expect(wrapper.get("dl").text()).toContain("アンカー");
    expect(wrapper.get("dl").text()).toContain("中央の選手たちの後ろ");
    expect(wrapper.get('a[href="/glossary"]').text()).toContain("用語集");
  });
  it.each(formations)("$name の配置・固有教材・役割を表示する", async (formation) => {
    const { wrapper } = await open(formation.id);
    expect(wrapper.get("h1").text()).toContain(formation.name);
    expect(wrapper.text()).toContain(getFormationLesson(formation.id)!.scene.title);
    expect(wrapper.get("svg[aria-label]").attributes("aria-label")).toContain(formation.name);
    await wrapper.get('[data-testid="replay-open"]').trigger("click");
    expect(wrapper.get('[data-testid="replay-step"]').text()).toContain("1 / 5");
    expect(wrapper.text()).not.toContain("選んだ陣形にかかわらず");
  });

  it("陣形切替で教材を初期状態へ戻す", async () => {
    const { wrapper, router } = await open("4-4-2");
    await wrapper.get('[data-testid="replay-open"]').trigger("click");
    await wrapper.get('[data-testid="replay-next"]').trigger("click");
    expect(wrapper.get('[data-testid="replay-step"]').text()).toContain("2 / 5");
    await router.push("/formations/3-5-2/learn");
    expect(wrapper.find('[data-testid="replay-step"]').exists()).toBe(false);
    await wrapper.get('[data-testid="replay-open"]').trigger("click");
    expect(wrapper.get('[data-testid="replay-step"]').text()).toContain("1 / 5");
    expect(wrapper.text()).toContain("中央からウイングバックへ");
  });

  it("再生中の陣形切替でタイマーを破棄し、不明IDからも復帰できる", async () => {
    vi.useFakeTimers();
    try {
      const { wrapper, router } = await open("4-4-2");
      await wrapper.get('[data-testid="replay-open"]').trigger("click");
      await wrapper.get('[data-testid="replay-play"]').trigger("click");
      expect(vi.getTimerCount()).toBe(1);
      await router.push("/formations/unknown/learn");
      expect(vi.getTimerCount()).toBe(0);
      expect(wrapper.get('[role="alert"]').text()).toContain("見つかりません");
      await router.push("/formations/4-1-4-1/learn");
      expect(wrapper.get("h1").text()).toContain("4-1-4-1");
      expect(wrapper.find('[role="alert"]').exists()).toBe(false);
    } finally {
      vi.useRealTimers();
    }
  });

  it("一覧の学習リンクが実ルーターで遷移し、比較の選択を増やさない", async () => {
    const { router } = await open("4-4-2");
    await router.push("/");
    const wrapper = mount(FormationListPage, { global: { plugins: [router] } });
    wrappers.push(wrapper);
    await wrapper.get('a[href="/formations/3-4-3/learn"]').trigger("click");
    await flushPromises();
    expect(router.currentRoute.value.path).toBe("/formations/3-4-3/learn");
    expect(wrapper.find('[aria-pressed="true"]').exists()).toBe(false);
  });

  it("不明IDを案内し、一覧へ戻れる", async () => {
    const { wrapper } = await open("unknown");
    expect(wrapper.get('[role="alert"]').text()).toContain("見つかりません");
    expect(wrapper.get('a[href="/"]').text()).toContain("一覧へ");
    expect(wrapper.find('[data-testid="replay-open"]').exists()).toBe(false);
  });
});
