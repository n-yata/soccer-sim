import type { ReplayFrame, TacticalScene } from "@/types/tacticalReplay";

function frame(
  wing: [number, number],
  overlap: [number, number],
  defender: [number, number],
  cover: [number, number],
  ball: [number, number],
): ReplayFrame {
  return {
    players: [
      { id: "wing", x: wing[0], y: wing[1] },
      { id: "overlap", x: overlap[0], y: overlap[1] },
      { id: "defender", x: defender[0], y: defender[1] },
      { id: "cover", x: cover[0], y: cover[1] },
    ],
    ball: { x: ball[0], y: ball[1] },
  };
}

// 右サイドの局面だけを切り出した独自教材。選択陣形の勝敗推定とは独立する。
export const wideOverloadScene: TacticalScene = {
  id: "wide-overload",
  title: "サイドの2対1",
  durationMs: 2800,
  players: [
    { id: "wing", label: "ウイング", number: 7, team: "attack" },
    { id: "overlap", label: "サイドバック", number: 2, team: "attack" },
    { id: "defender", label: "対面の守備者", number: 3, team: "defence" },
    { id: "cover", label: "カバー役", number: 4, team: "defence" },
  ],
  steps: [
    {
      title: "まず、誰が空いている？",
      explanation:
        "青7がボールを持ち、青2が後ろから支えています。赤3が目の前を守り、赤4は中央からカバーできる位置にいます。青2の走り出しを見てみましょう。",
      observation: "青2と赤4の距離に注目。赤4が近づく前に使える時間は短い。",
      advantage: "サイドに2対1をつくる準備",
      frame: frame([116, 128], [65, 170], [178, 115], [230, 65], [129, 134]),
      routes: [{ from: { x: 65, y: 170 }, to: { x: 160, y: 170 }, kind: "run" }],
    },
    {
      title: "守備者を引きつける",
      explanation:
        "青7が内側へ持ち運ぶと、赤3も青7に寄ります。その間に青2が外側を追い越します。赤3はボールと走る味方を同時に止めにくくなり、外のパス先が空きます。",
      observation: "青7だけで突破しようとせず、赤3が寄った瞬間に青2を見る。",
      advantage: "外側にパスの選択肢が生まれる",
      frame: frame([147, 112], [160, 170], [177, 105], [230, 80], [160, 118]),
      routes: [
        { from: { x: 65, y: 170 }, to: { x: 160, y: 170 }, kind: "run" },
        { from: { x: 160, y: 118 }, to: { x: 213, y: 170 }, kind: "pass" },
      ],
      space: { x: 194, y: 147, width: 60, height: 42, label: "外の空間" },
    },
    {
      title: "カバーが来る前にパス",
      explanation:
        "青7から青2へ、走る先にパスを出します。赤3が青7に寄った分、青2は前へ進めます。ただし赤4も外側へ移動中。人数の優位を使うには、パスと走り出しのタイミングを合わせることが大切です。",
      observation: "黄色の線がパス。赤4の移動で、使える空間が狭くなり始める。",
      advantage: "青2が前を向いて受けられる",
      frame: frame([155, 112], [213, 170], [186, 118], [235, 104], [226, 170]),
      routes: [{ from: { x: 160, y: 118 }, to: { x: 226, y: 170 }, kind: "pass" }],
      space: { x: 232, y: 147, width: 42, height: 42, label: "進める空間" },
    },
    {
      title: "カバーで優位が変わる",
      explanation:
        "赤4が青2の前へ到着し、赤3は青7を見ています。局面は2対2になり、外を進む道が閉じました。さっき空いていたからといって、同じ方向へ進み続けるとボールを失いやすくなります。",
      observation: "赤4が進む道をふさいだ。青2の後ろには戻せる青7がいる。",
      advantage: "2対2：外への突破は難しくなる",
      frame: frame([161, 119], [225, 169], [189, 126], [249, 157], [237, 175]),
      routes: [{ from: { x: 237, y: 175 }, to: { x: 174, y: 125 }, kind: "pass" }],
    },
    {
      title: "戻してやり直す",
      explanation:
        "青2は青7へ戻してボールを保ちます。相手が外へ寄った後は、中央や逆サイドの味方も探せます。数の優位は一瞬の条件。相手の動きに合わせて、進むか戻すかを選び直しましょう。",
      observation: "引きつける → 空いた味方を使う → カバーを見て選び直す。",
      advantage: "保持して、次の攻め方を探す",
      frame: frame([147, 114], [218, 173], [180, 127], [249, 157], [160, 120]),
      routes: [{ from: { x: 237, y: 175 }, to: { x: 160, y: 120 }, kind: "pass" }],
    },
  ],
};
