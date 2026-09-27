import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig({
  // GitHub Pagesのプロジェクトページ配信（https://n-yata.github.io/soccer-sim/）に合わせた
  // サブパス。ローカル開発サーバー（npm run dev）ではViteが自動でこのbaseを反映する
  base: "/soccer-sim/",
  plugins: [vue()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  test: {
    environment: "jsdom",
    globals: true,
    // scoped styleの実CSSをjsdomへ適用する。ComparisonPageの横並び/縦積み切替
    // （flex-wrap依存）のような、実CSSの宣言を直接検証する回帰テストに必要。
    css: true,
  },
});
