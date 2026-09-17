import type { Formation, FormationTag, Position, PositionType } from "@/types/formation";

// FormationTag の定義は types/formation.ts に置いている（Formation.extraTags が依存するため、
// ここに置くと types → data の逆流になる）。利用側が「タグの型」と「タグの導出」を
// 1箇所から取れるよう、ここから再公開する
export type { FormationTag };

// --- 導出条件のしきい値 -------------------------------------------------------
// いずれもピッチ座標系（x/y とも 0-100。y が大きいほど相手ゴール側）に対する値。
// 値を動かすと全フォーメーションのタグが変わり、結果として全組み合わせの解説文と
// 総合判定が静かに変化する。変更するときは formationTags.test.ts の期待表も併せて直すこと。

/** ウイングとみなす左右の外側レーン。FW がこの外側にいるかで「ウイング有」を判定する */
const WING_LEFT_X = 25;
const WING_RIGHT_X = 75;
/** ウイングとみなす高さ。低い位置に開いた FW はウイングではなく単なる横幅要員 */
const WING_MIN_Y = 80;

/**
 * ウイングバックとみなす左右の外側レーン。ウイング（FW）より更に外側を条件にしている。
 * ウイングバックは「タッチライン際を最初から最後まで一人で担当する」立ち位置であり、
 * 現行データでも x=10/90 と最も外側に置かれている。
 */
const WING_BACK_LEFT_X = 15;
const WING_BACK_RIGHT_X = 85;
/**
 * ウイングバックとみなす高さの上限。
 *
 * 幅だけで判定すると 4-4-2 のサイドMF（x=15/85, y=55）までウイングバック扱いになり、
 * 「相手のウイングバックの背後を突く」系のルールが 4-4-2 にも当たってしまう。
 * ウイングバックは最終ラインの一員として振る舞う低い初期位置が本質なので、高さで切る。
 */
const WING_BACK_MAX_Y = 50;

/** 守備的MFとみなす高さの上限（4-2-3-1 の DM は y=40） */
const DEFENSIVE_MF_MAX_Y = 42;
/** 攻撃的MFとみなす高さの下限（4-2-3-1 の AM は y=60/65） */
const ATTACKING_MF_MIN_Y = 58;
/** 「フラット」とみなす中盤の y のばらつき幅。4-4-2 の中盤は 50〜55 で差 5 */
const FLAT_MIDFIELD_Y_SPREAD = 10;

function byType(formation: Formation, type: PositionType): Position[] {
  return formation.positions.filter((position) => position.type === type);
}

function isWide(x: number, leftX: number, rightX: number): boolean {
  return x <= leftX || x >= rightX;
}

/**
 * positions だけからフォーメーションの特徴タグを導出する（純関数）。
 *
 * stats は参照しない。stats はレーダーチャート用に開発者が定性的に決めた独立の静的値であり
 * （formations.ts の先頭コメント参照）、タグ導出に混ぜると「レーダーの見栄えを直したら
 * 解説文が変わった」という静かな連動が生まれる。
 */
export function deriveTags(formation: Formation): FormationTag[] {
  const tags: FormationTag[] = [];

  const defenders = byType(formation, "DF");
  const midfielders = byType(formation, "MF");
  const forwards = byType(formation, "FW");

  if (defenders.length === 3) tags.push("3バック");
  if (defenders.length === 4) tags.push("4バック");
  if (defenders.length === 5) tags.push("5バック");

  if (forwards.length === 1) tags.push("1トップ");
  if (forwards.length === 2) tags.push("2トップ");
  if (forwards.length === 3) tags.push("3トップ");

  const wings = forwards.filter(
    (position) => isWide(position.x, WING_LEFT_X, WING_RIGHT_X) && position.y >= WING_MIN_Y,
  );
  if (wings.length >= 2) tags.push("ウイング有");

  const wingBacks = midfielders.filter(
    (position) =>
      isWide(position.x, WING_BACK_LEFT_X, WING_BACK_RIGHT_X) && position.y <= WING_BACK_MAX_Y,
  );
  if (wingBacks.length >= 2) tags.push("ウイングバック有");

  const defensiveMidfielders = midfielders.filter((position) => position.y <= DEFENSIVE_MF_MAX_Y);
  if (defensiveMidfielders.length === 2) tags.push("守備的MF2枚");
  // 「アンカー1枚」は守備的MF2枚の1人版。人数は1か2のどちらか一方にしかならないため、
  // 守備的MF2枚と同時には付かない（formationTags.test.tsで全形を走査し排他性を固定する）
  if (defensiveMidfielders.length === 1) tags.push("アンカー1枚");

  const attackingMidfielders = midfielders.filter((position) => position.y >= ATTACKING_MF_MIN_Y);
  if (attackingMidfielders.length >= 3) tags.push("攻撃的MF3枚");

  if (midfielders.length === 3) tags.push("中盤3枚");
  if (midfielders.length === 4) {
    const ys = midfielders.map((position) => position.y);
    const minY = Math.min(...ys);
    const maxY = Math.max(...ys);
    const spread = maxY - minY;
    // フラットとダイヤは「MFが4人」という条件を共有する排他的な補集合。
    // spread<=10 ならフラット（formationTags.test.tsで全形を走査し排他性を固定する）
    if (spread <= FLAT_MIDFIELD_Y_SPREAD) {
      tags.push("中盤フラット4枚");
    } else if (
      ys.filter((y) => y === minY).length === 1 &&
      ys.filter((y) => y === maxY).length === 1
    ) {
      // 「ダイヤ」はフラットの単純な補集合ではなく、最も低い1人・最も高い1人が
      // それぞれ底・頂点をなす形に限定する。そうしないと、フラットでない4人配置
      // （例: ボックス型=DM2枚+AM2枚）にも「菱形の頂点が〜」という保証していない
      // 位置の主張を持つ`中盤ダイヤ`が付いてしまう（matchupRules.tsのR28/R29/R32b等が
      // 前提にしている「頂点は1人」が崩れる）
      tags.push("中盤ダイヤ");
    }
  }
  // ウイングバックを中盤に数える形（3-5-2 など）も含めた「実質」の枚数。
  // 4-2-3-1 のように守備的MF＋攻撃的MFで5枚になる形も同じタグで扱う
  if (midfielders.length >= 5) tags.push("中盤実質5枚");

  return tags;
}

/**
 * 導出タグと extraTags をマージして返す（重複は除去し、導出結果の順序を優先する）。
 *
 * ルール適用側はこちらを使う。deriveTags を直接使うと extraTags 専用のタグ
 * （`ライン間が空く` など座標に現れない特徴）が欠落し、該当ルールが静かに当たらなくなる。
 */
export function getTags(formation: Formation): FormationTag[] {
  return [...new Set([...deriveTags(formation), ...(formation.extraTags ?? [])])];
}
