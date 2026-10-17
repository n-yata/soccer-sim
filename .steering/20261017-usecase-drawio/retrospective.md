# 振り返り: ユースケースのシーケンス図を drawio に作り直す

## 何をしたか
- `usecase.md` の Mermaid のシーケンス図12枚を、`usecase-sequences.drawio`（ユースケースごとに1ページ）に作り直した
- `usecase.md` の各図は、drawio のページへのリンクとフロー説明に置き換えた

## コミット前レビュー（review-pre-commit）の結果
- 第1回: Critical 0 / High 0 / Medium 0 / Low 2。Low 2件を直した
- 全文: [review-report.md](./review-report.md)

## 学び
- kit の規約 `diagrams.md` は「`docs/specs/2_basic-design/` 以降の図は draw.io」と定めている。一方、`specs-basic-design` のガイドは「シーケンス図は mermaid で記述する」と指示している。ガイドに従って Mermaid で書き、規約を確かめないままコミットしていた。シャビの「drawio は作成しないってこと？」という問いで規約を読み直して気づいた
- 図の形式のような横断的な決まりは、スキルのガイドだけで判断せず、規約（`get_rule`）でも確かめる
- 手で描き直さず、元の Mermaid を解析して変換するスクリプトにしたことで、206件のメッセージを写し間違いなく移せた。レビューでもスクリプトで全件を突き合わせられた

## 改善提案（kit への提案）
- `specs-basic-design` の guide.md「パート2: usecase.md」の「レイヤー横断のシーケンスを mermaid で記述する」を、`diagrams.md`（`2_basic-design/` 以降は draw.io）に合わせて直してほしい。スキルのガイドと規約が食い違っていると、ガイドに従った成果物が規約違反になる
