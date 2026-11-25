#!/usr/bin/env bash
# ブラウザ版（PWA）の書き出し。リポジトリのどこから実行してもよい。
#   soccer-game/tools/export-web.sh <出力先のディレクトリ>
# 出力先は実行した場所からの相対パスでもよい。中身は書き出しの前に消す。
# Godot は環境変数 GODOT_BIN、無ければ PATH の godot を使う。Web の書き出しテンプレート
# （web_nothreads_release.zip）が Godot のテンプレートの置き場所に要る。
#
# export_presets.cfg が無ければ export_presets.cfg.example を写して使う（CI）。
# 手元の export_presets.cfg は署名の設定を持つので上書きせず、Web のプリセットが無ければ止まる。
set -euo pipefail

if [ "$#" -ne 1 ]; then
	echo "使い方: $0 <出力先のディレクトリ>" >&2
	exit 1
fi

godot_bin="${GODOT_BIN:-godot}"
game_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../game" && pwd)"
mkdir -p "$1"
out_dir="$(cd "$1" && pwd)"

case "$out_dir/" in
	"$game_dir"/*)
		# プロジェクトの中に書き出すと、次の書き出しで成果物が pck に入る（export/ は除外済みの置き場所）
		if [ "${out_dir#"$game_dir"/export}" = "$out_dir" ]; then
			echo "出力先を Godot のプロジェクトの中（export/ 以外）にはできません: $out_dir" >&2
			exit 1
		fi
		;;
esac
# 出力先は書き出しの前に中身を消すので、取り違えたときに消えて困る場所を拒む:
# プロジェクトを含むディレクトリ（リポジトリ直下など）と、前回の書き出し物ではない中身を持つディレクトリ
case "$game_dir/" in
	"$out_dir"/*)
		echo "出力先が Godot のプロジェクトを含んでいます: $out_dir" >&2
		exit 1
		;;
esac
if [ -n "$(ls -A "$out_dir")" ] && [ ! -f "$out_dir/index.pck" ]; then
	echo "出力先が空でなく、前回の書き出し物でもありません（中身を消さないので、空のディレクトリを指定してください。途中で失敗した書き出しの残りなら、手で空にしてください）: $out_dir" >&2
	exit 1
fi

presets="$game_dir/export_presets.cfg"
if [ ! -f "$presets" ]; then
	cp "$game_dir/export_presets.cfg.example" "$presets"
elif ! grep -q '^name="Web"$' "$presets"; then
	echo "export_presets.cfg に Web のプリセットがありません。export_presets.cfg.example の [preset.1] を写してください" >&2
	exit 1
fi

find "$out_dir" -mindepth 1 -delete
# 取り込み（.godot/ のキャッシュの作成。新しく取得したところでは class_name の解決に要る）。
# 進み具合の表示は長いので捨て、エラーは残す
"$godot_bin" --headless --path "$game_dir" --import >/dev/null
"$godot_bin" --headless --path "$game_dir" --export-release "Web" "$out_dir/index.html"

if [ ! -f "$out_dir/index.wasm" ] || [ ! -f "$out_dir/index.pck" ] || [ ! -f "$out_dir/index.service.worker.js" ]; then
	echo "書き出しの成果物が揃っていません: $out_dir" >&2
	exit 1
fi
echo "書き出しました: $out_dir"
