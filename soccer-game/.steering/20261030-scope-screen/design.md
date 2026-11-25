# 設計

| 層 | ファイル | 役割 |
|---|---|---|
| UI | `ui/screens/s10_scope/scope_screen.gd`（`ScopeScreen`） | S-10。ヘッダー・説明文・`SimplificationList` を縦にスクロール |
| UI | `ui/common/simplification_list.gd` | 見出しに ID を付ける（`title_of`）。「実戦では」をテーマの型 `CautionLabel` にする |
| UI | `ui/common/theme/app_theme.tres` | `CautionLabel`（文字 caution `#FBBF77`、24px） |
| UI | `ui/main_shell.gd`・`ui/screens/s01_title/title_screen.tscn` | 画面の登録、タイトルの一言 |

- 値は `App.library.simplifications()`（静的データの順 = ID 順。ID の連番はテスト `tests/content/tutorial_content_test.gd` が確かめる）
- 状態を持たない。開くたびに一覧を作り直す（`SimplificationList.show_items` が前のカードを外す）

## テスト

- `tests/ui/scope_screen_test.gd`: 全項目が ID 順・3行の文、`CautionLabel` の色、開き直しで重複しない、戻る、画面の登録
- `tests/ui/tutorial_screen_test.gd`: 最後の段階のカードの見出しを「SIM-NN 名前」に合わせる
