import { afterEach, describe, expect, it, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { createMemoryHistory, createRouter } from "vue-router";
import FormationLearningPage from "./FormationLearningPage.vue";
import FormationListPage from "./FormationListPage.vue";
import LearningListPage from "./LearningListPage.vue";
import { formations } from "@/data/formations";
import { getFormationLesson } from "@/data/formationLessons";
import type { FormationLesson } from "@/types/tacticalReplay";

// 登録用語を1件も含まない教材は静的データには無いため、指定した陣形の教材だけを差し替えられるようにする。
// 未指定のときは実関数をそのまま呼ぶので、他のテストには影響しない。
const lessonState = vi.hoisted(() => ({
  override: undefined as { id: string; lesson: FormationLesson } | undefined,
}));
vi.mock("@/data/formationLessons", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/data/formationLessons")>();
  return {
    ...actual,
    getFormationLesson: (id: string) =>
      lessonState.override?.id === id ? lessonState.override.lesson : actual.getFormationLesson(id),
  };
});

const wrappers: ReturnType<typeof mount>[] = [];
afterEach(() => {
  wrappers.splice(0).forEach((wrapper) => wrapper.unmount());
  lessonState.override = undefined;
});

// 実教材の構造を保ったまま、用語抽出の対象になる文言だけを登録用語を含まない文に置き換える。
function lessonWithoutTerms(id: string): FormationLesson {
  const lesson = getFormationLesson(id)!;
  return {
    ...lesson,
    objective: "教材の目的の文",
    caution: "注意点の文",
    scene: {
      ...lesson.scene,
      title: "場面の見出し",
      steps: lesson.scene.steps.map((step, index) => ({
        ...step,
        title: `解説${index + 1}の見出し`,
        explanation: "選手の動きを説明する文",
        observation: "見るポイントの文",
        advantage: "優位の条件の文",
      })),
    },
  };
}

async function open(id: string) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: FormationListPage },
      { path: "/learn", component: LearningListPage },
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

  it("不明IDを案内し、一覧へ戻れる", async () => {
    const { wrapper } = await open("unknown");
    expect(wrapper.get('[role="alert"]').text()).toContain("見つかりません");
    expect(wrapper.get('a[href="/learn"]').text()).toContain("一覧へ");
    expect(wrapper.find('[data-testid="replay-open"]').exists()).toBe(false);
  });

  it("陣形切替ナビは表示中の陣形だけを現在のページとして示す", async () => {
    const { wrapper } = await open("4-3-3");
    const links = wrapper.findAll('nav[aria-label="学ぶ陣形を切り替える"] a');
    expect(links).toHaveLength(formations.length);
    const current = links.filter((link) => link.attributes("aria-current") === "page");
    expect(current.map((link) => link.text())).toEqual(["4-3-3"]);
    expect(links.filter((link) => link.attributes("aria-current") !== undefined)).toHaveLength(1);
  });

  it("役割一覧に攻撃側の選手だけを「青番号：役割（基本配置のポジション）」で示す", async () => {
    const { wrapper } = await open("4-3-3");
    const roles = wrapper
      .findAll(".formation-learning-page__roles li")
      .map((item) => item.text().replace(/\s+/g, ""));
    expect(roles).toEqual(["青7：ウイング（基本配置のRW）", "青2：サイドバック（基本配置のRB）"]);
    expect(roles.some((role) => role.includes("赤"))).toBe(false);
  });

  it("教材に登録用語が1件も無ければ、用語一覧を空にして用語集へのリンクだけを示す", async () => {
    lessonState.override = { id: "4-3-3", lesson: lessonWithoutTerms("4-3-3") };
    const { wrapper } = await open("4-3-3");
    expect(wrapper.get("h1").text()).toBe("4-3-3を学ぶ");
    const terms = wrapper.get(".formation-learning-page__terms");
    expect(terms.findAll("dt")).toHaveLength(0);
    expect(terms.get('a[href="/glossary"]').text()).toContain("用語集");
    expect(wrapper.find('[role="alert"]').exists()).toBe(false);
  });
});
