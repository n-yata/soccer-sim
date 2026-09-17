import type { Formation } from "@/types/formation";

// ピッチ座標系: 幅・高さとも 0-100 の相対座標。原点(0,0)は自陣ゴール側の左下、
// y が大きいほど攻撃方向（相手ゴール側）に近づく（functional-overview.md「確定事項」参照）。
//
// stats（レーダーチャート用、各軸0-100）の算出方針:
// positions の人数構成・座標や description の内容を参考に、一般的な戦術理論に基づいて
// 開発者が定性的に判断した値である（advantagesForA/Bと同じ運用）。各フォーメーションの
// コメントに、その値の根拠となった主な特徴を記載する。以下は各軸が着目する観点の目安
// （厳密な計算式ではない）:
//   attack: FWの人数・攻撃的ポジションの前掛かり度合い
//   defense: DFの人数・最終ラインの低さ・守備的MFの有無
//   balance: DF/MF/FWの人数配分の均等さ
//   spaceControl: サイドの選手がどれだけ幅を使っているか
//   pressIntensity: 中盤の選手密度やFW-DFライン間のコンパクトさ
export const formations: Formation[] = [
  {
    id: "4-4-2",
    name: "4-4-2",
    description: "DF4人・MF4人・FW2人の伝統的なバランス型フォーメーション。",
    // DF/MF/FWが4-4-2と偏りが少なくバランス型。サイドMF(x15/85)で幅は作れるが、
    // FWとDFのライン間が間延びしやすくプレス強度は低め
    stats: { attack: 55, defense: 60, balance: 80, spaceControl: 65, pressIntensity: 40 },
    // FWとMFが前後に離れやすく、中盤と最終ラインの間にすき間ができやすい。
    // この特徴は座標のy差では表現できない（4-3-3のほうがFW-MFのy差は大きいが、
    // 4-3-3は中盤3枚が中央に密集するためライン間は空きにくい）ため手動で付与する
    extraTags: ["ライン間が空く"],
    positions: [
      { id: "4-4-2-gk", type: "GK", label: "GK", x: 50, y: 5 },
      { id: "4-4-2-lb", type: "DF", label: "LB", x: 15, y: 20 },
      { id: "4-4-2-cb1", type: "DF", label: "CB", x: 35, y: 18 },
      { id: "4-4-2-cb2", type: "DF", label: "CB", x: 65, y: 18 },
      { id: "4-4-2-rb", type: "DF", label: "RB", x: 85, y: 20 },
      { id: "4-4-2-lm", type: "MF", label: "LM", x: 15, y: 55 },
      { id: "4-4-2-cm1", type: "MF", label: "CM", x: 35, y: 50 },
      { id: "4-4-2-cm2", type: "MF", label: "CM", x: 65, y: 50 },
      { id: "4-4-2-rm", type: "MF", label: "RM", x: 85, y: 55 },
      { id: "4-4-2-st1", type: "FW", label: "ST", x: 40, y: 85 },
      { id: "4-4-2-st2", type: "FW", label: "ST", x: 60, y: 85 },
    ],
  },
  {
    id: "4-3-3",
    name: "4-3-3",
    description: "DF4人・MF3人・FW3人。両翼を高く張らせて幅を作る攻撃的フォーメーション。",
    // FW3人・両ウイングが高い位置(y85)を取るため攻撃力は最高クラス。MFが3人と少なく
    // バランスはやや偏る
    stats: { attack: 80, defense: 60, balance: 65, spaceControl: 70, pressIntensity: 35 },
    positions: [
      { id: "4-3-3-gk", type: "GK", label: "GK", x: 50, y: 5 },
      { id: "4-3-3-lb", type: "DF", label: "LB", x: 15, y: 20 },
      { id: "4-3-3-cb1", type: "DF", label: "CB", x: 35, y: 18 },
      { id: "4-3-3-cb2", type: "DF", label: "CB", x: 65, y: 18 },
      { id: "4-3-3-rb", type: "DF", label: "RB", x: 85, y: 20 },
      { id: "4-3-3-cm1", type: "MF", label: "CM", x: 30, y: 50 },
      { id: "4-3-3-cm2", type: "MF", label: "CM", x: 50, y: 45 },
      { id: "4-3-3-cm3", type: "MF", label: "CM", x: 70, y: 50 },
      { id: "4-3-3-lw", type: "FW", label: "LW", x: 20, y: 85 },
      { id: "4-3-3-st", type: "FW", label: "ST", x: 50, y: 88 },
      { id: "4-3-3-rw", type: "FW", label: "RW", x: 80, y: 85 },
    ],
  },
  {
    id: "4-2-3-1",
    name: "4-2-3-1",
    description: "DF4人・守備的MF2人・攻撃的MF3人・FW1人。中盤を厚くした現代的なフォーメーション。",
    // DF4人+守備的MF2人で守備の厚みが最も高い。中盤(y40-65)に5人集中しライン間が狭く
    // プレス強度も高い。一方でFWが1人のみのためバランスは偏る
    stats: { attack: 65, defense: 85, balance: 45, spaceControl: 60, pressIntensity: 70 },
    positions: [
      { id: "4-2-3-1-gk", type: "GK", label: "GK", x: 50, y: 5 },
      { id: "4-2-3-1-lb", type: "DF", label: "LB", x: 15, y: 20 },
      { id: "4-2-3-1-cb1", type: "DF", label: "CB", x: 35, y: 18 },
      { id: "4-2-3-1-cb2", type: "DF", label: "CB", x: 65, y: 18 },
      { id: "4-2-3-1-rb", type: "DF", label: "RB", x: 85, y: 20 },
      { id: "4-2-3-1-dm1", type: "MF", label: "DM", x: 35, y: 40 },
      { id: "4-2-3-1-dm2", type: "MF", label: "DM", x: 65, y: 40 },
      { id: "4-2-3-1-aml", type: "MF", label: "AM", x: 20, y: 65 },
      { id: "4-2-3-1-amc", type: "MF", label: "AM", x: 50, y: 60 },
      { id: "4-2-3-1-amr", type: "MF", label: "AM", x: 80, y: 65 },
      { id: "4-2-3-1-st", type: "FW", label: "ST", x: 50, y: 88 },
    ],
  },
  {
    id: "3-5-2",
    name: "3-5-2",
    description: "DF3人・MF5人・FW2人。両翼のウイングバックが上下動して幅を作るフォーメーション。",
    // ウイングバック(x10/90)がピッチ幅いっぱいを使うためスペース支配力は最高。
    // DFが3人と少なく守備力はやや控えめ
    stats: { attack: 55, defense: 50, balance: 55, spaceControl: 90, pressIntensity: 60 },
    positions: [
      { id: "3-5-2-gk", type: "GK", label: "GK", x: 50, y: 5 },
      { id: "3-5-2-cb1", type: "DF", label: "CB", x: 30, y: 18 },
      { id: "3-5-2-cb2", type: "DF", label: "CB", x: 50, y: 15 },
      { id: "3-5-2-cb3", type: "DF", label: "CB", x: 70, y: 18 },
      { id: "3-5-2-lwb", type: "MF", label: "LWB", x: 10, y: 45 },
      { id: "3-5-2-cm1", type: "MF", label: "CM", x: 35, y: 50 },
      { id: "3-5-2-cm2", type: "MF", label: "CM", x: 50, y: 45 },
      { id: "3-5-2-cm3", type: "MF", label: "CM", x: 65, y: 50 },
      { id: "3-5-2-rwb", type: "MF", label: "RWB", x: 90, y: 45 },
      { id: "3-5-2-st1", type: "FW", label: "ST", x: 40, y: 85 },
      { id: "3-5-2-st2", type: "FW", label: "ST", x: 60, y: 85 },
    ],
  },
  {
    id: "5-3-2",
    name: "5-3-2",
    description:
      "DF5人・MF3人・FW2人。最終ラインに5枚を並べて自陣を固める守備重視のフォーメーション。",
    // 最終ラインに5枚を置くため守備力は最高クラス。前線が2枚で攻撃力は低め。
    // 中盤3枚で人数を割けないぶんプレス強度も低い
    stats: { attack: 40, defense: 85, balance: 55, spaceControl: 55, pressIntensity: 35 },
    positions: [
      { id: "5-3-2-gk", type: "GK", label: "GK", x: 50, y: 5 },
      { id: "5-3-2-lb", type: "DF", label: "LB", x: 10, y: 18 },
      { id: "5-3-2-cb1", type: "DF", label: "CB", x: 30, y: 16 },
      { id: "5-3-2-cb2", type: "DF", label: "CB", x: 50, y: 14 },
      { id: "5-3-2-cb3", type: "DF", label: "CB", x: 70, y: 16 },
      { id: "5-3-2-rb", type: "DF", label: "RB", x: 90, y: 18 },
      { id: "5-3-2-cm1", type: "MF", label: "CM", x: 30, y: 50 },
      { id: "5-3-2-cm2", type: "MF", label: "CM", x: 50, y: 48 },
      { id: "5-3-2-cm3", type: "MF", label: "CM", x: 70, y: 50 },
      { id: "5-3-2-st1", type: "FW", label: "ST", x: 40, y: 85 },
      { id: "5-3-2-st2", type: "FW", label: "ST", x: 60, y: 85 },
    ],
  },
  {
    id: "4-1-4-1",
    name: "4-1-4-1",
    description:
      "DF4人・MF5人・FW1人。中盤の底に1枚を置き、その前に4枚を横並びにする守備の安定したフォーメーション。",
    // 中盤の底1枚と横並び4枚で中央を二重に閉じるため守備力は高い。
    // 1トップで攻撃力は控えめ。サイドMF(x15/85)で幅は確保できる
    stats: { attack: 50, defense: 75, balance: 70, spaceControl: 70, pressIntensity: 55 },
    positions: [
      { id: "4-1-4-1-gk", type: "GK", label: "GK", x: 50, y: 5 },
      { id: "4-1-4-1-lb", type: "DF", label: "LB", x: 15, y: 20 },
      { id: "4-1-4-1-cb1", type: "DF", label: "CB", x: 35, y: 18 },
      { id: "4-1-4-1-cb2", type: "DF", label: "CB", x: 65, y: 18 },
      { id: "4-1-4-1-rb", type: "DF", label: "RB", x: 85, y: 20 },
      { id: "4-1-4-1-dm", type: "MF", label: "DM", x: 50, y: 35 },
      { id: "4-1-4-1-lm", type: "MF", label: "LM", x: 15, y: 55 },
      { id: "4-1-4-1-cm1", type: "MF", label: "CM", x: 35, y: 52 },
      { id: "4-1-4-1-cm2", type: "MF", label: "CM", x: 65, y: 52 },
      { id: "4-1-4-1-rm", type: "MF", label: "RM", x: 85, y: 55 },
      { id: "4-1-4-1-st", type: "FW", label: "ST", x: 50, y: 88 },
    ],
  },
  {
    id: "3-4-3",
    name: "3-4-3",
    description:
      "DF3人・MF4人・FW3人。ウイングバックとウイングで両サイドを厚くする攻撃的なフォーメーション。",
    // 前線3枚＋ウイングバックで最も前掛かり。両サイドを最外から最前線まで
    // 担うためスペース支配力は最高クラス。DF3枚で守備力は低め
    stats: { attack: 85, defense: 50, balance: 60, spaceControl: 85, pressIntensity: 60 },
    positions: [
      { id: "3-4-3-gk", type: "GK", label: "GK", x: 50, y: 5 },
      { id: "3-4-3-cb1", type: "DF", label: "CB", x: 30, y: 18 },
      { id: "3-4-3-cb2", type: "DF", label: "CB", x: 50, y: 15 },
      { id: "3-4-3-cb3", type: "DF", label: "CB", x: 70, y: 18 },
      { id: "3-4-3-lwb", type: "MF", label: "LWB", x: 10, y: 45 },
      { id: "3-4-3-cm1", type: "MF", label: "CM", x: 40, y: 48 },
      { id: "3-4-3-cm2", type: "MF", label: "CM", x: 60, y: 48 },
      { id: "3-4-3-rwb", type: "MF", label: "RWB", x: 90, y: 45 },
      { id: "3-4-3-lw", type: "FW", label: "LW", x: 20, y: 85 },
      { id: "3-4-3-st", type: "FW", label: "ST", x: 50, y: 88 },
      { id: "3-4-3-rw", type: "FW", label: "RW", x: 80, y: 85 },
    ],
  },
  {
    id: "4-1-2-1-2",
    name: "4-1-2-1-2",
    // 4-4-2の中盤を菱形に配置した形（4-4-2ダイヤとも呼ばれる）。id/nameは正式表記の
    // 4-1-2-1-2を使う（DF4・DM1・CM2・AM1・FW2の人数がそのまま名称に現れるため。
    // 「4-4-2ダイヤ」表記だと数字以外の文字が混ざり、formations.test.tsの
    // 「名称の数字合計とフィールドプレイヤー数が一致する」不変条件がNumber("2ダイヤ")=NaNで
    // 壊れる。詳細は design.md 参照）
    description:
      "DF4人・DM1人・CM2人・AM1人・FW2人。中盤を菱形に配置し、中央に人数をかけるフォーメーション（4-4-2の中盤を菱形にした形で「4-4-2ダイヤ」とも呼ばれる）。",
    // 中盤4枚を中央に集めるため中央は厚いが、サイドに誰も開かないため
    // スペース支配力は最も低い。菱形の底と頂点で縦の距離が近く、プレス強度は高め
    stats: { attack: 65, defense: 60, balance: 65, spaceControl: 40, pressIntensity: 60 },
    positions: [
      { id: "4-1-2-1-2-gk", type: "GK", label: "GK", x: 50, y: 5 },
      { id: "4-1-2-1-2-lb", type: "DF", label: "LB", x: 15, y: 20 },
      { id: "4-1-2-1-2-cb1", type: "DF", label: "CB", x: 35, y: 18 },
      { id: "4-1-2-1-2-cb2", type: "DF", label: "CB", x: 65, y: 18 },
      { id: "4-1-2-1-2-rb", type: "DF", label: "RB", x: 85, y: 20 },
      { id: "4-1-2-1-2-dm", type: "MF", label: "DM", x: 50, y: 35 },
      { id: "4-1-2-1-2-lcm", type: "MF", label: "LCM", x: 25, y: 52 },
      { id: "4-1-2-1-2-rcm", type: "MF", label: "RCM", x: 75, y: 52 },
      { id: "4-1-2-1-2-am", type: "MF", label: "AM", x: 50, y: 68 },
      { id: "4-1-2-1-2-st1", type: "FW", label: "ST", x: 40, y: 85 },
      { id: "4-1-2-1-2-st2", type: "FW", label: "ST", x: 60, y: 85 },
    ],
  },
];

export function getFormationById(id: string): Formation | undefined {
  return formations.find((formation) => formation.id === id);
}
