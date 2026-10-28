# 設計

- `CpuConfig.marked_penalty: float = 3.0`（`offside_penalty` の隣）。
- `CpuPlanner._probabilities_of`: `offside` と同じ形で、`hint.is_marked` なら `cpu.marked_penalty` を引く。`score()`・`situation_bonus()` は変えない（ヒントの材料を評価値に足す場所を1か所にまとめる）。
- `ConfigRepository._load_cpu`: `_is_bonus_valid(loaded.marked_penalty)` を検査に足し、エラーの文に `marked_penalty=%s` を足す。
- `game/config/cpu_config.tres` に `marked_penalty = 3.0`。
- テスト: cpu_planner_test（減点で確率が下がる・マーク注意でないスルーパスは変わらない）、config_repository_test（読める・範囲外で戻す・エラー文）、hint_values_test（初期値）。
