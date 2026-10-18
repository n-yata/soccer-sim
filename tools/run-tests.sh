#!/usr/bin/env bash
# テストの一括実行。リポジトリのどこから実行してもよい。
#   tools/run-tests.sh
# Godot は環境変数 GODOT_BIN、無ければ PATH の godot を使う。
#
# 次の順に実行し、1つでも失敗したら終了コード 1 で終わる。
#   0. プロジェクトの取り込み（class_name のキャッシュの更新と、取り込みのエラーの確認）
#   1. 禁止依存の検査の自己確認（全ルールが当たる／誤検出しない／検査できないときは失敗する）
#   2. game/domain/ の禁止依存の検査（NFR-13）
#   3. gdUnit4 のテスト（0件で終わった場合も失敗として扱う）
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
game_dir="$repo_root/game"
checker="$repo_root/tools/check_domain_deps.gd"
fixtures="res://tests/fixtures/forbidden_deps"
godot="${GODOT_BIN:-godot}"
failed=0

if ! command -v "$godot" >/dev/null 2>&1; then
	echo "Godot が見つからない: $godot（GODOT_BIN で指定する）" >&2
	exit 1
fi

run_checker() {
	"$godot" --headless --path "$game_dir" --script "$checker" -- "$@" 2>&1
}

# 終了コードだけで成功と判断しない。実行時エラーで処理が打ち切られても終了コードが 0 になる経路があるため、
# 最後まで走ったときにだけ出る行を必須にする（fail closed）

# 実行時エラーが出ていないこと（関数が途中で打ち切られても、処理が先へ進んで成功の行が出ることがある）
no_script_error() {
	! grep -q "SCRIPT ERROR" <<<"$1"
}

# 「check_domain_deps: ... を検査し、禁止した参照が 0 件」の行があり、実行時エラーが無いこと
finished_clean() {
	grep -qE "^check_domain_deps: .* 件を検査し、禁止した参照が 0 件$" <<<"$1" && no_script_error "$1"
}

# 「self-check: [カテゴリ] ルール N 件中 N 件、行 M 件中 M 件を検出した」で、N・M がそれぞれ一致し 0 でないこと
all_rules_hit() {
	local rules_total rules_hit lines_total lines_hit
	rules_total="$(sed -E 's/.*ルール ([0-9]+) 件中 ([0-9]+) 件、行 ([0-9]+) 件中 ([0-9]+) 件.*/\1/' <<<"$1")"
	rules_hit="$(sed -E 's/.*ルール ([0-9]+) 件中 ([0-9]+) 件、行 ([0-9]+) 件中 ([0-9]+) 件.*/\2/' <<<"$1")"
	lines_total="$(sed -E 's/.*ルール ([0-9]+) 件中 ([0-9]+) 件、行 ([0-9]+) 件中 ([0-9]+) 件.*/\3/' <<<"$1")"
	lines_hit="$(sed -E 's/.*ルール ([0-9]+) 件中 ([0-9]+) 件、行 ([0-9]+) 件中 ([0-9]+) 件.*/\4/' <<<"$1")"
	[ -n "$1" ] && [ "$rules_total" -gt 0 ] && [ "$rules_total" = "$rules_hit" ] \
		&& [ "$lines_total" -gt 0 ] && [ "$lines_total" = "$lines_hit" ]
}

echo "== 0. プロジェクトの取り込み（class_name のキャッシュの更新）"
# 新しく足した class_name は、エディタで取り込むまでグローバルなクラスの一覧に載らない。
# ここではスクリプト全体はコンパイルされない。構文エラーは手順3（テストが読み込むとき）で検出される
output="$(cd "$game_dir" && "$godot" --headless --editor --quit 2>&1)"
status=$?
errors="$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -E "ERROR|Parse Error|SCRIPT ERROR")"
if [ "$status" -ne 0 ] || [ -n "$errors" ]; then
	echo "NG: 取り込みでエラーが出た（終了コード $status）"
	echo "$errors"
	failed=1
else
	echo "OK"
fi

echo "== 1. 禁止依存の検査の自己確認"
# 各カテゴリの fixture で、そのカテゴリの全ルールが当たり、ほかのカテゴリが当たらないこと（ルールの空振りの検出）
for category in node file time random; do
	output="$(run_checker "$fixtures/$category" --self-check "$category")"
	status=$?
	summary="$(grep -E "^self-check: \[$category\] ルール [0-9]+ 件中 [0-9]+ 件、行 [0-9]+ 件中 [0-9]+ 件を検出した$" <<<"$output" | tail -1)"
	if [ "$status" -ne 0 ] || ! all_rules_hit "$summary" || ! no_script_error "$output"; then
		echo "NG: $category の自己確認が失敗した（終了コード $status）"
		echo "$output" | grep -E "self-check|check_domain_deps|SCRIPT ERROR"
		failed=1
	else
		echo "OK: $summary"
	fi
done
# コメント・文字列の中の語は検出しないこと
output="$(run_checker "$fixtures/clean")"
status=$?
if [ "$status" -ne 0 ] || ! finished_clean "$output"; then
	echo "NG: コメント・文字列の中の語を誤検出した、または検査を最後まで行えなかった（終了コード $status）"
	echo "$output"
	failed=1
else
	echo "OK: コメント・文字列の中の語は検出しない"
fi
# 検査できないとき（ディレクトリが無い・スクリプトが0件）を「違反なし」にしないこと
for target in "res://no_such_directory" "res://content"; do
	run_checker "$target" >/dev/null
	status=$?
	if [ "$status" -ne 2 ]; then
		echo "NG: 検査できない対象（$target）で終了コードが 2 にならない（$status）"
		failed=1
	else
		echo "OK: 検査できない対象（$target）は失敗として扱う"
	fi
done

echo "== 2. game/domain/ の禁止依存の検査"
output="$(run_checker "res://domain")"
status=$?
echo "$output" | grep -v "^Godot Engine"
if [ "$status" -ne 0 ] || ! finished_clean "$output"; then
	echo "NG: 禁止依存の検査が失敗した、または最後まで行えなかった（終了コード $status）"
	failed=1
fi

echo "== 3. gdUnit4 のテスト"
# --remote-debug tcp://127.0.0.1:0 は、構文エラーのときに対話式のデバッガで止まらないための指定（gdUnit4 の runtest と同じ）
output="$(cd "$game_dir" && "$godot" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests 2>&1)"
status=$?
plain="$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')"
echo "$plain" | grep -E "FAILED|Statistics|Executed test|No test cases|Exit code"
if [ "$status" -ne 0 ]; then
	# 失敗したときだけエラー行を出す。成功時のエラー行は、異常系のテストが意図して起こしたもの（push_error）。
	# リモートデバッガの接続エラー2行は、上の指定による想定どおりの出力なので外す
	echo "$plain" | grep -E "ERROR|Parse Error|SCRIPT ERROR" \
		| grep -vE "remote port number|Remote Debugger: Unable to connect"
	echo "NG: gdUnit4 が失敗した（終了コード $status）"
	failed=1
elif grep -q "No test cases found" <<<"$output"; then
	echo "NG: テストが1件も実行されなかった"
	failed=1
else
	# 「Executed test suites: (実行数/総数)」が出ていて、両者が一致すること（読み込めずに飛ばされたスイートを見逃さない）
	suites="$(grep -oE "Executed test suites: \([0-9]+/[0-9]+\)" <<<"$plain" | tail -1 | grep -oE "[0-9]+/[0-9]+")"
	if [ -z "$suites" ] || [ "${suites%/*}" != "${suites#*/}" ] || [ "${suites%/*}" -eq 0 ]; then
		echo "NG: 実行したテストスイートの数を確かめられない、または一部が実行されていない（${suites:-出力なし}）"
		failed=1
	fi
fi

if [ "$failed" -ne 0 ]; then
	echo "== 失敗"
	exit 1
fi
echo "== すべて成功"
