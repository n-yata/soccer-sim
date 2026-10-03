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
    { path: "/board", name: "free-layout-board", component: FreeLayoutBoardPage },
  ],
});
