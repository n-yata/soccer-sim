import js from "@eslint/js";
import tseslint from "typescript-eslint";
import pluginVue from "eslint-plugin-vue";
import vueParser from "vue-eslint-parser";
import eslintConfigPrettier from "eslint-config-prettier";

export default [
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...pluginVue.configs["flat/recommended"],
  {
    files: ["**/*.vue"],
    languageOptions: {
      parser: vueParser,
      parserOptions: {
        parser: tseslint.parser,
        sourceType: "module",
      },
    },
  },
  {
    languageOptions: {
      globals: {
        console: "readonly",
      },
    },
    rules: {
      "no-console": ["warn", { allow: ["error"] }],
    },
  },
  eslintConfigPrettier,
  {
    // .claude/skills, .claude/hooks は kit 配布物のため lint 対象外とする
    // （reference/rules/gitignore.md「フォーマッタ・整形ツールの除外設定」参照）
    // soccer-game/ は Godot のゲーム（独自の規約・ツールを持つ）、public/game/ はその書き出し物のため対象外
    ignores: [
      "dist/**",
      "node_modules/**",
      ".claude/skills/**",
      ".claude/hooks/**",
      "soccer-game/**",
      "public/game/**",
    ],
  },
];
