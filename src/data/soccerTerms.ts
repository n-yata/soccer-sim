import type { SoccerTerm } from "@/types/formation";

// 収録語は matchups.ts の優位ポイント・総合判定理由、radarAxes.ts の軸説明、
// formations.ts の説明文・陣形別教材に実際に登場する用語から抽出している（推測で追加しない）。
// 各説明文は、他のサッカー用語を使わずに書くこと（NFR-02準拠）。
export const soccerTerms: SoccerTerm[] = [
  {
    id: "anchor",
    term: "アンカー",
    reading: "あんかー",
    category: "ポジション",
    description: "中央の選手たちの後ろで、守りを支えながら味方へのパスの支点になる選手",
  },
  {
    id: "volante",
    term: "ボランチ",
    reading: "ぼらんち",
    category: "ポジション",
    description: "中央の低い位置で相手の攻撃を止め、味方へボールをつないで攻撃を始める選手",
  },
  {
    id: "behind-striker",
    term: "トップ下",
    reading: "とっぷした",
    category: "ポジション",
    description: "一番前の攻撃選手の後ろで、パスを受けて攻撃をつなぎ、ゴールを狙う選手",
  },
  {
    id: "side-back",
    term: "サイドバック",
    reading: "さいどばっく",
    category: "ポジション",
    description:
      "ピッチの左右どちらかを主戦場にする守備の選手。自陣を守るだけでなく、攻撃の際は高い位置まで駆け上がって攻撃に加わることもある",
  },
  {
    id: "center-back",
    term: "センターバック",
    reading: "せんたーばっく",
    category: "ポジション",
    description: "ピッチ中央でゴール前を守る選手。相手の攻撃選手を体を張って止める役割を担う",
  },
  {
    id: "wing-back",
    term: "ウイングバック",
    reading: "ういんぐばっく",
    category: "ポジション",
    description:
      "守備の選手が3人のチームで、左右のサイドを一人で行ったり来たりする選手。自陣に戻って守ることも、相手陣地の深くまで攻め上がることもある",
  },
  {
    id: "defensive-midfielder",
    term: "守備的MF",
    reading: "しゅびてきえむえふ",
    category: "ポジション",
    description:
      "ピッチの中央付近で主に守備を担当する選手。相手の攻撃の起点になりそうな場所をふさぎ、味方の守備陣の前で壁になる",
  },
  {
    id: "attacking-midfielder",
    term: "攻撃的MF",
    reading: "こうげきてきえむえふ",
    category: "ポジション",
    description:
      "ピッチの中央からやや前寄りに位置し、主に攻撃を組み立てる選手。ゴールに近い位置でパスやシュートに関わることが多い",
  },
  {
    id: "two-top",
    term: "2トップ",
    reading: "つーとっぷ",
    category: "ポジション",
    description: "最前線に並んで立つ2人の攻撃の選手。ゴールを奪う役割を2人で分担する",
  },
  {
    id: "wing",
    term: "ウイング",
    reading: "ういんぐ",
    category: "ポジション",
    description:
      "ピッチの左右の高い位置に立つ攻撃の選手。コートの端に近い、相手の少ない場所を使って相手守備の外側から仕掛ける",
  },
  {
    id: "one-on-one",
    term: "1対1",
    reading: "いちたいいち",
    category: "攻守の考え方",
    description: "味方1人と相手1人が、ボールを挟んで向き合って対決する場面",
  },
  {
    id: "numerical-advantage",
    term: "数的優位",
    reading: "すうてきゆうい",
    category: "攻守の考え方",
    description:
      "その場面で、味方の人数が相手チームの人数より多い状態。人数が多いほうが有利に戦いやすい",
  },
  {
    id: "man-to-man",
    term: "マンツーマン",
    reading: "まんつーまん",
    category: "攻守の考え方",
    description: "守る側の選手が、相手の特定の1人にほぼ付きっきりで対応する守り方",
  },
  {
    id: "pin-down",
    term: "ピン留め",
    reading: "ぴんどめ",
    category: "攻守の考え方",
    description:
      "攻撃側の選手がその場に留まり続けることで、相手の守備選手をそこから動けなくさせること。動けなくなった相手の周りに空いた広い場所を、他の味方が使えるようになる",
  },
  {
    id: "five-lanes",
    term: "5レーン",
    reading: "ふぁいぶれーん",
    category: "陣形・戦術",
    description:
      "ピッチを、攻める方向と同じ向きに縦へ5つの帯に区切って考える方法。選手が同じ帯に重ならないように立つことで、ピッチ全体を幅広く使いやすくする",
  },
  {
    id: "pressing",
    term: "プレッシング",
    reading: "ぷれっしんぐ",
    category: "攻守の考え方",
    description:
      "ボールを持っている相手選手に対して、素早く近づいて自由に動けないようにする守備のやり方",
  },
  {
    id: "space",
    term: "スペース",
    reading: "すぺーす",
    category: "陣形・戦術",
    description: "コート上で、相手の選手がいない広い場所のこと",
  },
  {
    id: "back-line",
    term: "最終ライン",
    reading: "さいしゅうらいん",
    category: "陣形・戦術",
    description: "守る選手たちが作る、一番ゴールに近い横の並び",
  },
  {
    id: "midfield",
    term: "中盤",
    reading: "ちゅうばん",
    category: "陣形・戦術",
    description: "コートの前寄りと後ろ寄りの間にある、真ん中あたりのエリア",
  },
  {
    id: "gap-between-lines",
    term: "ライン間",
    reading: "らいんかん",
    category: "陣形・戦術",
    description:
      "守る選手たちが作る前後の並びと並びの間にできるすき間の場所。攻撃側はここでボールを受けると自由に動きやすい",
  },
  {
    id: "compact-block",
    term: "コンパクトな守備ブロック",
    reading: "こんぱくとなしゅびぶろっく",
    category: "陣形・戦術",
    description:
      "守る選手たち同士の前後・左右の距離を狭く保ち、すき間を作らないようにまとまった立ち位置",
  },
];
