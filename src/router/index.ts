import { createRouter, createWebHistory } from "vue-router";
import FormationListPage from "@/pages/FormationListPage.vue";
import ComparisonPage from "@/pages/ComparisonPage.vue";
import MatrixPage from "@/pages/MatrixPage.vue";
import GlossaryPage from "@/pages/GlossaryPage.vue";
import QuizPage from "@/pages/QuizPage.vue";
import LeaguePage from "@/pages/LeaguePage.vue";

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", name: "formation-list", component: FormationListPage },
    {
      path: "/compare/:formationAId/:formationBId",
      name: "comparison",
      component: ComparisonPage,
    },
    { path: "/matrix", name: "matrix", component: MatrixPage },
    { path: "/glossary", name: "glossary", component: GlossaryPage },
    { path: "/quiz", name: "quiz", component: QuizPage },
    { path: "/league", name: "league", component: LeaguePage },
  ],
});
