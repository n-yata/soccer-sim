import { createRouter, createWebHistory } from "vue-router";
import FormationListPage from "@/pages/FormationListPage.vue";
import ComparisonPage from "@/pages/ComparisonPage.vue";
import MatrixPage from "@/pages/MatrixPage.vue";
import GlossaryPage from "@/pages/GlossaryPage.vue";
import QuizPage from "@/pages/QuizPage.vue";
import LearningListPage from "@/pages/LearningListPage.vue";
import FormationLearningPage from "@/pages/FormationLearningPage.vue";
import FreeLayoutBoardPage from "@/pages/FreeLayoutBoardPage.vue";

export const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: "/learn", name: "learning-list", component: LearningListPage },
    { path: "/", name: "formation-list", component: FormationListPage },
    {
      path: "/formations/:formationId/learn",
      name: "formation-learning",
      component: FormationLearningPage,
    },
    {
      path: "/compare/:formationAId/:formationBId",
      name: "comparison",
      component: ComparisonPage,
    },
    { path: "/matrix", name: "matrix", component: MatrixPage },
    { path: "/glossary", name: "glossary", component: GlossaryPage },
    { path: "/quiz", name: "quiz", component: QuizPage },
    {
      path: "/board",
      name: "free-layout-board",
      component: FreeLayoutBoardPage,
      // 学習画面の「この陣形をボードで試す」から青の初期陣形を受け取る。クエリは利用者が書き換えられるため
      // 文字列以外（配列・null）は渡さず、陣形として実在するかの判定はボード画面に任せる。
      props: (route) => ({
        initialBlueFormationId: typeof route.query.blue === "string" ? route.query.blue : undefined,
      }),
    },
  ],
});
