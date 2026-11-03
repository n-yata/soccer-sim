#!/usr/bin/env bash
# テストの一括実行。リポジトリのどこから実行してもよい。
#   tools/run-tests.sh                 （ゲームバランスの計測 tests/balance/ を除く）
#   tools/run-tests.sh --with-balance  （ゲームバランスの計測も流す。規則・初期値・CPU を変えたとき）
# Godot は環境変数 GODOT_BIN、無ければ PATH の godot を使う。
#
# 次の順に実行し、1つでも失敗したら終了コード 1 で終わる。
#   0. プロジェクトの取り込み（class_name のキャッシュの更新と、取り込みのエラーの確認）
#   1. 禁止依存の検査の自己確認（全ルールが当たる／誤検出しない／検査できないときは失敗する）
#   2. game/domain/ の禁止依存の検査（NFR-13）
#   3. gdUnit4 のテスト（0件で終わった場合も失敗として扱う）
# 既定の実行は3分以内に収める（開発の待ち時間を短くする。超えたら失敗として扱う）。
# バランスの計測は試合を数百回回すので、それだけで約4分かかるため、既定では流さない
set -u

time_limit_seconds=180
started_at="$(date +%s)"
with_balance=0
for arg in "$@"; do
	case "$arg" in
		--with-balance) with_balance=1 ;;
		*) echo "不明な引数: $arg（使えるのは --with-balance だけ）" >&2; exit 1 ;;
	esac
done
if [ "$with_balance" -eq 1 ]; then
	# バランスの計測を含めるときは3分に収まらないので、止めるまでの時間だけ延ばす（3分の判定はしない）
	time_limit_seconds=600
fi

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


if [ "$with_balance" -eq 0 ]; then
	echo "== 3. gdUnit4 のテスト（ゲームバランスの計測を除く。含めるときは --with-balance）"
else
	echo "== 3. gdUnit4 のテスト（ゲームバランスの計測を含む）"
fi
# - gdUnit4 のコンソール出力は捨て、結果はレポート（results.xml）から読む。Windows では Godot の標準出力への書き込みが
#   1回あたり数ms〜十数msかかり、gdUnit4 はテスト1件ごとに数回書くため、出力を受け取るだけで数分延びる（2026-11-03 に計測）
# - APPDATA を作業用のディレクトリに向け、user:// を実行ごとに別にする。gdUnit4 はスイートを終えるたびに user://tmp を消すので、
#   同じ user:// を使うほかの実行（別のセッション）の一時ファイルを消さない。本物の保存データにも触れない
# - 残り時間で timeout をかけ、3分を超えたら止めて失敗にする
# - tests/ の直下のディレクトリごとに Godot を起動し直し、順に流す。1本で全部を流すと、後になるほど遅くなり
#   （メモリが数GB まで膨らむ）、分けて流した合計より1分以上長くかかった（2026-11-03 に計測）
# - 並行では流さない（何本も立てるとメモリが足りなくなる）。時間はテストの量で収める
# エラー出力は件数が少ないので、失敗したときの手がかりとしてファイルに残す。
# --remote-debug tcp://127.0.0.1:0 は、構文エラーのときに対話式のデバッガで止まらないための指定（gdUnit4 の runtest と同じ）
work_dir="$(mktemp -d)"
# 失敗したときは、エラー出力と gdUnit4 のレポートを調べられるよう残す
trap 'if [ "$failed" -eq 0 ]; then rm -rf "$work_dir"; else echo "調べるためのファイルを残した: $work_dir"; fi' EXIT
suites_all=()
while IFS= read -r path; do
	suites_all+=("res://${path#"$game_dir"/}")
done < <(find "$game_dir/tests" -name "*_test.gd" | sort)
suites=()
for suite in "${suites_all[@]}"; do
	if [ "$with_balance" -eq 1 ] || [[ "$suite" != res://tests/balance/* ]]; then
		suites+=("$suite")
	fi
done
expected_suites="${#suites[@]}"
# res://tests/<ディレクトリ>/... の <ディレクトリ> ごとにまとめる
batches=()
for suite in "${suites[@]}"; do
	batch="${suite#res://tests/}"
	batch="${batch%%/*}"
	if [[ " ${batches[*]} " != *" $batch "* ]]; then
		batches+=("$batch")
	fi
done
groups="${#batches[@]}"
mkdir -p "$work_dir/appdata"
status=0
timed_out=0
for ((group = 0; group < groups; group++)); do
	args=()
	for suite in "${suites[@]}"; do
		if [[ "$suite" == "res://tests/${batches[$group]}/"* ]]; then
			args+=(-a "$suite")
		fi
	done
	remaining=$((time_limit_seconds - ($(date +%s) - started_at)))
	if [ "$remaining" -lt 1 ]; then
		timed_out=1
		break
	fi
	(cd "$game_dir" && APPDATA="$(cygpath -w "$work_dir/appdata" 2>/dev/null || echo "$work_dir/appdata")" \
		timeout -k 10 "$remaining" "$godot" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
		res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode "${args[@]}" \
		-rd "$(cygpath -m "$work_dir/reports$group" 2>/dev/null || echo "$work_dir/reports$group")" -rc 1 \
		>/dev/null 2>"$work_dir/stderr$group.log")
	code=$?
	if [ "$code" -eq 124 ]; then
		timed_out=1
		break
	elif [ "$code" -ne 0 ]; then
		status="$code"
		# 101 は孤立したノードの警告（失敗・エラーは0件）。どのディレクトリで起きたかとエラー出力の末尾を出す
		echo "NG: tests/${batches[$group]} が終了コード $code で終わった。エラー出力の末尾:"
		tail -n 20 "$work_dir/stderr$group.log"
	fi
done
reports=()
while IFS= read -r path; do
	reports+=("$path")
done < <(find "$work_dir" -name results.xml)
if [ "$timed_out" -eq 1 ]; then
	echo "NG: ${time_limit_seconds} 秒を超えたので止めた（既定の実行は3分以内に収める）"
	# 起動したのが本体を子として立てるラッパー（*_console.exe）だと、本体が残ることがある。残ると次の実行のメモリを圧迫する
	if tasklist 2>/dev/null | grep -qi "godot"; then
		echo "注意: Godot がまだ動いている。止めてから次を流すこと（tasklist で確かめる）"
	fi
	failed=1
elif [ "${#reports[@]}" -ne "$groups" ]; then
	echo "NG: gdUnit4 のレポート（results.xml）が ${groups} 個そろっていない（${#reports[@]} 個。終了コード $status）"
	cat "$work_dir"/stderr*.log | grep -E "SCRIPT ERROR|Parse Error"
	failed=1
else
	# スイートごとの件数を足し合わせる（<testsuite ... tests="N" failures="N" errors="N" ...>）
	read -r ran tests failures errors < <(cat "${reports[@]}" | grep -oE '<testsuite [^>]*>' | awk '
		{ n++; for (i = 1; i <= NF; i++) { split($i, kv, "="); gsub(/"/, "", kv[2]);
			if (kv[1] == "tests") t += kv[2]; else if (kv[1] == "failures") f += kv[2]; else if (kv[1] == "errors") e += kv[2] } }
		END { print n + 0, t + 0, f + 0, e + 0 }')
	echo "Executed test suites: ($ran/$expected_suites)"
	echo "Executed test cases : $tests（失敗 $failures・エラー $errors）"
	if [ "$failures" -ne 0 ] || [ "$errors" -ne 0 ] || [ "$status" -ne 0 ]; then
		# 落ちたテストの名前と、失敗の文面（CDATA の中身）を出す
		cat "${reports[@]}" | awk '/<testcase /{ match($0, /name="[^"]*"/); name = substr($0, RSTART + 6, RLENGTH - 7);
				match($0, /classname="[^"]*"/); suite = substr($0, RSTART + 11, RLENGTH - 12) }
			/<failure |<error /{ print "FAILED: " suite " > " name; body = 1; next }
			/<\/failure>|<\/error>/{ body = 0 }
			body && !/CDATA|\]\]>/{ print "    " $0 }'
		# 成功時のエラー行は、異常系のテストが意図して起こしたもの（push_error）なので、失敗したときだけ出す
		cat "$work_dir"/stderr*.log | grep -E "SCRIPT ERROR|Parse Error"
		echo "NG: gdUnit4 が失敗した（終了コード $status）"
		failed=1
	elif [ "$tests" -eq 0 ]; then
		echo "NG: テストが1件も実行されなかった"
		failed=1
	elif [ "$ran" -ne "$expected_suites" ]; then
		# 読み込めずに飛ばされたスイート（構文エラー等）を見逃さない
		echo "NG: 実行したテストスイートの数が tests/ の *_test.gd の数と合わない（$ran/$expected_suites）"
		cat "$work_dir"/stderr*.log | grep -E "SCRIPT ERROR|Parse Error"
		failed=1
	fi
fi

elapsed=$(($(date +%s) - started_at))
if [ "$with_balance" -eq 0 ] && [ "$elapsed" -gt "$time_limit_seconds" ]; then
	echo "NG: 全体で ${elapsed} 秒かかった（${time_limit_seconds} 秒以内に収める）"
	failed=1
fi
if [ "$failed" -ne 0 ]; then
	echo "== 失敗（${elapsed} 秒）"
	exit 1
fi
echo "== すべて成功（${elapsed} 秒）"
