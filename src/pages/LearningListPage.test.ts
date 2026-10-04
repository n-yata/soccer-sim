import { afterEach, describe, it, expect, vi } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createRouter, createMemoryHistory, RouterView } from "vue-router";
import LearningListPage from "./LearningListPage.vue";
import FormationLearningPage from "./FormationLearningPage.vue";
import BackButton from "@/components/BackButton.vue";
import { formations } from "@/data/formations";
import { getFormationLesson } from "@/data/formationLessons";

// 教材の無い陣形は静的データでは起きないため、指定した陣形だけ教材が見つからない状態を作れるようにする。
// 未指定のときは実関数をそのまま呼ぶので、他のテストには影響しない。
const lessonState = vi.hoisted(() => ({ missingId: undefined as string | undefined }));
vi.mock("@/data/formationLessons", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/data/formationLessons")>();
  return {
    ...actual,
    getFormationLesson: (id: string) =>
      id === lessonState.missingId ? undefined : actual.getFormationLesson(id),
  };
});

afterEach(() => {
  lessonState.missingId = undefined;
});

async function mountLearningList() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/learn", component: LearningListPage },
      { path: "/formations/:formationId/learn", component: FormationLearningPage },
    ],
  });
  await router.push("/learn");
  await router.isReady();
  return mount(RouterView, { global: { plugins: [router] } });
}

describe("戦術の学習一覧", () => {
  it("8陣形の目的を示し、実ルーターで教材へ進み学習一覧へ戻れる", async () => {
    const wrapper = await mountLearningList();
    try {
      expect(wrapper.findAll(".learning-list-page__card")).toHaveLength(8);
      for (const f of formations) {
        const card = wrapper.get(`a[href="/formations/${f.id}/learn"]`);
        expect(card.text()).toContain(f.name);
        expect(card.text()).toContain(getFormationLesson(f.id)!.objective);
        expect(card.find("button").exists()).toBe(false);
      }
      await wrapper.get('a[href="/formations/3-4-3/learn"]').trigger("click");
      await flushPromises();
      expect(wrapper.get("h1").text()).toBe("3-4-3を学ぶ");
      await wrapper.get('a[href="/learn"]').trigger("click");
      await flushPromises();
      expect(wrapper.get("h1").text()).toBe("戦術を学ぶ");
    } finally {
      wrapper.unmount();
    }
  });

  it("各カードに場面タイトルを h3 で示し、カード全体を「陣形名を学ぶ：場面タイトル」として読み上げる", async () => {
    const wrapper = await mountLearningList();
    try {
      for (const f of formations) {
        const card = wrapper.get(`a[href="/formations/${f.id}/learn"]`);
        const sceneTitle = getFormationLesson(f.id)!.scene.title;
        expect(card.get("h3").text()).toBe(sceneTitle);
        expect(card.attributes("aria-label")).toBe(`${f.name}を学ぶ：${sceneTitle}`);
      }
      expect(wrapper.get('a[href="/formations/4-3-3/learn"]').attributes("aria-label")).toBe(
        "4-3-3を学ぶ：サイドの2対1",
      );
    } finally {
      wrapper.unmount();
    }
  });

  it("各カードにミニピッチ図を1つずつ描く", async () => {
    const wrapper = await mountLearningList();
    try {
      const cards = wrapper.findAll(".learning-list-page__card");
      expect(cards).toHaveLength(8);
      for (const card of cards) {
        expect(card.findAll("svg.formation-mini-pitch")).toHaveLength(1);
      }
    } finally {
      wrapper.unmount();
    }
  });

  it("教材の無い陣形はカードを出さず、エラーも表示しない", async () => {
    lessonState.missingId = "4-4-2";
    const wrapper = await mountLearningList();
    try {
      expect(wrapper.findAll(".learning-list-page__card")).toHaveLength(7);
      expect(wrapper.find('a[href="/formations/4-4-2/learn"]').exists()).toBe(false);
      expect(wrapper.find('a[href="/formations/4-3-3/learn"]').exists()).toBe(true);
      expect(wrapper.find('[role="alert"]').exists()).toBe(false);
    } finally {
      wrapper.unmount();
    }
  });

  it("主ナビから開くトップレベル画面のため、ヘッダーに戻るボタンを置かない", async () => {
    const wrapper = await mountLearningList();
    try {
      expect(wrapper.get("h1").text()).toBe("戦術を学ぶ");
      expect(wrapper.findComponent(BackButton).exists()).toBe(false);
    } finally {
      wrapper.unmount();
    }
  });
});
