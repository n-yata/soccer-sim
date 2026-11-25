# コミット前レビューレポート

詳細設計（`20261017-detail-design`）と、画面を横向きだけにする変更（`20261018-landscape`）を1つのコミットにするため、
レビューは本レポートにまとめる。

## 第1回（2026-10-18）
- 対象: `docs/specs/1_requirements/`（architecture-overview・functional-overview・non-functional-requirements・repository-structure・requirements-definition）、
  `docs/specs/2_basic-design/`（component-design・screen-design・wireframes.drawio）、`docs/specs/3_detail-design/` 一式（`.gitkeep` の削除を含む）、
  `.steering/20261017-detail-design/`・`.steering/20261018-landscape/`
- 結果: Critical 0件 / High 2件 / Medium 9件 / Low 10件

## コミット前レビュー結果

### Critical（即時対応必須）
- なし

### High（優先対応）
- [バグ] **S-03 の上部バーが 16:9（さらに 21:9）の横幅に収まらない（NFR-25「表示が欠けない」に反する）**: `screen-03-match.md` のノード構成の `TopBar`（`HBoxContainer`、高さ 96px）に、`MenuButton` 96px・`ScoreBug`（チップ 2 つ＋スコア 52px＋時計で約 470px）・`InfoRow`（`PhaseTag`＋自分と相手の陣形・方式の `Label` 2 つ）を横一列に並べている。screen-common §2 の最小の文字（24〜28px）で見積もると、`PhaseTag`「NEG.TRANSITION ネガティブトランジション」が約 500px、陣形・方式の Label「◆ 4-4-2 マンツーマン・カウンター」が1本あたり約 380〜450px で、合計は約 1,900px になる。16:9 で使える幅は 1280 − 48 = 1232px、21:9 でも 1632px なので、どちらも超える。開示中の `RevealBanner`（「YOU ショートパス → 中盤・中央」と「CPU プレス → 中盤・左HS」）も、16:9 では約 1,290〜1,400px になり収まらない。ワイヤーフレームは 800×360dp（20:9 相当で、16:9 の基準 640dp より広い）で描かれており、陣形・方式の欄も 502dp 幅の小さな 2 行の文字なので、この問題が図からは見えない。
  → 修正案:
  1. `InfoRow` を `VBoxContainer` の 2 段にする（上段は `PhaseTag`、下段は「● 4-3-3 ゾーン・カウンター ◆ 4-4-2 …」）。`PhaseTag` はヘッダーでは英字だけにし、日本語の局面名を操作の列の上端に移す。
  2. 陣形・方式の Label には `text_overrun_behavior = ELLIPSIS` と最小の文字の大きさを定め、省いた全文は操作の列などで読めるようにする。
  3. `RevealBanner` も 2 段（YOU 行と CPU 行）にする。
  4. screen-common §1.1 に「ヘッダーの中身は 16:9 の 1232px で収まること」を検査の項目として書き、ワイヤーフレームか詳細設計に 16:9 の配置を少なくとも 1 枚描く。
- [バグ] **背番号つきの駒を描くための値が `BoardSnapshot` に無い**: 今回の差分で ER 図に「背番号」を足し（`functional-overview.md`）、`formations.json` に `number` を足した（data-definition §3.1）。screen-common §5 の `TacticsBoard` は「各エリアの駒（人数ぶん。背番号つき）」を `show_snapshot(snapshot: BoardSnapshot)` で描くとしている。ところが `component-design.md` §3.5 の `BoardSnapshot` には `user_counts`・`opponent_counts`（人数だけ）しか無く、どの選手（背番号）がどのエリアにいるかが渡らない。UI 側で選手の位置を求めるには、`fixed_area` と `base_area` のどちらを使うかといったルールの計算が要り、§3.5 の「UI は座標の変換もルールの計算もしない」に反する。このまま作ると、背番号の無い駒になるか、UI に規則が漏れる。
  → 修正案: `BoardSnapshot` に `user_players` / `opponent_players`（各要素は `{player_id, number, area}`。area は利用者の視点に変換済み）を足し、`user_counts` はそこから導けることを明記する。`RevealView.players_before` / `players_at_judgement` も、背番号を引けるかどうか（`player_id` → `LibraryService` で引く、など）をあわせて決める。

### Medium（対応推奨）
- [バグ] **`MatchBoardPanel` と S-03 画面の役割分担が食い違い、S-08 では「次へ」が 2 つになる**: screen-common §5 では、`MatchBoardPanel` が `bind(controller, options_filter)` でコントローラにつながり、`turn_ready_to_leave` を出す（盤面・手の選択・判定理由をまとめた部品）。一方 `screen-03-match.md` の「イベント処理の詳細フロー」は、`MatchScreen` 自身が `state_changed`・`turn_resolved` をつなぎ、`_state` などを持ち、`continue_after_reveal()` を呼ぶ書き方になっている。両方をそのまま作ると、シグナルを 2 重に受けるか、どちらが遷移を起こすかが決まらない。S-08 では、パネル内の `PrimaryButton`（判定後は「次のターンへ／NEXT」）と `SideBottomSlot` の `NextButton`「次へ」が同時に出る（ワイヤーフレーム s08 も「決定」と「次へ」の 2 段）。そのうえ、チュートリアル用コントローラで NEXT を押したときの動き（`continue_after_reveal` を呼ぶか）が書かれていない。
  → 修正案: 状態（`SELECT_ACTION`〜`SHOW_RESULT`）、`_options`・`_hints`・`_reveal`、シグナルの接続は `MatchBoardPanel` が持つと決め、S-03 の詳細フローを「パネルの中の処理」として書き直す。「次へ」はパネルが `turn_ready_to_leave` を出し、S-03 は `continue_after_reveal()`、S-08 は次の段階へ進む。S-08 では判定後の `PrimaryButton` を隠し、`NextButton` だけにする（または逆）と明記する。
- [バグ] **S-05 の陣形カードの並べ方が文書によって違い、操作の列が縦にあふれる**: `screen-design.md` S-05（今回の差分）は「陣形の4カード（2×2）」、`screen-05-halftime.md` とワイヤーフレーム s05（76dp 幅で横 4 枚）は「4列」。さらに screen-design は「列の中は縦にスクロールできる」とするが、詳細設計の `SideColumn` は `VBoxContainer` のままでスクロールが無い。見出し 3 つ（約 32px × 3）＋カード 96 ＋2択 96 × 2 ＋後半開始 112 ＋間隔 12 × 7 で約 580px となり、高さ 576px を超える。
  → 修正案: screen-design を「4列」に直す。`SideColumn` を `ScrollContainer` ＋（`SecondHalfButton` を外に出して下端に固定）の構成にする（S-09 と同じ書き方）。
- [バグ] **S-08 の操作の列が高さ 576px を超える**: `Coach`（ワイヤーフレームで 88dp ＝ 176px）＋`ChoicePanel`（96px 以上）＋`TargetInfo`＋`PrimaryButton` 112＋`NextButton` 112＋間隔で、約 560〜730px になる（選べる手が 2 行になると確実に超える）。S-03 の判定理由の表示中（`JudgeTelop` の 4 要素＋ボタン）も、文が長いと 576px 前後になる。
  → 修正案: `SideColumn` の中身（主ボタンより上）を `ScrollContainer` に入れ、主ボタンは下端に固定すると screen-03 にも明記する。S-08 の「次へ」の重複を解消すれば 112px 減る。
- [バグ] **`quiz_progress()` の戻り値に `total` が無い**: `screen-09-quiz.md`「正答状況の数え方」と S-01（「3／8 正解」）は `total` を使うが、`component-design.md` §3.3 は `{"answered": int, "correct": int}` のまま。「最新の回答で数える」という規則も component-design 側には無い。
  → 修正案: component-design の `quiz_progress()` のコメントを `{"answered", "correct", "total"}`（correct は問題ごとの最新の回答）に直す。
- [バグ] **試合中に設定から音量を変えても反映されない／保存の時点が食い違う**: S-12 では、オーディオバスへの反映と `drag_ended` での保存を画面のスクリプトが行う。S-03 のメニューの設定（`SettingsOverlay`）は「`changed` を受けたら `save_settings()`」だけで、バスに反映しない。起動時は `MainShell` が反映するので、試合中に変えた音量は次の起動まで効かない。ドラッグ中も保存し続けるので、S-12 の「動かしている間は保存しない」とも食い違う。`SettingsPanel` のシグナルは `changed` だけなので、`drag_ended` を外から知る手段も無い。
  → 修正案: バスへの反映を `SettingsPanel`（または `UserDataService.save_settings` の後で App/MainShell が `settings_changed` を受けて行う）に寄せる。`SettingsPanel` に `commit_requested(settings)`（指を離したとき・トグルのとき）を足し、保存はそこだけで行う。
- [バグ] **S-07 の「動きの矢印つきミニピッチ」に必要な API と値が無い**: screen-common §5 の `MiniPitch` は `show_counts(counts, two_teams)` しか持たず、矢印の描き方が無い。`RevealView` にもエリアごとの人数が無い（`players_at_judgement` は選手単位なので、人数に直すと UI でのルール計算になる）。
  → 修正案: `MiniPitch` に `show_movements(movements)` を足すか、TurnRow には縮小した `TacticsBoard` を使うと決める。`RevealView` に `user_counts_at_judgement` / `opponent_counts_at_judgement` を足す。
- [バグ] **再開の失敗時に S-01 が `BUSY` のまま止まりうる**: `screen-01-title.md`「再開カードを押す」3 は、読み直しの失敗時に「`MatchController` が `storage_error(SUSPEND_LOAD)` を出してタイトルを要求し直す」ことを前提にしている。しかし `component-design.md` §3.2 の `resume()` は「進行段階を返す」とだけあり、画面を要求すること・失敗時の戻り値・エラー通知が書かれていない。controller がこの前提どおりに作られないと、タイトルは `BUSY` のまま（戻る操作も効かない）になる。
  → 修正案: `resume()` の説明に「再開先の画面を App に要求する。読めなければ削除して `storage_error(SUSPEND_LOAD)`、`request_screen(S01_TITLE)`」と足す。S-01 側でも、戻り値を見て `IDLE` に戻す保険を書く。
- [運用] **戦績・回答結果の件数の上限と 5MB の上限が噛み合わず、超えると全履歴が退避される**: data-definition §2.2／§2.3 は 0〜100,000 件を正常とするが、1 件が約 600〜900 バイト（timeline 込み）の戦績は、約 6,000〜8,000 件で 5MB を超える（component-design §4.3「数千件で 2MB に届かない」）。5MB を超えたファイルは「破損」として退避され初期状態に戻るため、利用者から見ると戦績が黙って全部消える。追記の側にも、上限を超えたときの動きが定められていない。
  → 修正案: 件数の上限を大きさから逆算した値（例: 戦績 5,000 件・回答 50,000 件）にする。上限に達したら古いものから捨てる（または追記を止めて通知する）と `append` / `save_quiz_answer` の仕様に書く。
- [バグ] **1 エリアに 5 人以上いるときの駒の描き方が未定義**: screen-common §5 の `TacticsBoard` は「各チーム4人まで重ならない」とだけある。人数の範囲は 0〜10 で、ヒントが OFF のときは人数を駒だけで読ませる（functional-overview 表示仕様）。
  → 修正案: 5 人以上は駒を 4 つ＋「+N」のバッジにする、駒を縮小する、のどちらかを決めて書く。

### Low / 改善提案
- [バグ] `screen-03-match.md`「演出の終了」3 は `show_snapshot(snapshot)` を使うが、`turn_resolved` で受けた `snapshot` を「画面の中だけで持つ値」に保持していない（`_reveal` だけ）。`_snapshot` を足す。
- [バグ] S-03「開示」2 で、演出の前にスコアを更新するため、得点のリプレイの前に結果が見えてしまう。意図どおりなら問題ないが、演出の終了後に更新するかを確認する。
- [バグ] ヒントの札の文言が、正本（functional-overview・ワイヤーフレーム）の `±0 GK外` と、`screen-03-match.md` の `±0 GK`・「カバーあり／GK／空」で違う。正本に合わせる。
- [バグ] `screen-07-review.md` の `_expanded`（複数可）と、「押すと右に直前のターンを出す（1 件選択）」の振る舞いが食い違う。`_selected_goal: int` に直す。
- [バグ] S-01 は `resume()` より前に `snapshot()` で再開カードを作る。`snapshot()` が中断データの読み込み前（起動直後など）に正しい値を返すことは、component-design に保証が無い。必要なら `suspended_summary()` のような専用の値にする。
- [バグ] `screen-09-quiz.md` の `_picked: int`（-1 で未選択）は、選択肢の `id: string` と照合する。型をそろえる（`String`、未選択は空文字）。
- [バグ] TacticsBoard の 1 エリアは 16:9 で高さ約 115px。駒を 2 段（52 × 2 ＝ 104px）にすると残りは約 11px で、左上の優劣記号・右上のヒントの札・左端のレーン名と駒が重なる。駒を置く範囲から、記号と札の帯を除くと決めておく。
- [運用] `keep_height` のため、16:9 より縦長の端末（タブレット・折りたたみ）では横幅が 1280px を下回り、本体が細くなる（1 エリアの横 192px の最小を割る）。NFR-25 の範囲外だが、配布の対象から外す（Play の対応端末の設定）か、最低幅を書いておく。
- [運用] `.steering/20261017-detail-design/requirements.md` の「`storage/`」は、実際のディレクトリ名 `data/` と違う。tasklist の「縦向きのみ」は経緯として残すなら問題ないが、`storage/` は直しておく。
- [バグ] S-01 の `FirstTimeBadge`（地 `you`）の文字色が書かれていない。screen-common §3 の `you` の項に合わせて `bg` の色にすると明記する。

### 問題なし
- **セキュリティ①（ハードコーディング）**: 変更・新規の全ファイル（.steering 含む）と 2 つの drawio を対象に、次を正規表現で検索した: URL（`http(s)://`）、メールアドレス、利用者のホームディレクトリや一時フォルダを示すローカルの絶対パス、claude.ai のリンク、`api_key`・`secret`・`token`・`password`、`arn:aws`、12 桁の数字。該当は 0 件。drawio のメタデータも `host="drawio"` だけで、端末名・ユーザー名・更新者は無い。`.gitignore` は `.env`・`.env.*`・`*.key` などを除外している。.steering の 4 ファイルにローカルパス・個人情報・アーティファクトのリンクは無い（「シャビ」の呼称だけ）。
- **セキュリティ②〜④・OWASP**: 認証・通信・SQL・シェル・ログ実装を含む差分は無い。保存データの読み込み時の検証（大きさの上限・型・範囲・正規表現・知らないキーの扱い）は data-definition に表で定義されており、改変されたファイルを全量読み込まない方針も維持されている（A08 の観点で問題なし。上限値の噛み合わせは Medium に記載）。
- **バグ（整合）**:
  - 寸法: 1280 = 24 + 728 + 24 + 480 + 24、21:9 の 1680 = 24 + 968 + 24 + 640 + 24、720 = 24 + 96 + 576 + 24。1 エリアは 728/3 × 576/5 ≒ 242 × 115px で、最小の 192 × 104px（96 × 52dp）を満たす。S-02 のカード (728 − 24)/2 = 352、S-01 の 600 + 24 + 632 + 24 = 1280、S-05 のカード 4 × 108 + 3 × 12 = 468 ≤ 480 も一致した。
  - 縦向きの記述: 1_requirements・2_basic-design・3_detail-design に「縦向き・縦長・360×800・64dp・攻撃方向を上」の残りは無い（NFR-25 の「縦向きには回転しない」と .steering の経緯の記述だけ）。ワイヤーフレームは 12 ページすべてに 800×360 の枠がある。
  - 判定の内訳: S-03 と screen-design は `RevealView` の `compare_area`・`user_count`・`opponent_count`・`cover` だけを使い、`NO_CONTEST` では隠す（`RevealView` の「NO_CONTEST では空」と一致）。種別の相性・読み当ては使っていない。
  - 部品名: component-design §5.3／§5.5 と §6 の名前一覧、screen-common §5 で、追加した部品（`MatchBoardPanel`・`ScoreBug`・`ScreenHeader`・`FormationCard`・`MatchMenu`・`SettingsPanel`・`SimplificationList`・`NewMatchGate`）の名前がそろっている。`App.request_screen`、`defense_style_notes` / `attack_style_notes`、`BoardSnapshot.last_goal_by` も component-design に反映済み。
  - 保存・削除の時点: S-01 / S-02 / S-04 / S-05 / S-06 / S-11 の記述（削除の時点①②④、保存の時点①〜④、`FINALIZE_PENDING` の手順）は、component-design §3.2 と usecase UC-01 / 04 / 05 と矛盾しない。
  - 設定の初期値（0.7・true・false）は component-design §4.3 と data-definition §2.4 で一致する。
  - S-03 の状態遷移図（drawio）の遷移と、本文の状態表・イベント処理は一致する。
- **性能**: 戦績一覧の 50 件ずつの描画は、数千件規模を想定した方針として妥当（件数の上限は Medium を参照）。

### 未検証
- `usecase-sequences.drawio`（変更なし）の各シーケンスと詳細設計の手順の 1 対 1 の突き合わせ（本文の usecase.md だけで照合した）。
- ワイヤーフレームは S-03・S-05・S-08 の座標と、全ページの枠だけを確認した。その他 9 ページの細部の配置と screen-design の文の一致は見ていない。
- 配色のコントラスト比（screen-common §3 の数値）は再計算していない。
- 文字幅の見積もり（High の 1 件目）は、等幅を仮定した概算（全角 = 文字の大きさ、半角 ≒ 0.5 倍）。実際の Noto Sans JP・Barlow Condensed で測ってはいないが、超過幅が大きい（約 1.5 倍）ため結論は変わらないと判断した。

### 総合評価
**Critical なし。High 2 件あり（S-03 の上部バーが 16:9 の幅にあふれる、背番号つき駒の描画に必要な値が `BoardSnapshot` に無い）。** どちらも、実装者がそのまま作ると表示の欠けか UI へのルール漏れになる仕様の食い違いなので、コミット前に直すことを勧める。セキュリティ（ハードコーディング・ローカルパス・個人情報・リンクの混入）の指摘はない。Medium の 9 件は、近いうちに直せばよい。

### 対応
- **High 1（上部バーが 16:9 にあふれる）**: 修正した。
  - 上部バーには、メニュー・`ScoreBug`・局面のタグだけを置く。両チームの陣形・方式は、操作の列の上端の `SetupCard` に移した（2段、ELLIPSIS。常に表示）。
  - 開示中の `RevealBanner` は2段にした。
  - screen-common §1.1 に、「ヘッダーは 16:9 の 1232px に収め、いちばん長い文言で確かめる。可変の文言には ELLIPSIS」を足した。
  - screen-design と S-03 のワイヤーフレームも同じ配置に直した。
- **High 2（背番号つきの駒の値が無い）**: 修正した。
  - `BoardSnapshot` に `user_players` / `opponent_players`（`player_id`・`number`・利用者の視点の `area`）を足した。`user_counts` はこれを数えた値と一致する、と明記した。
  - `RevealView.players_before` / `players_at_judgement` も同じ形にした。
  - `TacticsBoard` の描き方を、選手ごとに背番号つきで描く形にした。
- **Medium**: 9件とも直した。
  - S-07 のミニピッチ: `MiniPitch` に `show_movements(movements)` を足した。判定時の人数は `RevealView.players_at_judgement` をエリアごとに数えるだけ（ルールの計算ではない）と明記した。
  - `MatchBoardPanel` と S-03 の役割分担: 状態と `turn_resolved` の受信はパネルが持つ、と決めた。上部バーはパネルのシグナル（`turn_started`・`reveal_started`・`result_shown`）で画面が描き直す。パネルに `bind(..., show_next)`・`start_turn()` を足した。S-08 は `show_next = false` にし、判定後は「決定」を隠して「次へ」だけにした。
  - S-05 の陣形カード: screen-design を「横に4つ」にそろえた。操作の列を「スクロールする中身＋下端に固定した主ボタン」の構成にした。
  - 操作の列のあふれ: screen-common §1.1 で、操作の列は「上端の固定部分・スクロールする中身・下端の主ボタン（固定）」の3段、と決めた。S-03・S-05 のツリーをこの形にした。
  - `quiz_progress()`: 戻り値に `total` を足し、「問題ごとの最新の回答で数える」と明記した。
  - 設定の音量: `SettingsPanel` が `changed` のたびにバスへ反映する形にした。保存は新しいシグナル `committed`（指を離したとき・トグルのとき）で行う。S-03 のメニューの設定と S-12 も、この形にそろえた。
  - `resume()`: 戻り値を `bool` にした。再開先の画面を App に要求する。失敗したら中断データを削除し、`storage_error(SUSPEND_LOAD)` を出して S-01 を要求し直し、`false` を返す。S-01 には、`false` のときに `IDLE` へ戻す保険を足した。
  - 件数の上限: 戦績を 3,000件、回答結果を 30,000件にした。どちらも、上限に達したら古いものから捨てて追記する（`RecordStore.append` に明記）。
  - 5人以上の駒: 駒を3つと「+N」の札にする。あわせて駒の直径を 40px にし、エリアの上端 32px を記号と札の帯に分けた（Low の「駒と記号の重なり」も解消）。
- **Low**: 直したもの。
  - `_snapshot` を足した。
  - スコアの更新を演出の後にした（得点の結果を先に見せない）。
  - ヒントの札の文言を `CoverKind` ごとに正本（`GK外` を含む）へそろえた。
  - S-07 の `_selected_goal` と、S-09 の `_picked: String`。
  - `snapshot()` が再開前に中断データの状態を返すことを、component-design に明記した。
  - `FirstTimeBadge` の文字の色。
  - 16:9 より縦長の端末を配布の対象から外す方針を、screen-common に書いた。
  - steering の `storage/` を `data/` に直した。

## 第2回（2026-10-18）— 修正後の再レビュー
- 対象: 前回の指摘への修正と、修正が触った箇所の周辺（component-design・screen-design・wireframes.drawio の S-03／S-08、screen-common §1.1・§5、screen-01／03／05／07／08／09／12、data-definition、.steering）。照合のため usecase.md UC-05 と usecase-sequences.drawio の seq-uc01-2-turn・seq-uc05-resume を読んだ
- 結果: Critical 0件 / High 0件 / Medium 2件 / Low 9件

### (a) 前回の指摘ごとの判定

| 前回の指摘 | 判定 | 根拠 |
|---|---|---|
| High1: S-03 の上部バーのあふれ | 解消 | 上部バーは メニュー 96 ＋ ScoreBug 約 470 ＋ 最長の PhaseTag 約 500 ＝ 約 1,070px で、1232px に収まる。陣形・方式は `SetupCard`（2段、ELLIPSIS）へ移った。`RevealBanner` は2段で、残りの幅は約 630px。§1.1 に検査の規則も入った |
| High2: 背番号つきの駒に必要な値が無い | 解消 | `BoardSnapshot.user_players` / `opponent_players`（`player_id`・`number`・`area`）が入った。counts と一致することも明記された。`RevealView.players_*` も同じ形になった |
| M: MatchBoardPanel と画面の役割分担 | 解消（S-03 側）／S-08 側は別の問題を持ち込んだ（下の Medium 1） | S-03 では、状態と `turn_resolved` はパネル、遷移と上部バーは画面、という分担がシグナルで一貫している |
| M: S-05 の陣形カードと列のあふれ | 解消 | screen-design は「横に4つ」。`SideColumn` は「スクロールする中身 ＋ 下端に固定したボタン」の構成になった |
| M: S-08・S-03 の操作の列のあふれ | 解消 | §1.1 で3段の構成を決め、S-03 のツリーもその形になった |
| M: `quiz_progress()` に `total` が無い | 解消 | `total` と「最新の回答で数える」が component-design に入った |
| M: 試合中の音量が反映されない・保存の時点 | 解消 | 反映は `SettingsPanel` の `changed`、保存は `committed`。S-03 と S-12 で一致する（残る小さな問題は Low） |
| M: S-07 のミニピッチ | 解消 | `MiniPitch.show_movements` が入った。人数は `players_at_judgement` を数えるだけ |
| M: `resume()` の失敗時 | 解消 | component-design・S-01・seq-uc05（成功時に画面を要求）が一致する。失敗の経路は usecase に未反映（Low） |
| M: 件数の上限と 5MB | 一部未解消（下の Medium 2） | 3,000件 × 約1KB ＝ 約3MB という前提は、項目の範囲では保証されていない |
| M: 5人以上の駒 | 解消 | 駒3つ ＋「+N」 |
| Low（直したと書かれたもの: `_snapshot`、スコアの更新時点、`GK外`、`_selected_goal`、`_picked: String`、`snapshot()` の再開前の値、`FirstTimeBadge`、縦長の端末の方針、`storage/` → `data/`） | すべて解消 | `GK外` などの文言は `CoverKind { NONE, DEFENDER, GOALKEEPER, OUT_OF_GK_REACH }` と対応している |

### Critical（即時対応必須）
- なし

### High（優先対応）
- なし

### Medium（対応推奨）
1. [バグ] **S-08 でのパネルのつなぎ方が決まっておらず、二重受信と止まったままの盤面が起こりうる**（`screen-08-tutorial.md` ノード構成の注記・「段階を始める」）
   - 選べる手の絞り込み（`options_filter`）は `bind()` の引数でしか渡せない。段階ごとに手が変わるため `bind()` を毎回呼ぶことになるが、`bind()` の中で `turn_resolved` をつなぐので、つなぎ直すたびに受信が重なり、開示と演出が2回走る。
   - S-03 は `start_turn()` を明示的に呼ぶが、S-08 の「段階を始める」は `start_tutorial_step()` の後に「MatchView に描く」とだけ書いており、`start_turn()` を呼ばない。パネルは `SELECT_ACTION` に入らず、手のボタンも出ない。
   - `EXPLAIN` で「`ChoicePanel` と『決定』を隠す」ためのパネルの API が無い。
   - パネルが出す `turn_started` / `reveal_started` を S-08 が受けていないので、ヘッダーの `PhaseTag` が更新されない。
   - 両者の選択の帯（FR-09）を S-08 のどこに出すかも書かれていない。
   → 修正案: `bind()` は `enter` で1回だけ呼び、2回目以降は何もしないと明記する。パネルに `set_options_filter(actions)`・`set_interactive(enabled: bool)`（`EXPLAIN` 用）を足す。「段階を始める」に `start_tutorial_step(step)` → `set_options_filter(step.allowed_actions)` → `BoardPanel.start_turn()` の順を書く。S-08 が `turn_started` / `reveal_started` を受けて `PhaseTag` と選択の帯を描くと書く。
2. [運用] **件数の上限と 5MB は、平均 1KB 以下という前提でしか噛み合わない**（`data-definition.md` §2.2）
   - `records[].timeline` は「1〜50件」まで正常とされている。1件の推移は約 150 バイトなので、推移が 50件ある戦績は約 7.7KB になる。
   - 1ハーフのターン数から見ると推移は最大でも約 26件で、約 4KB になる。仮に 3,000件 × 4KB とすると約 12MB で、5MB を超える。
   - 5MB を超えたファイルは「破損」として退避され、戦績が黙ってすべて消える（前回の Medium と同じ結果になる）。
   - 平均的な使い方なら 1件あたり 1KB 前後なので、条件付きの指摘にとどめる。
   → 修正案: `timeline` の上限を「1ハーフのターン数 × 2 ＋ 2」に締める。そのうえで最悪の大きさ × 件数の上限が 5MB を下回るように、件数の上限を決め直す（例: 1件の最悪 4KB なら 1,000件）。あるいは `append` で、件数ではなくファイルの大きさ（例: 4MB）を超えたら古いものから捨てる。あわせて、`totals()` の「通算は全件から」が「保持している直近の件数から」になることを S-11・component-design に書く。

### Low / 改善提案
- [バグ] `screen-03-match.md`「処理の持ち主」は、`state_changed` を受けたら「進行段階が `TURN` のままなら `start_turn()`」と書いている。一方、component-design の `state_changed` のコメントは「盤面・スコア・相手の方式が変わった」と広い。`submit_turn` の中でも発火する実装にすると、演出中にターンがリセットされる（seq-uc01-2-turn では `continue_after_reveal` の後だけ）。`state_changed` は `continue_after_reveal` の後にだけ出すと component-design に書くか、画面の側でパネルの状態が `LEAVING` のときだけ受けるようにする。
- [運用] `resume()` の失敗の経路（削除、`SUSPEND_LOAD`、S-01 を要求、`false` を返す）は、`usecase.md` UC-05 の 4. と `seq-uc05-resume` に反映されていない。成功の経路は一致している。
- [バグ] screen-common §1.1 の「作戦ボードの1エリア 高さ 104px 以上」では、新しい駒の配置（上端の帯 32 ＋ 駒 40 × 2段 ＝ 112px）が収まらない。基準の 115px では 3px の余りで収まる。最小値を 112px（56dp）に上げるか、最小の高さでは駒を1段にすると書く。
- [バグ] `committed` はスライダーの `drag_ended` とトグルでしか出ない。キーボードやゲームパッド（後続の Windows 版）で変えた値は保存されない。パネルを閉じるときにも `committed` を出すと足す。
- [バグ] `ReplayLayer` は `Columns` の兄弟として `BoardPanel` 全体に重ねる。`MatchBoardPanel` のルートがコンテナ（`VBoxContainer` など）だと縦に並んでしまうので、ルートは `Control` で、`ReplayLayer` は全面アンカーと明記する。
- [バグ] S-03「メニュー」2. の「ターンを始める の 2. をやり直す」は、今はパネルの中の処理なので、画面から呼ぶ API（例 `BoardPanel.refresh_hints()`）が要る。
- [運用] data-definition §2.3 の「古い回答を捨てても数え方は変わらない」は厳密ではない（ある問題の回答がすべて捨てられると `answered` が減る）。「実用上は変わらない」くらいの表現にする。
- [運用] ワイヤーフレームの S-03 の `SetupCard` は1行の表記（詳細設計は2段）。S-08 のヘッダーに `PhaseTag` が描かれていない。
- [バグ] S-08 の `OPERATE` では、判定前は「決定」と押せない「次へ」が両方とも列の下端に固定されるため、スクロールする中身に残る高さは約 230px になる。`_can_next` が偽の間は「次へ」を隠すと、説明文と手のボタンが一度に見える。

### (b) 指定の確認点
- **MatchBoardPanel と MatchScreen の分担**: S-03 と screen-common §5 は一致している（状態と `turn_resolved` はパネル、遷移と上部バーは画面、受け渡しは `turn_started`・`reveal_started`・`result_shown`・`turn_ready_to_leave`）。S-08 とは食い違いがある（Medium 1）。
- **S-03 のノード構成の入れ子**: 正しい。`SideColumn` の下は `SetupCard`（固定）→ `SideScroll/SideBody`（`SideTopSlot`・`ChoicePanel`・`TargetInfo`・`JudgeTelop`）→ `PrimaryButton`（固定）→ `SideBottomSlot` で、§1.1 の3段に合っている。注意はパネルのルートの型だけ（Low）。
- **`resume()` を bool にした変更**: component-design・screen-design（S-01 のイベント表「進行段階に応じて S-03〜05 へ」）・S-01・seq-uc05 と矛盾しない。usecase に失敗の経路が無いだけ（Low）。
- **件数の上限と 5MB**: 平均の大きさの前提に依存している（Medium 2）。回答結果は 30,000件 × 約 75 バイト ＝ 約 2.3MB で、問題なし。
- **駒の直径 40px と、エリア 115px・帯 32px**: 縦は 32 ＋ 40 × 2 ＝ 112 ≤ 115、横は 2 × 40 ＝ 80 ≤ 121（半分の幅）で収まる。最小の 104px とは食い違う（Low）。

### 問題なし
- **セキュリティ**: 修正後の 3_detail-design と .steering（新しい `review-report.md` を含む）を再検索した。ローカルの絶対パス、一時フォルダ・作業用フォルダのパス、claude.ai のリンク、メールアドレス、ユーザー名、12 桁の数字、トークン類は該当なし（`user://` は Godot の保存先の表記で問題ない）。前回の報告のパスの例は、review-report では一般化した言い方に置き換わっている。
- **バグ（整合）**:
  - 上部バーの幅の再計算。
  - `BoardSnapshot` と `RevealView` の選手単位の形が一致していること。
  - `CoverKind` と札の文言の対応。
  - S-03 の開示〜演出の終了で `_snapshot` を使うことと、スコアの更新の時点。
  - S-05・S-07・S-09・S-12 の修正箇所。
  - `quiz_progress` の `total`。
  - `RecordStore.append` で古いものから捨てる規則と、data-definition の記述の一致。

### 未検証
- `wireframes.drawio` は、S-03・S-08 の各ページの文字と座標だけを確認した。その他のページは、今回の修正の対象外として見ていない。
- 前回の未検証欄のうち、usecase-sequences.drawio は seq-uc01-2-turn と seq-uc05-resume だけを照合した。その他のシーケンスと配色のコントラスト比は、今回も見ていない。
- 文字幅は前回と同じく概算（全角は文字の大きさ、半角はその約 0.5 倍）で、実際のフォントでは測っていない。

### 総合評価
**Critical なし、High なし。** 前回の High 2件は解消した。Medium 9件のうち 8件は解消し、件数の上限は一部が未解消。修正によって S-08 のパネルのつなぎ方に新しい Medium が1件入った。コミットしてよい水準だが、Medium 2件（S-08 のパネルのつなぎ方、戦績の大きさの上限）は、実装に入る前に直すことを勧める。

### 対応
- **Medium 1（S-08 のパネルのつなぎ方）**: 修正した。
  - `bind(controller, show_next)` は画面の `enter` で1回だけ呼び、2回目以降は何もしない、と明記した。
  - パネルに `set_options_filter()`・`set_interactive()`・`refresh_hints()` を足した。
  - S-08 の「段階を始める」に、`start_tutorial_step` → `set_options_filter` → `set_interactive` → `start_turn` の順を書いた。
  - S-08 がパネルのシグナルを受けて `PhaseTag`・`RevealBanner`（両者の選択の帯）を描き、`turn_ready_to_leave` で「次へ」を押せるようにする、と書いた。
- **Medium 2（戦績の大きさの上限）**: 修正した。
  - `timeline` の上限を「1ハーフのターン数 × 2 ＋ 2」件にした。
  - `RecordStore.append` で、件数の上限か書き込み後の大きさ 4MB を超えるなら、古いものから捨てる形にした。
  - 通算（`totals()`）は保持している戦績から数える、と component-design・data-definition・S-11 に書いた。
- **Low**: 直したもの。
  - `state_changed` はターンの途中では出さない、と component-design に書いた。
  - usecase.md UC-05 に、`resume()` の失敗の経路を足した（usecase-sequences.drawio の図は成功の経路のまま）。
  - 1エリアの最小の高さを 112px（56dp）にした。
  - `committed` をパネルを閉じるときにも出すようにした。
  - パネルのルートを `Control` にし、`ReplayLayer` は全面アンカーで重ねる、と書いた。
  - `refresh_hints()` を足した（S-03 のメニューの手順も直した）。
  - 回答を捨てたときの表現を「実用上は変わらない」に直した。
  - `_can_next` が偽の間は「次へ」を隠すようにした。

## レビュー完了（2026-10-18）
- 最終ラウンド: 第2回
- 新たな Critical / High: なし
- 積み残し（Medium / Low を申し送る場合）:
  - ワイヤーフレームの S-08 のヘッダーに、局面のタグを描いていない（図の描き分けだけの不足で、詳細設計には書いてある）。
  - usecase-sequences.drawio の seq-uc05-resume に、失敗の経路を描いていない（usecase.md の本文には反映済み）。
  - 第2回の Medium 2件と Low の修正は再レビューしていない（スキルの規則で、Medium / Low はループを回す理由にならないため）。
  - 実際のフォントでの文字幅は、まだ測っていない。実装時に、ヘッダーと操作の列が 16:9 で収まることを確かめる（screen-common §1.1 の検査の項目）。
