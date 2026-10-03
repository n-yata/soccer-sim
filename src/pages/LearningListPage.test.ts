import { describe, it, expect } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createRouter, createMemoryHistory, RouterView } from "vue-router";
import LearningListPage from "./LearningListPage.vue";
import FormationLearningPage from "./FormationLearningPage.vue";
import { formations } from "@/data/formations";
import { getFormationLesson } from "@/data/formationLessons";

describe("戦術の学習一覧", () => {
  it("8陣形の目的を示し、実ルーターで教材へ進み学習一覧へ戻れる", async () => {
    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: "/learn", component: LearningListPage },
        { path: "/formations/:formationId/learn", component: FormationLearningPage },
      ],
    });
    await router.push("/learn");
    await router.isReady();
    const wrapper = mount(RouterView, { global: { plugins: [router] } });
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
});
