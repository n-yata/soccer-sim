## 試合の終了処理（functional-overview.md 確定事項「試合終了から破棄までの順序」①。component-design.md §3.2）。
## ① 戦績を記録する（同じ試合 ID があれば記録しない）→ 成功したら ② 試合を FINISHED にし → ③ 中断データを上書きする。
## どちらかが失敗したら、中断データは IN_PROGRESS のまま残る（呼んだ側が、後でやり直す）。
## 失敗の通知は、記録は UserDataService、保存は SuspendKeeper が出す（ここでは重ねて出さない）。
## user_data が null なら記録は成功した扱い（保存を確かめないテスト用。SuspendKeeper の store が null のときと同じ）。
class_name MatchFinalizer
extends RefCounted

var _user_data: UserDataService
var _keeper: SuspendKeeper


func _init(user_data: UserDataService, keeper: SuspendKeeper) -> void:
	_user_data = user_data
	_keeper = keeper


## 済んだら FINISHED にした状態、どちらかが失敗したら null。finished_at は戦績の終了日時。
func finalize(state: MatchState, finished_at: String) -> MatchState:
	if _user_data != null and not _user_data.append_record(MatchRecord.of(state, finished_at)):
		return null
	var finished: MatchState = MatchRules.finish(state)
	if not _keeper.save(finished):
		return null
	return finished
