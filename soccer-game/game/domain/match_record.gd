## 戦績1件（ER図「戦績」・data-definition.md §2.2）。試合ごとに1件で、戦績 ID は試合 ID と同じ値。
## 利用者 = HOME、CPU = AWAY（component-design.md §1.3）。勝敗は利用者から見た値。
class_name MatchRecord
extends RefCounted

var record_id: String = ""
var match_id: String = ""
## 終了日時（端末のローカル時刻の ISO 8601。タイムゾーンなし）
var finished_at: String = ""
var score_user: int = 0
var score_cpu: int = 0
var result: GameEnums.MatchResult = GameEnums.MatchResult.DRAW
## 陣形と方式の推移（試合の順）
var timeline: Array[RecordPeriod] = []


## 試合の状態から作る。推移は、両者の陣形・方式が同じ連続したターンの区切り（ReviewAggregator.segments）の始まり。
## ターン記録が無ければ、今の陣形・方式を前半1ターン目からのものとする。p_finished_at は呼び出し側が渡す（ドメインは時計を読まない）。
static func of(state: MatchState, p_finished_at: String) -> MatchRecord:
	var record := MatchRecord.new()
	record.record_id = state.match_id
	record.match_id = state.match_id
	record.finished_at = p_finished_at
	record.score_user = state.home_score
	record.score_cpu = state.away_score
	record.result = result_of(record.score_user, record.score_cpu)
	for segment: ReviewSegment in ReviewAggregator.segments(state.turn_records):
		record.timeline.append(RecordPeriod.new(segment.half, segment.from_turn, segment.home_setup, segment.away_setup))
	if record.timeline.is_empty():
		record.timeline.append(RecordPeriod.new(1, 1, state.home_setup.duplicate_deep(), state.away_setup.duplicate_deep()))
	return record


## 利用者から見た勝敗。
static func result_of(score_user: int, score_cpu: int) -> GameEnums.MatchResult:
	if score_user > score_cpu:
		return GameEnums.MatchResult.WIN
	if score_user < score_cpu:
		return GameEnums.MatchResult.LOSE
	return GameEnums.MatchResult.DRAW
