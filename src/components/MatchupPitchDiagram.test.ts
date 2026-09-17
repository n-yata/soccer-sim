import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import MatchupPitchDiagram from "./MatchupPitchDiagram.vue";
import { formations, getFormationById } from "@/data/formations";
import type { Formation } from "@/types/formation";

// MatchupPitchDiagramのcircle要素は、DOM順で
// [formationAの選手（DF→MF→FW→最後にGK）, formationBの選手（同順）] に並ぶ。
// この並び順を前提にテストを組み立てる。
function findGkCircle(
  wrapper: ReturnType<typeof mount>,
  team: "blue" | "red",
  formation: Formation,
) {
  const circles = wrapper.findAll(`circle.${team}`);
  // buildTeamItemsはGKを配列の最後にpushする
  return circles[formation.positions.length - 1];
}

describe("MatchupPitchDiagram", () => {
  it("formationA/formationBの全選手数分のcircleとラベルが、それぞれ青(A)・赤(B)の色で描画される", () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(MatchupPitchDiagram, {
      props: { formationA, formationB },
    });

    expect(wrapper.findAll("circle.blue")).toHaveLength(formationA.positions.length);
    expect(wrapper.findAll("circle.red")).toHaveLength(formationB.positions.length);

    const labels = wrapper.findAll("text").map((t) => t.text());
    expect(labels).toEqual(
      expect.arrayContaining(
        [...formationA.positions, ...formationB.positions].map((p) => p.label),
      ),
    );
  });

  it("対戦演出用にチームA/Bがそれぞれ専用の<g>にグルーピングされ、内包する選手数と一致する", () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(MatchupPitchDiagram, {
      props: { formationA, formationB },
    });

    const teamAGroup = wrapper.find(".matchup-pitch__team--a");
    const teamBGroup = wrapper.find(".matchup-pitch__team--b");
    expect(teamAGroup.exists()).toBe(true);
    expect(teamBGroup.exists()).toBe(true);
    expect(teamAGroup.findAll("circle.blue")).toHaveLength(formationA.positions.length);
    expect(teamBGroup.findAll("circle.red")).toHaveLength(formationB.positions.length);
    // チームAの<g>にチームBの選手が混入していないこと（グルーピングの取り違え防止）
    expect(teamAGroup.findAll("circle.red")).toHaveLength(0);
    expect(teamBGroup.findAll("circle.blue")).toHaveLength(0);
  });

  it("GKは青が画面左端(cx=0)、赤が画面右端(cx=260)に固定される", () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(MatchupPitchDiagram, {
      props: { formationA, formationB },
    });

    const gkBlue = findGkCircle(wrapper, "blue", formationA);
    const gkRed = findGkCircle(wrapper, "red", formationB);
    expect(Number(gkBlue.attributes("cx"))).toBeCloseTo(0);
    expect(Number(gkRed.attributes("cx"))).toBeCloseTo(260);
  });

  it("青の攻撃陣(FW)が赤の守備陣(DF)に、赤の攻撃陣(FW)が青の守備陣(DF)に近づく非対称な列配置になっている", () => {
    // component内のcolXByTeamの値をそのまま検証する（設計意図の固定）
    const formationA = getFormationById("4-4-2") as Formation;
    const formationB = getFormationById("4-4-2") as Formation;
    const wrapper = mount(MatchupPitchDiagram, {
      props: { formationA, formationB },
    });
    const blueCircles = wrapper.findAll("circle.blue");
    const redCircles = wrapper.findAll("circle.red");
    // 4-4-2の並び: DF(4)→MF(4)→FW(2)→GK(1) の順でcircleが描画される
    const blueDfCx = Number(blueCircles[0].attributes("cx"));
    const blueFwCx = Number(blueCircles[8].attributes("cx"));
    const redDfCx = Number(redCircles[0].attributes("cx"));
    const redFwCx = Number(redCircles[8].attributes("cx"));

    // 青DFと赤FW、青FWと赤DFが近接し、青DFと赤DF・青FWと赤FWよりも距離が近い
    expect(Math.abs(blueDfCx - redFwCx)).toBeLessThan(Math.abs(blueDfCx - redDfCx));
    expect(Math.abs(blueFwCx - redDfCx)).toBeLessThan(Math.abs(blueFwCx - redFwCx));
  });

  it("同じチーム内でDFラインは、幅方向(元のx座標)の昇順でcyが単調増加する", () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(MatchupPitchDiagram, {
      props: { formationA, formationB },
    });

    // 4-3-3のDF: LB(15), CB(35), CB(65), RB(85) の4人。DOM順の先頭4件がDF
    const blueCircles = wrapper.findAll("circle.blue");
    const dfCount = formationA.positions.filter((p) => p.type === "DF").length;
    const dfCys = blueCircles.slice(0, dfCount).map((c) => Number(c.attributes("cy")));
    for (let i = 1; i < dfCys.length; i++) {
      expect(dfCys[i]).toBeGreaterThan(dfCys[i - 1]);
    }
  });

  it("GKのcyは、自チームDFラインの中で最も中央(x=50)に近い選手のcyと一致する", () => {
    // 3-5-2のCB(50,15)はx=50でDFラインの中央そのものなので、GKのcyと厳密に一致するはず
    const formationA = getFormationById("4-4-2") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(MatchupPitchDiagram, {
      props: { formationA, formationB },
    });

    const redCircles = wrapper.findAll("circle.red");
    const dfPositions = formationB.positions
      .filter((p) => p.type === "DF")
      .sort((a, b) => a.x - b.x);
    const centerCbIndex = dfPositions.findIndex((p) => p.x === 50);
    expect(centerCbIndex).toBe(1); // CB(30), CB(50), CB(70) の中央

    const gkCircle = findGkCircle(wrapper, "red", formationB);
    const centerCbCircle = redCircles[centerCbIndex];
    expect(Number(gkCircle.attributes("cy"))).toBeCloseTo(Number(centerCbCircle.attributes("cy")));
  });

  // 同一フォーメーション同士の対戦では、青チームと赤チームの配置が左右対称になる
  // （チームごとにcyの基準をずらすと、衝突が実際には起きない組み合わせでも常に
  // 上下にズレて表示される回帰が過去にあった）。DFラインの各cyとGKのcyが
  // 青チーム・赤チームで一致することを全フォーメーションで検証する
  it.each(formations.map((f): [string] => [f.id]))(
    "%s（同一フォーメーション同士）: DFラインとGKの高さが左右対称になる",
    (formationId) => {
      const formation = getFormationById(formationId) as Formation;
      const wrapper = mount(MatchupPitchDiagram, {
        props: { formationA: formation, formationB: formation },
      });

      const dfCount = formation.positions.filter((p) => p.type === "DF").length;
      const blueCircles = wrapper.findAll("circle.blue");
      const redCircles = wrapper.findAll("circle.red");
      const blueDfCys = blueCircles.slice(0, dfCount).map((c) => Number(c.attributes("cy")));
      const redDfCys = redCircles.slice(0, dfCount).map((c) => Number(c.attributes("cy")));
      blueDfCys.forEach((cy, i) => expect(cy).toBeCloseTo(redDfCys[i]));

      const blueGk = findGkCircle(wrapper, "blue", formation);
      const redGk = findGkCircle(wrapper, "red", formation);
      expect(Number(blueGk.attributes("cy"))).toBeCloseTo(Number(redGk.attributes("cy")));
    },
  );

  // 全フォーメーション2件組み合わせを全走査し、青チームと赤チームの選手同士の
  // 中心間距離が近すぎない（丸がほぼ完全に隠れる）ことを検証する
  // （testing.md「不変条件のテストは対象データを全走査する」）。
  // 距離の下限は選手の丸そのもののサイズ（半径4.5＝直径9。MatchupPitchDiagram.vueの
  // circle要素のr属性）から導く。これより近いと丸の大半が重なり、色が違っても
  // 2チームの選手として見分けられなくなる
  const PLAYER_MARKER_DIAMETER = 9;
  const allPairs = formations.flatMap((a, i) =>
    formations.slice(i + 1).map((b): [string, string] => [a.id, b.id]),
  );

  it.each(allPairs)(
    "%s vs %s: 両チームの選手の中心間距離が近すぎない（丸がほぼ完全に隠れる回帰の防止）",
    (idA, idB) => {
      const formationA = getFormationById(idA) as Formation;
      const formationB = getFormationById(idB) as Formation;
      const wrapper = mount(MatchupPitchDiagram, {
        props: { formationA, formationB },
      });

      const blueCircles = wrapper.findAll("circle.blue");
      const redCircles = wrapper.findAll("circle.red");
      expect(blueCircles.length).toBe(formationA.positions.length);
      expect(redCircles.length).toBe(formationB.positions.length);

      const tooClose: string[] = [];
      blueCircles.forEach((circleA, indexA) => {
        const ax = Number(circleA.attributes("cx"));
        const ay = Number(circleA.attributes("cy"));
        redCircles.forEach((circleB, indexB) => {
          const bx = Number(circleB.attributes("cx"));
          const by = Number(circleB.attributes("cy"));
          const distance = Math.hypot(ax - bx, ay - by);
          if (distance < PLAYER_MARKER_DIAMETER) {
            tooClose.push(`A[${indexA}] vs B[${indexB}]: 距離${distance.toFixed(2)}`);
          }
        });
      });
      expect(tooClose).toEqual([]);
    },
  );

  // 選手ラベル（丸の中心から7上に描画される文字）が、相手チームの丸に重なって
  // 読めなくならないことを検証する。丸同士の中心間距離がPLAYER_MARKER_DIAMETER以上
  // 離れていても、ラベルは丸の外（上）に飛び出す分、隣接する相手チームの丸と
  // 重なることがある（実データでこの重なりが発生し、修正した）
  const LABEL_TO_CIRCLE_MIN_DISTANCE = 5;

  it.each(allPairs)(
    "%s vs %s: 選手ラベルが相手チームの丸に重ならない（回帰の防止）",
    (idA, idB) => {
      const formationA = getFormationById(idA) as Formation;
      const formationB = getFormationById(idB) as Formation;
      const wrapper = mount(MatchupPitchDiagram, {
        props: { formationA, formationB },
      });

      const blueCircles = wrapper.findAll("circle.blue").map((c) => ({
        cx: Number(c.attributes("cx")),
        cy: Number(c.attributes("cy")),
      }));
      const redCircles = wrapper.findAll("circle.red").map((c) => ({
        cx: Number(c.attributes("cx")),
        cy: Number(c.attributes("cy")),
      }));
      const blueLabels = wrapper
        .findAll(".matchup-pitch__team--a text")
        .map((t) => ({ x: Number(t.attributes("x")), y: Number(t.attributes("y")) }));
      const redLabels = wrapper
        .findAll(".matchup-pitch__team--b text")
        .map((t) => ({ x: Number(t.attributes("x")), y: Number(t.attributes("y")) }));

      const overlaps: string[] = [];
      blueLabels.forEach((label, labelIndex) => {
        redCircles.forEach((circle, circleIndex) => {
          const distance = Math.hypot(label.x - circle.cx, label.y - circle.cy);
          if (distance < LABEL_TO_CIRCLE_MIN_DISTANCE) {
            overlaps.push(`青label[${labelIndex}] vs 赤circle[${circleIndex}]: 距離${distance.toFixed(2)}`);
          }
        });
      });
      redLabels.forEach((label, labelIndex) => {
        blueCircles.forEach((circle, circleIndex) => {
          const distance = Math.hypot(label.x - circle.cx, label.y - circle.cy);
          if (distance < LABEL_TO_CIRCLE_MIN_DISTANCE) {
            overlaps.push(`赤label[${labelIndex}] vs 青circle[${circleIndex}]: 距離${distance.toFixed(2)}`);
          }
        });
      });
      expect(overlaps).toEqual([]);
    },
  );

  // FR: 4列以上のフォーメーション（DM/AMのように同じtype内でy座標が離れる陣形）でも、
  // その列数がtypeの種類数(GK/DF/MF/FW=最大4)に丸められず、実際の陣形どおりの列数で
  // 描画されることを固定する（本コンポーネントが解決したバグの回帰防止）。
  // 列＝distinctなcx値の個数として数える（GKは別列固定のため対象から除く）
  it.each([
    ["4-4-2", 3],
    ["4-3-3", 3],
    ["4-2-3-1", 4],
    ["3-5-2", 3],
    ["5-3-2", 3],
    ["4-1-4-1", 4],
    ["3-4-3", 3],
    ["4-1-2-1-2", 5],
  ] as const)("%s: フィールドプレイヤーの列数が%i列になる", (formationId, expectedColumns) => {
    const formationA = getFormationById(formationId) as Formation;
    const formationB = getFormationById("4-4-2") as Formation;
    const wrapper = mount(MatchupPitchDiagram, {
      props: { formationA, formationB },
    });

    const outfieldCount = formationA.positions.filter((p) => p.type !== "GK").length;
    const blueCircles = wrapper.findAll("circle.blue").slice(0, outfieldCount);
    const distinctCx = new Set(blueCircles.map((c) => Number(c.attributes("cx")).toFixed(1)));
    expect(distinctCx.size).toBe(expectedColumns);
  });
});
